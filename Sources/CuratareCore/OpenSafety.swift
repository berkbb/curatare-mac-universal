// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation
import UniformTypeIdentifiers

/// Dosya adlarının ve yolların güvenle gösterilmesi: riskli türler ve adın gerçek uzantısını gizleyen karakterler.
public enum OpenSafety {
    static let riskyTypes: [UTType] = [
        .executable, .script, .application, .applicationBundle, .unixExecutable, .internetLocation,
        .diskImage,
    ] + [
        "com.apple.installer-package-archive",
        "com.apple.mobileconfig",
        "com.apple.terminal.settings",
        "com.apple.terminal.session",
        "com.apple.automator-workflow",
        "com.apple.applescript.script",
        "com.apple.applescript.text",
        "com.apple.applescript.script-bundle",
        "com.apple.shortcut",
        "com.apple.systempreference.prefpane",
        "com.apple.quicklook.generator",
    ].compactMap { UTType($0) }

    static let riskyExtensions: Set<String> = [
        "scpt", "scptd", "applescript", "shortcut", "prefpane", "qlgenerator",
        "workflow", "action", "osax", "url", "webloc", "term", "terminal",
    ]

    public static func executableKind(of url: URL) -> String? {
        let resolved = url.resolvingSymlinksInPath()
        let values = try? resolved.resourceValues(forKeys: [.contentTypeKey, .isRegularFileKey])
        if let type = values?.contentType, riskyTypes.contains(where: { type.conforms(to: $0) }) {
            return type.localizedDescription ?? type.identifier
        }
        if riskyExtensions.contains(resolved.pathExtension.lowercased()) {
            return values?.contentType?.localizedDescription ?? resolved.pathExtension
        }
        if values?.isRegularFile == true,
           let permissions = (try? FileManager.default.attributesOfItem(atPath: resolved.path))?[.posixPermissions] as? NSNumber,
           permissions.uint16Value & 0o111 != 0 {
            return values?.contentType?.localizedDescription ?? "Unix executable"
        }
        return nil
    }

    public static func hasDeceptiveCharacters(_ name: String) -> Bool {
        var previous: Unicode.Scalar?
        for scalar in name.unicodeScalars {
            if isDeceptive(scalar, after: previous) { return true }
            previous = scalar
        }
        return false
    }

    public static func visibleName(_ name: String) -> String {
        var result = ""
        var previous: Unicode.Scalar?
        for scalar in name.unicodeScalars {
            if isDeceptive(scalar, after: previous) {
                result += String(format: "⟦U+%04X⟧", scalar.value)
            } else {
                result.unicodeScalars.append(scalar)
            }
            previous = scalar
        }
        return result
    }

    static let blankFillers: Set<UInt32> = [0x2800, 0x3164, 0x115F, 0x1160, 0xFFA0]
    static let emojiVariationSelectors: Set<UInt32> = [0xFE0E, 0xFE0F]

    static func isDeceptive(_ scalar: Unicode.Scalar, after previous: Unicode.Scalar? = nil) -> Bool {
        if blankFillers.contains(scalar.value) { return true }
        switch scalar.properties.generalCategory {
        case .format, .control, .lineSeparator, .paragraphSeparator:
            return true
        default:
            break
        }
        guard scalar.properties.isDefaultIgnorableCodePoint else { return false }
        if emojiVariationSelectors.contains(scalar.value), previous?.properties.isEmoji == true { return false }
        return true
    }
}
