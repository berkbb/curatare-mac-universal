// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation

/// Bir alt sürecin tamamlanmış çıktısı.
public struct ProcessResult: Sendable, Equatable {
    public let exitCode: Int32
    public let stdout: String
    public let stderr: String

    public init(exitCode: Int32, stdout: String, stderr: String) {
        self.exitCode = exitCode
        self.stdout = stdout
        self.stderr = stderr
    }
}

/// Motor (Mole) ve yardımcı araçlar çalıştırılırken oluşabilecek hatalar.
public enum EngineError: Error, Equatable, Sendable {
    case engineNotFound
    case timedOut
    case cancelled
    case sandboxUnavailable
    case failed(code: Int32, message: String)

    /// Çıktıdaki hata/uyarı satırlarını kısa bir özete indirger.
    public static func diagnostic(from output: String, limit: Int = 6) -> String {
        let lines = output
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.contains("\u{8}") }
        let markers = ["ERROR", "WARNING", "error", "warning", "failed", "Cannot", "cannot", "✗"]
        let interesting = lines.filter { line in markers.contains { line.contains($0) } }
        let chosen = interesting.isEmpty ? Array(lines.suffix(3)) : Array(interesting.prefix(limit))
        return chosen.joined(separator: "\n")
    }
}

/// Alt süreçleri çalıştırır; satır satır çıktı, ortam değişkeni, zaman aşımı ve iptal desteği sunar.
public struct CommandRunner: Sendable {
    public let executableURL: URL
    public let sandbox: SandboxProfile?
    public let environmentOverrides: [String: String]

    public init(
        executableURL: URL,
        sandbox: SandboxProfile? = nil,
        environmentOverrides: [String: String] = [:]
    ) {
        self.executableURL = executableURL
        self.sandbox = sandbox
        self.environmentOverrides = environmentOverrides
    }

    public static let maxOutputBytes = 128 << 20
    public static let drainGracePeriod: TimeInterval = 2
    public static let streamTailBytes = 64 << 10

    public func run(
        _ arguments: [String],
        timeout: TimeInterval? = nil,
        maxOutputBytes: Int = CommandRunner.maxOutputBytes,
        workingDirectory: URL? = nil,
        input: Data? = nil,
        retainStdout: Bool = true,
        onRecord: (@Sendable (String) -> Void)? = nil
    ) async throws -> ProcessResult {
        let launch: (URL, [String])
        if let sandbox {
            guard SandboxProfile.isAvailable else { throw EngineError.sandboxUnavailable }
            launch = (SandboxProfile.launcher, sandbox.launchArguments(executable: executableURL, arguments: arguments))
        } else {
            launch = (executableURL, arguments)
        }
        let box = try ProcessBox(
            executableURL: launch.0,
            arguments: launch.1,
            environmentOverrides: environmentOverrides,
            input: input
        )
        if let workingDirectory { box.process.currentDirectoryURL = workingDirectory }
        let state = RunState(onRecord: onRecord, maxOutputBytes: maxOutputBytes, retainStdout: retainStdout)
        state.onLimitExceeded = { box.terminate() }

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<ProcessResult, Error>) in
                let readers = DispatchGroup()
                readers.enter()
                readers.enter()

                box.process.terminationHandler = { finished in
                    let exitCode = finished.terminationStatus
                    ChildProcessGuard.unregister(finished.processIdentifier)
                    DispatchQueue.global().async {
                        _ = readers.wait(timeout: .now() + CommandRunner.drainGracePeriod)
                        continuation.resume(with: state.finish(exitCode: exitCode))
                    }
                }

                do {
                    try box.process.run()
                } catch {
                    box.process.terminationHandler = nil
                    continuation.resume(throwing: EngineError.engineNotFound)
                    return
                }

                let pid = box.process.processIdentifier
                ChildProcessGuard.register(pid, name: executableURL.lastPathComponent)
                if !box.process.isRunning { ChildProcessGuard.unregister(pid) }

                Self.startReader {
                    box.drain(box.stdoutPipe) { state.appendStdout($0) }
                    readers.leave()
                }
                Self.startReader {
                    box.drain(box.stderrPipe) { state.appendStderr($0) }
                    readers.leave()
                }

                if state.isCancelled { box.terminate() }
                if let timeout {
                    DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                        if box.isRunning {
                            state.markTimedOut()
                            box.terminate()
                        }
                    }
                }
            }
        } onCancel: {
            state.markCancelled()
            box.terminate()
        }
    }

    fileprivate static func startReader(_ body: @escaping @Sendable () -> Void) {
        let thread = Thread(block: body)
        thread.name = "CommandRunner.reader"
        thread.start()
    }
}

