// SPDX-License-Identifier: GPL-3.0-or-later
import Darwin
import Foundation

/// Alt süreç bekçisi: çalışan çocuk süreçleri sinyal güvenli (signal-safe) sabit boyutlu bir tabloda izler,
/// normal kapanışta veya ölümcül sinyallerde (SIGTERM/SIGINT/SIGHUP/SIGQUIT/SIGABRT/SIGSEGV/SIGBUS/SIGILL/SIGFPE/SIGTRAP)
/// tüm çocukları sonlandırır ve bir önceki çökmeden kalan yetim süreçleri süpürür.
public enum ChildProcessGuard {
    static let capacity = 64
    private static let nameLimit = 63

    private struct Slot {
        var pid: pid_t = 0
        var startSec: Int = 0
        var startUsec: Int32 = 0
        var name: (
            CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
            CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
            CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
            CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
            CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
            CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
            CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
            CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar
        ) = (
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
        )
    }

    nonisolated(unsafe) private static let slots: UnsafeMutablePointer<Slot> = {
        let p = UnsafeMutablePointer<Slot>.allocate(capacity: capacity)
        p.initialize(repeating: Slot(), count: capacity)
        return p
    }()

    nonisolated(unsafe) private static var lock = os_unfair_lock()

    public static var pidFileURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Curatare/children.pids")
    }

    nonisolated(unsafe) static var customPIDFileURL: URL?

    private static var activePIDFileURL: URL {
        customPIDFileURL ?? pidFileURL
    }

    private static let installOnce: Void = {
        reapOrphansFromPreviousRun()
        atexit { ChildProcessGuard.terminateAll(graceMicroseconds: 200_000) }
        let fatalSignals: [Int32] = [SIGTERM, SIGINT, SIGHUP, SIGQUIT, SIGABRT, SIGSEGV, SIGBUS, SIGILL, SIGFPE, SIGTRAP]
        for sig in fatalSignals {
            var action = sigaction()
            action.__sigaction_u.__sa_handler = { received in
                ChildProcessGuard.killAllFromSignalHandler()
                signal(received, SIG_DFL)
                raise(received)
            }
            sigemptyset(&action.sa_mask)
            action.sa_flags = SA_RESETHAND
            sigaction(sig, &action, nil)
        }
    }()

    public static func install() {
        _ = installOnce
    }

    public static func register(_ pid: pid_t, name: String) {
        guard pid > 0 else { return }
        _ = installOnce
        let start = processStartTime(pid)
        os_unfair_lock_lock(&lock)
        for i in 0..<capacity where slots[i].pid == 0 || slots[i].pid == pid {
            slots[i].pid = pid
            slots[i].startSec = start?.sec ?? 0
            slots[i].startUsec = start?.usec ?? 0
            writeName(name, into: &slots[i])
            break
        }
        os_unfair_lock_unlock(&lock)
        persistPIDFile()
    }

    public static func unregister(_ pid: pid_t) {
        guard pid > 0 else { return }
        os_unfair_lock_lock(&lock)
        for i in 0..<capacity where slots[i].pid == pid {
            slots[i] = Slot()
        }
        os_unfair_lock_unlock(&lock)
        persistPIDFile()
    }

    public static func terminateAll(graceMicroseconds: useconds_t = 300_000) {
        os_unfair_lock_lock(&lock)
        var snapshot: [(pid: pid_t, sec: Int, usec: Int32, name: String)] = []
        for i in 0..<capacity where slots[i].pid > 0 {
            snapshot.append((slots[i].pid, slots[i].startSec, slots[i].startUsec, readName(from: &slots[i])))
            slots[i] = Slot()
        }
        os_unfair_lock_unlock(&lock)

        var alive: [(pid: pid_t, sec: Int, usec: Int32, name: String)] = []
        for item in snapshot where isSameProcess(pid: item.pid, sec: item.sec, usec: item.usec, name: item.name) {
            kill(item.pid, SIGTERM)
            alive.append(item)
        }
        if !alive.isEmpty && graceMicroseconds > 0 {
            usleep(graceMicroseconds)
            for item in alive where isSameProcess(pid: item.pid, sec: item.sec, usec: item.usec, name: item.name) {
                kill(item.pid, SIGKILL)
            }
        }
        persistPIDFile()
    }

    static func killAllFromSignalHandler() {
        for i in 0..<capacity {
            let pid = slots[i].pid
            if pid > 0 {
                kill(pid, SIGKILL)
                slots[i].pid = 0
            }
        }
    }

    static func reapOrphansFromPreviousRun() {
        let url = activePIDFileURL
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return }
        try? FileManager.default.removeItem(at: url)
        for line in content.split(whereSeparator: \.isNewline) {
            let parts = line.split(separator: "\t")
            guard parts.count >= 4,
                  let pid = pid_t(parts[0]),
                  let sec = Int(parts[1]),
                  let usec = Int32(parts[2]) else { continue }
            let name = String(parts[3])
            if isSameProcess(pid: pid, sec: sec, usec: usec, name: name) {
                kill(pid, SIGTERM)
                usleep(100_000)
                if isSameProcess(pid: pid, sec: sec, usec: usec, name: name) {
                    kill(pid, SIGKILL)
                }
            }
        }
    }

    private static func persistPIDFile() {
        let url = activePIDFileURL
        os_unfair_lock_lock(&lock)
        var lines: [String] = []
        for i in 0..<capacity where slots[i].pid > 0 {
            let name = readName(from: &slots[i])
            lines.append("\(slots[i].pid)\t\(slots[i].startSec)\t\(slots[i].startUsec)\t\(name)")
        }
        os_unfair_lock_unlock(&lock)

        if lines.isEmpty {
            try? FileManager.default.removeItem(at: url)
            return
        }
        let dir = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let text = lines.joined(separator: "\n") + "\n"
        try? text.write(to: url, atomically: true, encoding: .utf8)
    }

    private static func writeName(_ name: String, into slot: inout Slot) {
        let utf8 = Array(name.utf8.prefix(nameLimit))
        withUnsafeMutableBytes(of: &slot.name) { buf in
            for i in 0..<buf.count { buf[i] = 0 }
            for (idx, byte) in utf8.enumerated() {
                buf[idx] = byte
            }
        }
    }

    private static func readName(from slot: inout Slot) -> String {
        withUnsafePointer(to: &slot.name) { ptr in
            ptr.withMemoryRebound(to: CChar.self, capacity: nameLimit + 1) {
                String(cString: $0)
            }
        }
    }

    private static func processStartTime(_ pid: pid_t) -> (sec: Int, usec: Int32)? {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
        guard sysctl(&mib, 4, &info, &size, nil, 0) == 0, size > 0 else { return nil }
        let tv = info.kp_proc.p_un.__p_starttime
        return (tv.tv_sec, tv.tv_usec)
    }

    private static func processCommandName(_ pid: pid_t) -> String? {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
        guard sysctl(&mib, 4, &info, &size, nil, 0) == 0, size > 0 else { return nil }
        return withUnsafePointer(to: &info.kp_proc.p_comm) { ptr in
            ptr.withMemoryRebound(to: CChar.self, capacity: Int(MAXCOMLEN) + 1) {
                String(cString: $0)
            }
        }
    }

    private static func isSameProcess(pid: pid_t, sec: Int, usec: Int32, name: String) -> Bool {
        guard pid > 0, let current = processStartTime(pid) else { return false }
        if sec > 0 && (current.sec != sec || current.usec != usec) { return false }
        if !name.isEmpty, let comm = processCommandName(pid) {
            let prefix = String(name.prefix(Int(MAXCOMLEN)))
            if !comm.hasPrefix(prefix) && !prefix.hasPrefix(comm) && comm != "sandbox-exec" && comm != "bash" {
                return false
            }
        }
        return true
    }
}
