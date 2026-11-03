// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation

// MARK: - Taşınabilir Kurallar Dosyası (özel koruma listesi ve Mole purge yolları)

/// Özel koruma listesini (beyaz liste) ve Mole purge yollarını başka bir Mac'e taşıyan JSON belgesi.
/// Ev klasörü altındaki yollar `~/` ile yazılır; böylece kullanıcı adı farklı bir Mac'te de aynı klasörü gösterir.
///
/// Geriye ve ileriye uyumluluk: `version` alanı biçim sürümünü taşır. Bilinmeyen alanlar yok sayılır,
/// eksik alanlar varsayılan değer alır. Metin olmayan girişler belgeyi bozmaz; doğrulamada reddedilir.
public struct PortableRulesDocument: Sendable, Equatable {
    public static let currentVersion = 1
    public static let formatIdentifier = "com.babadogantech.curatare.rules"

    public var version: Int
    public var exportedAt: Date?
    public var whitelist: [String]
    public var purgePaths: [String]
    /// Dosyada ilgili bölümün anahtarı var mıydı. "Değiştir" kipinde yalnızca dosyada bulunan bölümler değiştirilir.
    public var hasWhitelistSection: Bool
    public var hasPurgePathsSection: Bool
    /// Metin olmayan (sayı, nesne vb.) girişlerin sayısı.
    public var nonTextWhitelistEntries: Int
    public var nonTextPurgePathEntries: Int

    public init(
        version: Int = PortableRulesDocument.currentVersion,
        exportedAt: Date? = nil,
        whitelist: [String] = [],
        purgePaths: [String] = [],
        hasWhitelistSection: Bool = true,
        hasPurgePathsSection: Bool = true,
        nonTextWhitelistEntries: Int = 0,
        nonTextPurgePathEntries: Int = 0
    ) {
        self.version = version
        self.exportedAt = exportedAt
        self.whitelist = whitelist
        self.purgePaths = purgePaths
        self.hasWhitelistSection = hasWhitelistSection
        self.hasPurgePathsSection = hasPurgePathsSection
        self.nonTextWhitelistEntries = nonTextWhitelistEntries
        self.nonTextPurgePathEntries = nonTextPurgePathEntries
    }

    /// Dosya bu sürümün tanıdığından daha yeni bir biçimle yazıldıysa `true`; bilinen alanlar yine okunur.
    public var isNewerThanSupported: Bool { version > Self.currentVersion }
}

extension PortableRulesDocument: Codable {
    private enum CodingKeys: String, CodingKey {
        case format, version, exportedAt, whitelist, purgePaths
    }

    /// Her değeri tüketip yok sayar; metin olmayan dizi girişlerini atlamak için kullanılır.
    private struct DiscardedValue: Decodable {
        init(from decoder: Decoder) throws {}
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let format = try? container.decodeIfPresent(String.self, forKey: .format),
           format != Self.formatIdentifier {
            throw PortableRulesError.unrecognizedFormat(format)
        }
        let version = (try? container.decodeIfPresent(Int.self, forKey: .version)) ?? nil
        self.version = max(version ?? 1, 1)
        self.exportedAt = (try? container.decodeIfPresent(Date.self, forKey: .exportedAt)) ?? nil
        (whitelist, hasWhitelistSection, nonTextWhitelistEntries) = Self.decodeTextList(container, forKey: .whitelist)
        (purgePaths, hasPurgePathsSection, nonTextPurgePathEntries) = Self.decodeTextList(container, forKey: .purgePaths)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(Self.formatIdentifier, forKey: .format)
        try container.encode(version, forKey: .version)
        try container.encodeIfPresent(exportedAt, forKey: .exportedAt)
        try container.encode(whitelist, forKey: .whitelist)
        try container.encode(purgePaths, forKey: .purgePaths)
    }

