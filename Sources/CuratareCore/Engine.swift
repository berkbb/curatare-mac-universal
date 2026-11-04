// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation

/// Bulunan Mole motoru hakkında bilgi.
public struct EngineInfo: Sendable, Equatable {
    public let url: URL
    public let version: String
    public let source: Source

    public enum Source: String, Sendable, Equatable {
        case bundled
        case userUpdated
        case homebrew
        case systemPath
        case custom
    }

    public init(url: URL, version: String, source: Source) {
        self.url = url
        self.version = version
        self.source = source
    }

    /// Mole'un kök klasörü (`mole`, `bin/analyze-go`, `bin/status-go`, `lib/` öğelerini barındıran dizin).
    public var rootDirectory: URL {
        let resolved = url.resolvingSymlinksInPath()
        return resolved.deletingLastPathComponent()
    }

    /// `bin/analyze-go` yardımcısının yolu (varsa).
    public var analyzeGoURL: URL? {
        let candidate = rootDirectory.appendingPathComponent("bin/analyze-go")
        return FileManager.default.isExecutableFile(atPath: candidate.path) ? candidate : nil
    }

    /// `bin/status-go` yardımcısının yolu (varsa).
    public var statusGoURL: URL? {
        let candidate = rootDirectory.appendingPathComponent("bin/status-go")
        return FileManager.default.isExecutableFile(atPath: candidate.path) ? candidate : nil
    }
}

/// Sistemde veya uygulama paketinde `mole` motorunu bulur.
///
/// Arama sırası:
/// 1. Kullanıcının seçtiği özel yol veya `CURATARE_MOLE` ortam değişkeni
/// 2. Kullanıcının uygulama içinden GitHub'dan güncellediği motor (`~/Library/Application Support/Curatare/engine/mole`)
/// 3. Uygulama paketinin içindeki motor (`Curatare.app/Contents/Resources/mole/mole` veya `Contents/MacOS/mole`)
/// 4. Geliştirme ağacındaki `Vendor/mole/mole`
/// 5. Homebrew / yerel kurulum yolları (`/opt/homebrew/opt/mole/libexec/mole`, `/opt/homebrew/bin/mole`, `/usr/local/bin/mole`)
public enum EngineLocator {
    public static var userEngineDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("Curatare/engine", isDirectory: true)
    }

    public static var userEngineURL: URL {
        userEngineDirectory.appendingPathComponent("mole")
    }

    private static let searchPaths: [(String, EngineInfo.Source)] = [
        ("/opt/homebrew/opt/mole/libexec/mole", .homebrew),
        ("/opt/homebrew/bin/mole", .homebrew),
        ("/usr/local/opt/mole/libexec/mole", .homebrew),
        ("/usr/local/bin/mole", .homebrew),
    ]

    public static func locate(customPath: String? = nil, bundle: Bundle = .main) -> (url: URL, source: EngineInfo.Source)? {
        let fm = FileManager.default

        if let custom = customPath, !custom.isEmpty, fm.isExecutableFile(atPath: custom) {
            return (URL(fileURLWithPath: custom), .custom)
        }

        if let env = ProcessInfo.processInfo.environment["CURATARE_MOLE"],
           !env.isEmpty, fm.isExecutableFile(atPath: env) {
            return (URL(fileURLWithPath: env), .custom)
        }

        let userBin = userEngineURL
        if fm.isExecutableFile(atPath: userBin.path) {
            return (userBin, .userUpdated)
        }

        if let execDir = bundle.executableURL?.deletingLastPathComponent() {
            let bundled = execDir.appendingPathComponent("mole")
            if fm.isExecutableFile(atPath: bundled.path) {
                return (bundled, .bundled)
            }
        }

        if let resURL = bundle.resourceURL?.appendingPathComponent("mole/mole"),
           fm.isExecutableFile(atPath: resURL.path) {
            return (resURL, .bundled)
        }

        // Geliştirme sırasında (`swift test` / `swift run`) proje kökündeki `Vendor/mole/mole`
        let repoVendor = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Vendor/mole/mole")
        if fm.isExecutableFile(atPath: repoVendor.path) {
            return (repoVendor, .bundled)
        }

        for (path, source) in searchPaths where fm.isExecutableFile(atPath: path) {
            return (URL(fileURLWithPath: path), source)
        }

        return nil
    }

    public static func inspect(customPath: String? = nil, bundle: Bundle = .main) async -> EngineInfo? {
        guard let found = locate(customPath: customPath, bundle: bundle) else { return nil }
        let runner = CommandRunner(executableURL: found.url)
        // `mole --version` boşta ~0,5 sn sürer; işlemci yükü altında (oturum açılışı, paralel testler) 7 sn'yi
        // geçebilir. Süre kısa olursa motor bulunduğu halde sürümü "bilinmiyor" görünür.
        let output = (try? await runner.run(["--version"], timeout: 20).stdout) ?? ""
        let version = parseVersion(from: output) ?? "unknown"
        return EngineInfo(url: found.url, version: version, source: found.source)
    }

    /// `mole --version` çıktısından sürüm numarasını (`"Mole version 1.67.0"` -> `"1.67.0"`) ayıklar.
    public static func parseVersion(from output: String) -> String? {
        let pattern = #"Mole\s+version\s+[vV]?([0-9]+(?:\.[0-9]+)+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: output, range: NSRange(output.startIndex..., in: output)),
              let range = Range(match.range(at: 1), in: output) else {
            return nil
        }
        return String(output[range])
    }
}

