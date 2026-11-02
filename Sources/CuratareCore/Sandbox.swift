// SPDX-License-Identifier: GPL-3.0-or-later
import Darwin
import Foundation

/// Mole ve yardımcı ikilileri (`analyze-go`, `status-go`, `mole`) en az yetkiyle çalıştırmak için
/// `sandbox-exec` profili üretir.
///
/// Temel güvenceler:
/// - Ağ erişimi tamamen kapatılır (`(deny network*)`).
/// - Kişisel kimlik bilgisi ve anahtar klasörleri (`~/.ssh`, `~/.gnupg`, `~/.aws`, `~/Library/Keychains`) okunamaz/yazılamaz.
/// - Salt okunur taramalarda (`/dev` ve geçici scratch dizini dışında) tüm dosya yazmaları engellenir.
/// - Çöp'e taşıma / Mole çalıştırmalarında yazma yalnızca tarihli `~/.Trash` klasörüne ve Mole yapılandırma/günlük
///   klasörlerine izin verir.
public struct SandboxProfile: Sendable, Equatable {
    public static let launcher = URL(fileURLWithPath: "/usr/bin/sandbox-exec")

    public static var isAvailable: Bool {
        FileManager.default.isExecutableFile(atPath: launcher.path)
    }

    public let writableDirectories: [URL]
    public let allowsSubprocessExec: Bool

    public init(writableDirectories: [URL] = [], allowsSubprocessExec: Bool = true) {
        self.writableDirectories = writableDirectories
        self.allowsSubprocessExec = allowsSubprocessExec
    }

    /// Salt okunur disk / durum taraması (`status-go`, `analyze-go` vb.) için profil.
    public static func readingOnly(scratchDirectory: URL? = nil) -> SandboxProfile {
        if let scratchDirectory {
            return SandboxProfile(writableDirectories: [scratchDirectory], allowsSubprocessExec: false)
        }
        return SandboxProfile(writableDirectories: [], allowsSubprocessExec: false)
    }

    /// Mole betikleri (`mole clean --dry-run`, `mole uninstall --list` vb.) için profil:
    /// yalnızca belirtilen yapılandırma/önbellek/tarihli Çöp klasörlerine yazabilir, ağa çıkamaz.
    public static func forMole(writableDirectories: [URL]) -> SandboxProfile {
        SandboxProfile(writableDirectories: writableDirectories, allowsSubprocessExec: true)
    }

    /// Kullanıcının kimlik ve anahtar klasörleri — hiçbir tarayıcı veya yardımcı süreç bunlara dokunamaz.
    public static var sensitiveCredentialFolders: [URL] {
        let home = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
        return [
            home.appendingPathComponent(".ssh", isDirectory: true),
            home.appendingPathComponent(".gnupg", isDirectory: true),
            home.appendingPathComponent(".aws", isDirectory: true),
            home.appendingPathComponent(".kube", isDirectory: true),
            home.appendingPathComponent("Library/Keychains", isDirectory: true),
        ]
    }

    public func schemeSource(executable: URL? = nil) -> String {
        var lines = [
            "(version 1)",
            "(allow default)",
            "(deny network*)",
            "(deny file-write*)",
            "(allow file-write* (subpath \"/dev\"))",
        ]

        for dir in writableDirectories {
            for path in Self.sandboxPaths(for: dir) {
                lines.append("(allow file-write* (subpath \"\(Self.escapeSchemeString(path))\"))")
            }
        }

        for denied in Self.sensitiveCredentialFolders {
            for path in Self.sandboxPaths(for: denied) {
                lines.append("(deny file-read-data (subpath \"\(Self.escapeSchemeString(path))\"))")
                lines.append("(deny file-write* (subpath \"\(Self.escapeSchemeString(path))\"))")
            }
        }

        if !allowsSubprocessExec, let executable {
            lines.append("(deny process-exec)")
            for path in Self.sandboxPaths(for: executable) {
                lines.append("(allow process-exec (literal \"\(Self.escapeSchemeString(path))\"))")
            }
        }

        return lines.joined(separator: "\n")
    }

    public func launchArguments(executable: URL, arguments: [String]) -> [String] {
        ["-p", schemeSource(executable: executable), "--", executable.path] + arguments
    }

    static func sandboxPaths(for url: URL) -> [String] {
        let standardized = url.standardizedFileURL.path
        let resolved = realPath(of: url)
        return resolved == standardized ? [resolved] : [resolved, standardized]
    }

    static func realPath(of url: URL) -> String {
        var existing = url.standardizedFileURL
        var missingTail: [String] = []
        while existing.path != "/" {
            var buffer = [CChar](repeating: 0, count: Int(PATH_MAX))
            if let resolvedPtr = Darwin.realpath(existing.path, &buffer) {
                var base = URL(fileURLWithPath: String(cString: resolvedPtr))
                for component in missingTail.reversed() {
                    base.appendPathComponent(component)
                }
                return base.path
            }
            missingTail.append(existing.lastPathComponent)
            existing.deleteLastPathComponent()
        }
        return url.resolvingSymlinksInPath().standardizedFileURL.path
    }

    static func escapeSchemeString(_ value: String) -> String {
        let sanitized = value.replacingOccurrences(of: "\0", with: "")
        return sanitized
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