    private static func decodeTextList(
        _ container: KeyedDecodingContainer<CodingKeys>,
        forKey key: CodingKeys
    ) -> (values: [String], isPresent: Bool, nonTextCount: Int) {
        guard container.contains(key), !((try? container.decodeNil(forKey: key)) ?? false) else {
            return ([], false, 0)
        }
        guard var list = try? container.nestedUnkeyedContainer(forKey: key) else {
            // Dizi yerine tek bir değer yazılmış; bölüm var sayılır ama giriş kabul edilmez.
            return ([], true, 1)
        }
        var values: [String] = []
        var nonText = 0
        while !list.isAtEnd {
            if (try? list.decodeNil()) == true {
                nonText += 1
            } else if let text = try? list.decode(String.self) {
                values.append(text)
            } else if (try? list.decode(DiscardedValue.self)) != nil {
                nonText += 1
            } else {
                break
            }
        }
        return (values, true, nonText)
    }
}

public enum PortableRulesError: Error, Equatable, Sendable {
    case fileTooLarge(maximumBytes: Int)
    case unreadable
    case unrecognizedFormat(String)
}

// MARK: - Doğrulama

/// İçe aktarılan dosyadaki bir girişin neden kabul edilmediği.
public struct PortableRuleRejection: Sendable, Equatable, Identifiable {
    public enum Section: String, Sendable, Equatable, CaseIterable {
        case whitelist
        case purgePaths

        public var titleKey: LKey {
            switch self {
            case .whitelist: .rulesSectionWhitelist
            case .purgePaths: .rulesSectionPurgePaths
            }
        }
    }

    public enum Reason: Sendable, Equatable {
        case notText
        case invalidCharacters
        case notAbsolute
        case wildcardNotAllowed
        case tooBroad
        /// Yerleşik "Dokunulmayacaklar Listesi"nde; `ProtectionDecision.reason` metnini taşır.
        case protected(String)

        public var titleKey: LKey {
            switch self {
            case .notText: .rulesRejectNotText
            case .invalidCharacters: .rulesRejectInvalidCharacters
            case .notAbsolute: .rulesRejectNotAbsolute
            case .wildcardNotAllowed: .rulesRejectWildcard
            case .tooBroad: .rulesRejectTooBroad
            case .protected: .rulesRejectProtected
            }
        }
    }

    public let id: Int
    public let section: Section
    /// Dosyada yazıldığı biçimiyle giriş (metin olmayan girişlerde boş).
    public let entry: String
    public let reason: Reason
}

/// Doğrulamadan geçen girişler ve reddedilenler.
public struct PortableRulesValidation: Sendable, Equatable {
    /// Bu Mac'in ev klasörüne açılmış, standartlaştırılmış mutlak yollar (`AppSettings.customWhitelistPaths` biçimi).
    public var whitelist: [String]
    /// Mole `purge_paths` dosyasına yazılacak taşınabilir (`~/`) biçim.
    public var purgePaths: [String]
    public var rejected: [PortableRuleRejection]
    public var hasWhitelistSection: Bool
    public var hasPurgePathsSection: Bool
    public var sourceVersion: Int

    public var isNewerThanSupported: Bool { sourceVersion > PortableRulesDocument.currentVersion }
}

public enum PortableRules {
    /// İçe aktarılacak dosya için üst sınır; kural listeleri birkaç kilobaytı nadiren geçer.
    public static let maximumFileSize = 1_048_576

    // MARK: Dışa aktarma

    /// Ayarlardaki beyaz listeden ve Mole purge yollarından taşınabilir belge üretir.
    public static func makeDocument(
        whitelist: [String],
        purgePaths: [String],
        homeDirectory: URL,
        exportedAt: Date = Date()
    ) -> PortableRulesDocument {
        let home = homePath(homeDirectory)
        func portableList(_ list: [String]) -> [String] {
            var seen: Set<String> = []
            var result: [String] = []
            for raw in list {
                let trimmed = raw.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { continue }
                let portable = expandedPath(trimmed, home: home).map { portablePath($0, home: home) } ?? trimmed
                if seen.insert(portable.lowercased()).inserted {
                    result.append(portable)
                }
            }
            return result
        }
        return PortableRulesDocument(
            exportedAt: exportedAt,
            whitelist: portableList(whitelist),
            purgePaths: portableList(purgePaths)
        )
    }