private final class ProcessBox: @unchecked Sendable {
    let process = Process()
    let stdoutPipe = Pipe()
    let stderrPipe = Pipe()

    init(
        executableURL: URL,
        arguments: [String],
        environmentOverrides: [String: String],
        input: Data?
    ) throws {
        process.executableURL = executableURL
        process.arguments = arguments
        if !environmentOverrides.isEmpty {
            var env = ProcessInfo.processInfo.environment
            for (k, v) in environmentOverrides { env[k] = v }
            process.environment = env
        }
        if let input {
            let stdinPipe = Pipe()
            try stdinPipe.fileHandleForWriting.write(contentsOf: input)
            try stdinPipe.fileHandleForWriting.close()
            process.standardInput = stdinPipe
        } else {
            process.standardInput = FileHandle.nullDevice
        }
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
    }

    var isRunning: Bool { process.isRunning }
    static let killGracePeriod: TimeInterval = 2

    func terminate() {
        guard process.isRunning else { return }
        process.terminate()
        let pid = process.processIdentifier
        DispatchQueue.global().asyncAfter(deadline: .now() + Self.killGracePeriod) { [self] in
            if process.isRunning { kill(pid, SIGKILL) }
        }
    }

    func drain(_ pipe: Pipe, _ consume: (Data) -> Void) {
        let handle = pipe.fileHandleForReading
        while true {
            let data = handle.availableData
            if data.isEmpty { break }
            consume(data)
        }
    }
}

private final class RunState: @unchecked Sendable {
    private let lock = NSLock()
    private var stdout = Data()
    private var stderr = Data()
    private var pending = Data()
    private var totalBytes = 0
    private var cancelled = false
    private var timedOut = false
    private var overflowed = false
    private var finished = false
    private let maxOutputBytes: Int
    private let retainStdout: Bool
    var onLimitExceeded: (@Sendable () -> Void)?
    private let onRecord: (@Sendable (String) -> Void)?

    static let maxRecordBytes = 64 << 10

    init(onRecord: (@Sendable (String) -> Void)?, maxOutputBytes: Int, retainStdout: Bool) {
        self.onRecord = onRecord
        self.maxOutputBytes = maxOutputBytes
        self.retainStdout = retainStdout
    }

    var isCancelled: Bool { lock.withLock { cancelled } }
    func markCancelled() { lock.withLock { cancelled = true } }
    func markTimedOut() { lock.withLock { timedOut = true } }

    func appendStdout(_ data: Data) {
        var records: [String] = []
        var fireLimit = false
        lock.withLock {
            if overflowed || finished { return }
            if retainStdout {
                if totalBytes + data.count > maxOutputBytes {
                    overflowed = true
                    fireLimit = true
                    return
                }
                totalBytes += data.count
                stdout.append(data)
            } else {
                stdout.append(data)
                if stdout.count > CommandRunner.streamTailBytes { stdout = stdout.suffix(CommandRunner.streamTailBytes) }
            }
            guard onRecord != nil else { return }
            pending.append(data)
            var start = pending.startIndex
            for index in pending.indices where pending[index] == 0x0A || pending[index] == 0x0D {
                if index > start { records.append(String(decoding: pending[start..<index], as: UTF8.self)) }
                start = pending.index(after: index)
            }
            pending = pending[start...]
            if pending.count > Self.maxRecordBytes { pending = Data(pending.suffix(Self.maxRecordBytes)) }
        }
        if fireLimit { onLimitExceeded?() }
        for record in records { onRecord?(record) }
    }

    func appendStderr(_ data: Data) {
        var fireLimit = false
        lock.withLock {
            if overflowed || finished { return }
            if totalBytes + data.count > maxOutputBytes {
                overflowed = true
                fireLimit = true
                return
            }
            totalBytes += data.count
            stderr.append(data)
        }
        if fireLimit { onLimitExceeded?() }
    }

    func finish(exitCode: Int32) -> Result<ProcessResult, Error> {
        var tail: String?
        let result: Result<ProcessResult, Error> = lock.withLock {
            finished = true
            if !pending.isEmpty, onRecord != nil {
                tail = String(decoding: pending, as: UTF8.self)
                pending = Data()
            }
            if cancelled { return .failure(EngineError.cancelled) }
            if timedOut { return .failure(EngineError.timedOut) }
            if overflowed {
                return .failure(EngineError.failed(code: exitCode, message: "Output exceeded the size limit and was stopped."))
            }
            return .success(ProcessResult(
                exitCode: exitCode,
                stdout: String(decoding: stdout, as: UTF8.self),
                stderr: String(decoding: stderr, as: UTF8.self)
            ))
        }
        if let tail { onRecord?(tail) }
        return result
    }
}