/// `Scripts/update-mole.sh` betiğini çalıştırarak `tw93/Mole` GitHub sürümlerinden Mole'u denetler ve günceller.
public enum EngineUpdateResult: Sendable, Equatable {
    case upToDate(version: String)
    case updateAvailable(current: String?, latest: String, source: String?)
    case installed(version: String, path: String)
}

public enum EngineUpdater {
    public static func locateScript(bundle: Bundle = .main) -> URL? {
        let fm = FileManager.default
        if let res = bundle.resourceURL?.appendingPathComponent("Scripts/update-mole.sh"),
           fm.isExecutableFile(atPath: res.path) {
            return res
        }
        let devScript = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Scripts/update-mole.sh")
        if fm.isExecutableFile(atPath: devScript.path) {
            return devScript
        }
        return nil
    }

    public static func check(currentVersion: String?, scriptURL: URL? = locateScript()) async throws -> EngineUpdateResult {
        guard let script = scriptURL else {
            throw EngineError.failed(code: -1, message: "update-mole.sh not found")
        }
        var args = ["check", "--dest", EngineLocator.userEngineDirectory.path]
        if let currentVersion { args += ["--current", currentVersion] }
        return try await runScript(script, arguments: args)
    }

    public static func install(
        force: Bool = false,
        localSeed: Bool = false,
        destination: URL = EngineLocator.userEngineDirectory,
        scriptURL: URL? = locateScript(),
        onLog: (@Sendable (String) -> Void)? = nil
    ) async throws -> EngineUpdateResult {
        guard let script = scriptURL else {
            throw EngineError.failed(code: -1, message: "update-mole.sh not found")
        }
        var args = ["install", "--dest", destination.path]
        if force { args.append("--force") }
        if localSeed { args.append("--local-seed") }
        return try await runScript(script, arguments: args, onLog: onLog)
    }

    private static func runScript(
        _ script: URL,
        arguments: [String],
        onLog: (@Sendable (String) -> Void)? = nil
    ) async throws -> EngineUpdateResult {
        let runner = CommandRunner(executableURL: script)
        let result = try await runner.run(arguments, timeout: 600, onRecord: onLog)
        if !result.stderr.isEmpty { onLog?(result.stderr) }
        guard result.exitCode == 0 else {
            throw EngineError.failed(
                code: result.exitCode,
                message: EngineError.diagnostic(from: result.stderr + "\n" + result.stdout)
            )
        }
        return try parseScriptOutput(result.stdout)
    }

    public static func parseScriptOutput(_ stdout: String) throws -> EngineUpdateResult {
        var kv: [String: String] = [:]
        for line in stdout.split(whereSeparator: \.isNewline) {
            guard let eq = line.firstIndex(of: "=") else { continue }
            let key = String(line[..<eq]).trimmingCharacters(in: .whitespaces)
            let value = String(line[line.index(after: eq)...]).trimmingCharacters(in: .whitespaces)
            kv[key] = value
        }
        let latest = kv["LATEST"] ?? "unknown"
        let current = kv["CURRENT"].flatMap { $0 == "none" || $0.isEmpty ? nil : $0 }
        switch kv["STATUS"] {
        case "up-to-date":
            return .upToDate(version: current ?? latest)
        case "update-available":
            return .updateAvailable(current: current, latest: latest, source: kv["SOURCE"])
        case "installed":
            return .installed(version: latest, path: kv["INSTALLED"] ?? "")
        default:
            throw EngineError.failed(code: -1, message: stdout)
        }
    }
}