    public static func encode(_ document: PortableRulesDocument) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(document)
    }

    // MARK: İçe aktarma

    /// Dosyayı boyut sınırını aşmadan okur ve çözer; hiçbir dosyayı değiştirmez.
    public static func readDocument(at url: URL) throws -> PortableRulesDocument {
        let values = try? url.resourceValues(forKeys: [.fileSizeKey])
        if let size = values?.fileSize, size > maximumFileSize {
            throw PortableRulesError.fileTooLarge(maximumBytes: maximumFileSize)
        }
        guard let data = try? Data(contentsOf: url) else { throw PortableRulesError.unreadable }
        return try decode(data)
    }

    public static func decode(_ data: Data) throws -> PortableRulesDocument {
        guard data.count <= maximumFileSize else {
            throw PortableRulesError.fileTooLarge(maximumBytes: maximumFileSize)
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            return try decoder.decode(PortableRulesDocument.self, from: data)
        } catch let error as PortableRulesError {
            throw error
        } catch {
            throw PortableRulesError.unreadable
        }
    }

    /// Her girişi denetler. Yerleşik koruma listesindeki (`com.apple.*`, kimlik kasaları, ortak çatılar, aktif YZ
    /// durumu, kardeş uygulamalar vb.) yollar reddedilir; purge yolları ayrıca sistem ve çok geniş konumlara karşı denetlenir.
    /// `rules` içindeki kullanıcı beyaz listesi ve "izin ver" seçenekleri yok sayılır: yalnızca yerleşik liste uygulanır.
    public static func validate(
        _ document: PortableRulesDocument,
        homeDirectory: URL,
        rules: ProtectionRules = ProtectionRules()
    ) -> PortableRulesValidation {
        let home = homePath(homeDirectory)
        var builtIn = rules
        builtIn.userWhitelistPatterns = []
        builtIn.allowUninstallingProtectedApps = false
        builtIn.allowDeveloperCacheCleaning = false
        builtIn.allowUserCacheCleaning = false

        var rejected: [PortableRuleRejection] = []
        func reject(_ section: PortableRuleRejection.Section, _ entry: String, _ reason: PortableRuleRejection.Reason) {
            rejected.append(PortableRuleRejection(id: rejected.count, section: section, entry: entry, reason: reason))
        }

        func accepted(_ list: [String], section: PortableRuleRejection.Section) -> [String] {
            var seen: Set<String> = []
            var result: [String] = []
            for raw in list {
                let trimmed = raw.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { continue }
                if containsControlCharacters(trimmed) {
                    reject(section, trimmed, .invalidCharacters)
                    continue
                }
                guard let absolute = expandedPath(trimmed, home: home) else {
                    reject(section, trimmed, .notAbsolute)
                    continue
                }
                if section == .purgePaths {
                    if absolute.contains("*") {
                        reject(section, trimmed, .wildcardNotAllowed)
                        continue
                    }
                    if isTooBroadForPurge(absolute, home: home) {
                        reject(section, trimmed, .tooBroad)
                        continue
                    }
                }
                let decision = builtIn.evaluate(path: absolute)
                if decision.isProtected {
                    reject(section, trimmed, .protected(decision.reason ?? ""))
                    continue
                }
                let stored = section == .whitelist ? absolute : portablePath(absolute, home: home)
                if seen.insert(absolute.lowercased()).inserted {
                    result.append(stored)
                }
            }
            return result
        }

        let whitelist = accepted(document.whitelist, section: .whitelist)
        for _ in 0..<document.nonTextWhitelistEntries { reject(.whitelist, "", .notText) }
        let purgePaths = accepted(document.purgePaths, section: .purgePaths)
        for _ in 0..<document.nonTextPurgePathEntries { reject(.purgePaths, "", .notText) }

        return PortableRulesValidation(
            whitelist: whitelist,
            purgePaths: purgePaths,
            rejected: rejected,
            hasWhitelistSection: document.hasWhitelistSection,
            hasPurgePathsSection: document.hasPurgePathsSection,
            sourceVersion: document.version
        )
    }

    // MARK: Yol yardımcıları

    /// `~` ve `~/` ile başlayan yolları verilen ev klasörüne açar; mutlak olmayan yollar için `nil`.
    /// `~kullanıcı` biçimi taşınabilir olmadığından kabul edilmez.
    public static func expandedPath(_ raw: String, homeDirectory: URL) -> String? {
        expandedPath(raw, home: homePath(homeDirectory))
    }

    /// Ev klasörü altındaki mutlak yolu `~/` biçimine çevirir.
    public static func portablePath(_ absolute: String, homeDirectory: URL) -> String {
        portablePath(absolute, home: homePath(homeDirectory))
    }

    private static func homePath(_ homeDirectory: URL) -> String {
        (homeDirectory.path as NSString).standardizingPath
    }

    private static func expandedPath(_ raw: String, home: String) -> String? {
        let expanded: String
        if raw == "~" {
            expanded = home
        } else if raw.hasPrefix("~/") {
            expanded = home + raw.dropFirst(1)
        } else if raw.hasPrefix("/") {
            expanded = raw
        } else {
            return nil
        }
        return (expanded as NSString).standardizingPath
    }

    private static func portablePath(_ absolute: String, home: String) -> String {
        if absolute == home { return "~" }
        if absolute.hasPrefix(home + "/") { return "~" + absolute.dropFirst(home.count) }
        return absolute
    }

    private static func containsControlCharacters(_ text: String) -> Bool {
        text.unicodeScalars.contains {
            $0.properties.generalCategory == .control || CharacterSet.newlines.contains($0)
        }
    }

    /// Purge taraması proje klasörlerinde derleme çıktısı arar; sistem konumları, uygulamalar, Kitaplık ve Çöp Sepeti
    /// hiçbir zaman proje klasörü değildir. Kitaplık içinde yalnızca bulut sürücü klasörleri kabul edilir.
    private static func isTooBroadForPurge(_ absolute: String, home: String) -> Bool {
        let path = absolute.lowercased()
        let lowerHome = home.lowercased()
        let exactRoots = ["/", lowerHome, "/users", "/volumes"]
        if exactRoots.contains(path) { return true }

        func isInside(_ root: String) -> Bool { path == root || path.hasPrefix(root + "/") }
        // Ev klasörünün içi yalnızca eve göre kurallarla değerlendirilir (ev klasörü `/var` altında olsa bile).
        if isInside(lowerHome) {
            let cloudFolders = [lowerHome + "/library/cloudstorage", lowerHome + "/library/mobile documents"]
            if cloudFolders.contains(where: isInside) { return false }
            return [lowerHome + "/library", lowerHome + "/applications", lowerHome + "/.trash"].contains(where: isInside)
        }
        let systemTrees = [
            "/system", "/library", "/applications", "/private", "/usr", "/bin", "/sbin", "/etc", "/var", "/tmp",
            "/opt", "/dev", "/cores",
        ]
        return systemTrees.contains(where: isInside)
    }
}

// MARK: - İçe Aktarma Planı (Birleştir / Değiştir)

public enum PortableRulesImportMode: String, Sendable, CaseIterable, Identifiable {
    /// Mevcut girişler korunur, yalnızca yeni girişler eklenir (güvenli varsayılan).
    case merge
    /// Dosyada bulunan bölümler mevcut listenin yerini alır.
    case replace

    public var id: String { rawValue }

    public var titleKey: LKey {
        switch self {
        case .merge: .rulesImportModeMerge
        case .replace: .rulesImportModeReplace
        }
    }

    public var noteKey: LKey {
        switch self {
        case .merge: .rulesImportModeMergeNote
        case .replace: .rulesImportModeReplaceNote
        }
    }
}

/// Önizlemede gösterilen ve onaylanınca uygulanan değişiklikler. Yalnızca ayar listeleri değişir;
/// hiçbir dosya silinmez veya taşınmaz.
public struct PortableRulesImportPlan: Sendable, Equatable {
    public let mode: PortableRulesImportMode
    public let whitelistToAdd: [String]
    public let whitelistToRemove: [String]
    public let purgePathsToAdd: [String]
    public let purgePathsToRemove: [String]
    public let resultingWhitelist: [String]
    public let resultingPurgePaths: [String]

    public init(
        validation: PortableRulesValidation,
        currentWhitelist: [String],
        currentPurgePaths: [String],
        mode: PortableRulesImportMode,
        homeDirectory: URL
    ) {
        self.mode = mode
        func key(_ path: String) -> String {
            (PortableRules.expandedPath(path, homeDirectory: homeDirectory) ?? path).lowercased()
        }
        func diff(current: [String], imported: [String], replaces: Bool) -> (add: [String], remove: [String], result: [String]) {
            let currentKeys = Set(current.map(key))
            let importedKeys = Set(imported.map(key))
            let add = imported.filter { !currentKeys.contains(key($0)) }
            guard replaces else { return (add, [], current + add) }
            let remove = current.filter { !importedKeys.contains(key($0)) }
            let kept = current.filter { importedKeys.contains(key($0)) }
            return (add, remove, kept + add)
        }

        let whitelist = diff(
            current: currentWhitelist,
            imported: validation.whitelist,
            replaces: mode == .replace && validation.hasWhitelistSection
        )
        let purge = diff(
            current: currentPurgePaths,
            imported: validation.purgePaths,
            replaces: mode == .replace && validation.hasPurgePathsSection
        )
        whitelistToAdd = whitelist.add
        whitelistToRemove = whitelist.remove
        resultingWhitelist = whitelist.result
        purgePathsToAdd = purge.add
        purgePathsToRemove = purge.remove
        resultingPurgePaths = purge.result
    }

    public var changesWhitelist: Bool { !whitelistToAdd.isEmpty || !whitelistToRemove.isEmpty }
    public var changesPurgePaths: Bool { !purgePathsToAdd.isEmpty || !purgePathsToRemove.isEmpty }
    public var hasChanges: Bool { changesWhitelist || changesPurgePaths }
}

// MARK: - Mole Purge Yolları Dosyası (`~/.config/mole/purge_paths`)

/// `mole purge` taramasının proje klasörleri: satır başına bir yol, `~` desteklenir, `#` ile başlayan satırlar yorumdur.
/// Dosya boşsa Mole kendi varsayılan klasörlerini kullanır.
public struct MolePurgePathsFile: Sendable {
    public let url: URL

    public init(homeDirectory: URL = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)) {
        self.url = homeDirectory.appendingPathComponent(".config/mole/purge_paths")
    }

    /// Yorum ve boş satırlar dışındaki yollar, dosyada yazıldıkları biçimiyle.
    public func load() -> [String] {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        return content.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }
    }

    /// Yol satırlarını yeniden yazar; kullanıcının yorum satırları korunur. Dosya bir sembolik bağlantıysa
    /// (ör. dotfiles deposu) bağlantının gösterdiği dosya güncellenir, bağlantı bozulmaz.
    public func save(_ paths: [String]) throws {
        let target = url.resolvingSymlinksInPath()
        let existing = (try? String(contentsOf: target, encoding: .utf8)) ?? ""
        let comments = existing.split(whereSeparator: \.isNewline)
            .map(String.init)
            .filter { $0.trimmingCharacters(in: .whitespaces).hasPrefix("#") }
        if comments.isEmpty && paths.isEmpty && !FileManager.default.fileExists(atPath: target.path) { return }
        let content = (comments + paths).joined(separator: "\n") + "\n"
        try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(content.utf8).write(to: target, options: .atomic)
    }
}
