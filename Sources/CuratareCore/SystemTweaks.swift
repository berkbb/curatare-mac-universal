import Foundation
import AppKit

public enum SystemTweakCategory: String, Sendable, CaseIterable, Identifiable {
    case finder
    case dock
    case screenshot
    case diskAndNetwork
    case system

    public var id: String { rawValue }

    public var titleKey: LKey {
        switch self {
        case .finder: .tweaksSectionFinder
        case .dock: .tweaksSectionDock
        case .screenshot: .tweaksSectionScreenshot
        case .diskAndNetwork: .tweaksSectionDiskAndNetwork
        case .system: .tweaksSectionSystem
        }
    }

    public var iconSystemName: String {
        switch self {
        case .finder: "macwindow"
        case .dock: "dock.rectangle"
        case .screenshot: "camera.viewfinder"
        case .diskAndNetwork: "externaldrive.connected.to.line.below"
        case .system: "gearshape.2"
        }
    }
}

public struct SystemTweakItem: Identifiable, Sendable, Equatable {
    public let id: String
    public let category: SystemTweakCategory
    public let titleKey: LKey
    public let descriptionKey: LKey
    public let domain: String
    public let key: String
    public let defaultValue: Bool
    public var isEnabled: Bool
    public let restartService: RestartService
    /// Doluysa açıkken anahtara bu değer yazılır, kapanınca anahtar silinir (macOS varsayılanı);
    /// açık sayılması için saklanan değerin buna karşılık gelmesi gerekir (ör. `autohide-delay` = 0).
    public let enabledValue: PreferenceValue?

    public enum RestartService: String, Sendable, Equatable {
        case none
        case finder
        case dock
        case systemUIServer

        public var noticeKey: LKey? {
            switch self {
            case .none: nil
            case .finder: .tweaksRestartNoticeFinder
            case .dock: .tweaksRestartNoticeDock
            case .systemUIServer: .tweaksRestartNoticeSystemUI
            }
        }
    }

    public init(
        id: String,
        category: SystemTweakCategory,
        titleKey: LKey,
        descriptionKey: LKey,
        domain: String,
        key: String,
        defaultValue: Bool,
        isEnabled: Bool,
        restartService: RestartService,
        enabledValue: PreferenceValue? = nil
    ) {
        self.id = id
        self.category = category
        self.titleKey = titleKey
        self.descriptionKey = descriptionKey
        self.domain = domain
        self.key = key
        self.defaultValue = defaultValue
        self.isEnabled = isEnabled
        self.restartService = restartService
        self.enabledValue = enabledValue
    }
}

/// Bir tercih anahtarının ham değeri; `defaults write` türleriyle (-bool, -int, -float, -string) birebir.
public enum PreferenceValue: Sendable, Equatable {
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)

    var numericValue: Double? {
        switch self {
        case .bool(let b): b ? 1 : 0
        case .int(let i): Double(i)
        case .double(let d): d
        case .string(let s): Double(s.trimmingCharacters(in: .whitespaces))
        }
    }

    var boolValue: Bool? {
        switch self {
        case .bool(let b): b
        case .int, .double: numericValue.map { $0 != 0 }
        case .string(let s):
            switch s.lowercased() {
            case "true", "yes", "1": true
            case "false", "no", "0": false
            default: nil
            }
        }
    }

    /// Saklanan değer bu değere karşılık geliyor mu? Terminal'den farklı türle yazılmış eşdeğerleri de
    /// (ör. `-string 0` ile `-float 0`, `-int 1` ile `-bool true`) eşit sayar.
    public func matches(_ stored: PreferenceValue) -> Bool {
        if case .string(let a) = self, case .string(let b) = stored {
            return a.caseInsensitiveCompare(b) == .orderedSame
        }
        if case .bool(let a) = self {
            return stored.boolValue == a
        }
        guard let a = numericValue, let b = stored.numericValue else { return false }
        return a == b
    }
}

/// Açık/kapalı yerine birkaç değerden birini seçtiren ayar (ör. küçültme efekti, son öğe sayısı).
/// Varsayılan seçenek anahtarı siler; anahtar yoksa varsayılan seçenek işaretlenir. Listede olmayan bir değer
/// Terminal ile yazılmışsa `selectedOptionID` `nil` olur ve hiçbir seçenek işaretlenmez.
public struct SystemChoiceTweak: Identifiable, Sendable, Equatable {
    public struct Option: Identifiable, Sendable, Equatable {
        public let id: String
        /// Yerelleştirilmiş ad; sayı seçeneklerinde `nil` olur ve `id` her dilde olduğu gibi gösterilir.
        public let titleKey: LKey?
        /// Yazılacak değer; macOS'un kendi değerini bilmediğimiz varsayılan seçenekte `nil` olur.
        public let value: PreferenceValue?

        public init(id: String, titleKey: LKey? = nil, value: PreferenceValue?) {
            self.id = id
            self.titleKey = titleKey
            self.value = value
        }

        public static let systemDefault = Option(id: "default", titleKey: .tweakOptionSystemDefault, value: nil)
        public static let on = Option(id: "on", titleKey: .tweakOptionOn, value: .bool(true))
        public static let off = Option(id: "off", titleKey: .tweakOptionOff, value: .bool(false))

        public static func count(_ n: Int) -> Option {
            Option(id: String(n), value: .int(n))
        }

        /// "ms" birim simgesi her dilde aynı yazılır.
        public static func milliseconds(_ n: Int) -> Option {
            Option(id: "\(n) ms", value: .int(n))
        }
    }

    public let id: String
    public let category: SystemTweakCategory
    public let titleKey: LKey
    public let descriptionKey: LKey
    public let domain: String
    public let key: String
    public let options: [Option]
    public let defaultOptionID: String
    public var selectedOptionID: String?
    public let restartService: SystemTweakItem.RestartService

    public init(
        id: String,
        category: SystemTweakCategory,
        titleKey: LKey,
        descriptionKey: LKey,
        domain: String,
        key: String,
        options: [Option],
        defaultOptionID: String = Option.systemDefault.id,
        restartService: SystemTweakItem.RestartService
    ) {
        self.id = id
        self.category = category
        self.titleKey = titleKey
        self.descriptionKey = descriptionKey
        self.domain = domain
        self.key = key
        self.options = options
        self.defaultOptionID = defaultOptionID
        self.selectedOptionID = defaultOptionID
        self.restartService = restartService
    }
}

/// Yeni ekran resimlerinin dosya biçimi (`com.apple.screencapture` → `type`). macOS varsayılanı PNG'dir.
public enum ScreenshotFormat: String, Sendable, CaseIterable, Identifiable {
    case png
    case jpg
    case heic
    case pdf

    public var id: String { rawValue }

    /// Biçim adı her dilde aynıdır (PNG, JPG, HEIC, PDF).
    public var displayName: String { rawValue.uppercased() }

    public static let domain = "com.apple.screencapture"
    public static let key = "type"
}

/// Yeni ekran resimlerinin dosya adı öneki (`com.apple.screencapture` → `name`). Anahtar yoksa macOS
/// sistem dilindeki kendi adını kullanır.
public enum ScreenshotNamePrefix {
    public static let domain = "com.apple.screencapture"
    public static let key = "name"
    public static let maxLength = 60

    /// Dosya adında klasör ayırıcısı olan `/` ve `:` çıkarılır, baş ve sondaki boşluklar kırpılır.
    public static func sanitized(_ raw: String) -> String {
        let cleaned = raw.filter { $0 != "/" && $0 != ":" }.trimmingCharacters(in: .whitespacesAndNewlines)
        return String(cleaned.prefix(maxLength)).trimmingCharacters(in: .whitespaces)
    }
}

/// Safari Geliştir menüsü yalnızca okunur: Safari'nin kendi ayarı korumasız `SandboxBroker` alanına ve korumalı
/// kapsayıcıya birlikte yazar. Dışarıdan yalnızca bu anahtar değiştirilince Safari kapatmayı uygular ama açmayı
/// uygulamaz (2026-11-03 canlı denemesi); bu yüzden Curatare durumu gösterir, değiştirmeyi Safari'ye bırakır.
public enum SafariDevelopMenu {
    public static let domain = "com.apple.Safari.SandboxBroker"
    public static let key = "ShowDevelopMenu"
    public static let bundleID = "com.apple.Safari"
}

/// Yeni ekran resimlerinin ve ekran kayıtlarının klasörü (`com.apple.screencapture` → `location`).
/// Anahtar yoksa macOS Masaüstü'ne kaydeder.
public enum ScreenshotLocation {
    public static let domain = "com.apple.screencapture"
    public static let key = "location"
}

public protocol PreferenceStoreProtocol: Sendable {
    func readBool(domain: String, key: String, defaultValue: Bool) -> Bool
    func writeBool(domain: String, key: String, value: Bool)
    func readString(domain: String, key: String, defaultValue: String) -> String
    func writeString(domain: String, key: String, value: String)
    func readValue(domain: String, key: String) -> PreferenceValue?
    func writeValue(domain: String, key: String, value: PreferenceValue)
    func removeValue(domain: String, key: String)
    /// Dock'un `persistent-apps` gibi sözlük dizisi tutan anahtarları; dizi okunamazsa `nil`.
    func readDictionaryArray(domain: String, key: String) -> [[String: Any]]?
    func writeDictionaryArray(domain: String, key: String, value: [[String: Any]])
    func restartService(_ service: SystemTweakItem.RestartService)
}

public struct SystemPreferenceStore: PreferenceStoreProtocol {
    public init() {}

    /// `defaults` komutundaki `NSGlobalDomain` adını CFPreferences tanımaz; bu adla yazılan değer genel alana değil
    /// ayrı bir `~/Library/Preferences/NSGlobalDomain.plist` dosyasına gider. Genel alan `kCFPreferencesAnyApplication`'dır.
    public static func preferencesDomain(for domain: String) -> CFString {
        domain == "NSGlobalDomain" ? kCFPreferencesAnyApplication : domain as CFString
    }

    public func readBool(domain: String, key: String, defaultValue: Bool) -> Bool {
        if let val = CFPreferencesCopyAppValue(key as CFString, Self.preferencesDomain(for: domain)) {
            if let b = val as? Bool { return b }
            if let num = val as? NSNumber { return num.boolValue }
            if let s = val as? String {
                let lower = s.lowercased()
                if lower == "true" || lower == "yes" || lower == "1" { return true }
                if lower == "false" || lower == "no" || lower == "0" { return false }
            }
        }
        return defaultValue
    }

    public func writeBool(domain: String, key: String, value: Bool) {
        let cfDomain = Self.preferencesDomain(for: domain)
        CFPreferencesSetAppValue(key as CFString, value ? kCFBooleanTrue : kCFBooleanFalse, cfDomain)
        CFPreferencesAppSynchronize(cfDomain)
    }

    public func readString(domain: String, key: String, defaultValue: String) -> String {
        if let val = CFPreferencesCopyAppValue(key as CFString, Self.preferencesDomain(for: domain)) as? String {
            return val
        }
        return defaultValue
    }

    public func writeString(domain: String, key: String, value: String) {
        let cfDomain = Self.preferencesDomain(for: domain)
        CFPreferencesSetAppValue(key as CFString, value as CFString, cfDomain)
        CFPreferencesAppSynchronize(cfDomain)
    }

    public func readValue(domain: String, key: String) -> PreferenceValue? {
        guard let val = CFPreferencesCopyAppValue(key as CFString, Self.preferencesDomain(for: domain)) else { return nil }
        // NSNumber Swift'te Bool'a da köprülenir; gerçek CFBoolean önce ayrılmazsa `-int 1` bool sanılır.
        if CFGetTypeID(val) == CFBooleanGetTypeID(), let num = val as? NSNumber { return .bool(num.boolValue) }
        if let num = val as? NSNumber {
            return CFNumberIsFloatType(num as CFNumber) ? .double(num.doubleValue) : .int(num.intValue)
        }
        if let s = val as? String { return .string(s) }
        return nil
    }

    public func writeValue(domain: String, key: String, value: PreferenceValue) {
        let cfDomain = Self.preferencesDomain(for: domain)
        let cfValue: CFPropertyList = switch value {
        case .bool(let b): (b ? kCFBooleanTrue : kCFBooleanFalse) as CFPropertyList
        case .int(let i): NSNumber(value: i)
        case .double(let d): NSNumber(value: d)
        case .string(let s): s as CFString
        }
        CFPreferencesSetAppValue(key as CFString, cfValue, cfDomain)
        CFPreferencesAppSynchronize(cfDomain)
    }

    public func removeValue(domain: String, key: String) {
        let cfDomain = Self.preferencesDomain(for: domain)
        CFPreferencesSetAppValue(key as CFString, nil, cfDomain)
        CFPreferencesAppSynchronize(cfDomain)
    }

    public func readDictionaryArray(domain: String, key: String) -> [[String: Any]]? {
        CFPreferencesCopyAppValue(key as CFString, Self.preferencesDomain(for: domain)) as? [[String: Any]]
    }

    public func writeDictionaryArray(domain: String, key: String, value: [[String: Any]]) {
        let cfDomain = Self.preferencesDomain(for: domain)
        CFPreferencesSetAppValue(key as CFString, value as NSArray, cfDomain)
        CFPreferencesAppSynchronize(cfDomain)
    }

    public func restartService(_ service: SystemTweakItem.RestartService) {
        guard service != .none else { return }
        let name: String
        switch service {
        case .none: return
        case .finder: name = "Finder"
        case .dock: name = "Dock"
        case .systemUIServer: name = "SystemUIServer"
        }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        p.arguments = [name]
        try? p.run()
    }
}

public final class MockPreferenceStore: PreferenceStoreProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private var boolValues: [String: Bool] = [:]
    private var stringValues: [String: String] = [:]
    private var numberValues: [String: PreferenceValue] = [:]
    private var arrayValues: [String: [[String: Any]]] = [:]
    public private(set) var restartedServices: [SystemTweakItem.RestartService] = []

    public init(initialBools: [String: Bool] = [:], initialStrings: [String: String] = [:]) {
        self.boolValues = initialBools
        self.stringValues = initialStrings
    }

    private func compositeKey(_ domain: String, _ key: String) -> String {
        "\(domain):\(key)"
    }

    public func readBool(domain: String, key: String, defaultValue: Bool) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return boolValues[compositeKey(domain, key)] ?? defaultValue
    }

    public func writeBool(domain: String, key: String, value: Bool) {
        lock.lock()
        defer { lock.unlock() }
        boolValues[compositeKey(domain, key)] = value
    }

    public func readString(domain: String, key: String, defaultValue: String) -> String {
        lock.lock()
        defer { lock.unlock() }
        return stringValues[compositeKey(domain, key)] ?? defaultValue
    }

    public func writeString(domain: String, key: String, value: String) {
        lock.lock()
        defer { lock.unlock() }
        stringValues[compositeKey(domain, key)] = value
    }

    public func readValue(domain: String, key: String) -> PreferenceValue? {
        lock.lock()
        defer { lock.unlock() }
        let k = compositeKey(domain, key)
        if let number = numberValues[k] { return number }
        if let b = boolValues[k] { return .bool(b) }
        if let s = stringValues[k] { return .string(s) }
        return nil
    }

    public func writeValue(domain: String, key: String, value: PreferenceValue) {
        lock.lock()
        defer { lock.unlock() }
        let k = compositeKey(domain, key)
        boolValues.removeValue(forKey: k)
        stringValues.removeValue(forKey: k)
        numberValues.removeValue(forKey: k)
        switch value {
        case .bool(let b): boolValues[k] = b
        case .string(let s): stringValues[k] = s
        case .int, .double: numberValues[k] = value
        }
    }

    public func removeValue(domain: String, key: String) {
        lock.lock()
        defer { lock.unlock() }
        boolValues.removeValue(forKey: compositeKey(domain, key))
        stringValues.removeValue(forKey: compositeKey(domain, key))
        numberValues.removeValue(forKey: compositeKey(domain, key))
        arrayValues.removeValue(forKey: compositeKey(domain, key))
    }

    public func readDictionaryArray(domain: String, key: String) -> [[String: Any]]? {
        lock.lock()
        defer { lock.unlock() }
        return arrayValues[compositeKey(domain, key)]
    }

    public func writeDictionaryArray(domain: String, key: String, value: [[String: Any]]) {
        lock.lock()
        defer { lock.unlock() }
        arrayValues[compositeKey(domain, key)] = value
    }

    public func restartService(_ service: SystemTweakItem.RestartService) {
        lock.lock()
        defer { lock.unlock() }
        restartedServices.append(service)
    }
}

public struct SystemTweakManager: Sendable {
    public let store: any PreferenceStoreProtocol

    public init(store: any PreferenceStoreProtocol = SystemPreferenceStore()) {
        self.store = store
    }

    /// Tüm tanımlı macOS sistem ayarlarını okur ve durumlarıyla listeler.
    public func loadAllTweaks() -> [SystemTweakItem] {
        definitions.map { def in
            let currentVal = readValue(for: def)
            var item = def
            item.isEnabled = currentVal
            return item
        }
    }

    /// Belirtilen ayarı uygular ve gerekirse ilgili hizmeti (Finder/Dock vb.) yeniden başlatır.
    public func applyTweak(id: String, enabled: Bool, restartService: Bool = true) -> SystemTweakItem? {
        guard let def = definitions.first(where: { $0.id == id }) else { return nil }
        writeValue(for: def, value: enabled)
        if restartService {
            store.restartService(def.restartService)
        }
        var updated = def
        updated.isEnabled = enabled
        return updated
    }

    /// Çok seçenekli ayarları geçerli değerleriyle listeler.
    public func loadChoiceTweaks() -> [SystemChoiceTweak] {
        choiceDefinitions.map { def in
            var item = def
            item.selectedOptionID = selectedOptionID(for: def)
            return item
        }
    }

    /// Seçeneği yazar; varsayılan seçenek anahtarı silerek macOS'un kendi değerine döndürür.
    public func applyChoiceTweak(id: String, optionID: String, restartService: Bool = true) -> SystemChoiceTweak? {
        guard let def = choiceDefinitions.first(where: { $0.id == id }),
              let option = def.options.first(where: { $0.id == optionID }) else { return nil }
        if let value = option.value, option.id != def.defaultOptionID {
            store.writeValue(domain: def.domain, key: def.key, value: value)
        } else {
            store.removeValue(domain: def.domain, key: def.key)
        }
        if restartService {
            store.restartService(def.restartService)
        }
        var updated = def
        updated.selectedOptionID = option.id
        return updated
    }

    /// Tüm ayarları sistem varsayılanlarına sıfırlar.
    public func restoreAllToDefaults(restartServices: Bool = true) -> [SystemTweakItem] {
        var servicesToRestart: Set<SystemTweakItem.RestartService> = []
        let result = definitions.map { def in
            writeValue(for: def, value: def.defaultValue)
            if def.restartService != .none {
                servicesToRestart.insert(def.restartService)
            }
            var item = def
            item.isEnabled = def.defaultValue
            return item
        }
        for def in choiceDefinitions {
            store.removeValue(domain: def.domain, key: def.key)
            if def.restartService != .none {
                servicesToRestart.insert(def.restartService)
            }
        }
        setScreenshotFormat(.png, restartService: false)
        setScreenshotNamePrefix("", restartService: false)
        setScreenshotLocation(nil, restartService: false)
        servicesToRestart.insert(.systemUIServer)
        if restartServices {
            for service in servicesToRestart {
                store.restartService(service)
            }
        }
        return result
    }

    static let dockDomain = "com.apple.dock"
    /// Boşluklar uygulama bölümüne eklenir; kullanıcı sağ bölüme de taşımış olabilir.
    static let dockTileKeys = ["persistent-apps", "persistent-others"]

    /// `spacer-tile`, `small-spacer-tile` ve `flex-spacer-tile`.
    static func isDockSpacer(_ tile: [String: Any]) -> Bool {
        (tile["tile-type"] as? String)?.hasSuffix("spacer-tile") == true
    }

    /// Dock'a ayırıcı boşluk (spacer) ekler. Tercih doğrudan yazılır; komut, betik ya da izin gerekmez.
    /// Dock dizisi okunamazsa hiçbir şey yazılmaz: boş diziyle üzerine yazmak Dock'taki uygulamaları silerdi.
    @discardableResult
    public func addDockSpacer(small: Bool = false) -> Bool {
        guard var tiles = store.readDictionaryArray(domain: Self.dockDomain, key: "persistent-apps") else { return false }
        tiles.append(["tile-type": small ? "small-spacer-tile" : "spacer-tile", "tile-data": [String: Any]()])
        store.writeDictionaryArray(domain: Self.dockDomain, key: "persistent-apps", value: tiles)
        store.restartService(.dock)
        return true
    }

    /// Dock'taki tüm ayırıcı boşlukları kaldırır; diğer kutucuklara dokunmaz. Kaldırılacak boşluk yoksa `false`
    /// döner ve Dock yeniden başlatılmaz.
    @discardableResult
    public func removeDockSpacers() -> Bool {
        var removedAny = false
        for key in Self.dockTileKeys {
            guard let tiles = store.readDictionaryArray(domain: Self.dockDomain, key: key) else { continue }
            let kept = tiles.filter { !Self.isDockSpacer($0) }
            guard kept.count != tiles.count else { continue }
            store.writeDictionaryArray(domain: Self.dockDomain, key: key, value: kept)
            removedAny = true
        }
        if removedAny { store.restartService(.dock) }
        return removedAny
    }

    /// Geçerli ekran resmi biçimi; anahtar yoksa macOS varsayılanı PNG. Terminal ile listede olmayan bir biçim
    /// (ör. `tiff`) ayarlanmışsa `nil` döner ve seçici hiçbir biçimi işaretlemez.
    public func screenshotFormat() -> ScreenshotFormat? {
        let raw = store.readString(domain: ScreenshotFormat.domain, key: ScreenshotFormat.key, defaultValue: "png").lowercased()
        return ScreenshotFormat(rawValue: raw == "jpeg" ? "jpg" : raw)
    }

    /// Ekran resmi biçimini yazar; PNG seçilince anahtar silinir (sistem varsayılanına döner).
    public func setScreenshotFormat(_ format: ScreenshotFormat, restartService: Bool = true) {
        if format == .png {
            store.removeValue(domain: ScreenshotFormat.domain, key: ScreenshotFormat.key)
        } else {
            store.writeString(domain: ScreenshotFormat.domain, key: ScreenshotFormat.key, value: format.rawValue)
        }
        if restartService {
            store.restartService(.systemUIServer)
        }
    }

    /// Safari'nin kendi ayarının son yazdığı Geliştir menüsü durumu; Curatare bu anahtara yazmaz.
    public func safariDevelopMenuShown() -> Bool {
        store.readBool(domain: SafariDevelopMenu.domain, key: SafariDevelopMenu.key, defaultValue: false)
    }

    /// Geçerli kayıt klasörü; anahtar yoksa `nil` (macOS varsayılanı Masaüstü).
    public func screenshotLocation() -> String? {
        let path = store.readString(domain: ScreenshotLocation.domain, key: ScreenshotLocation.key, defaultValue: "")
        return path.isEmpty ? nil : path
    }

    /// Kayıt klasörünü yazar; `nil` anahtarı siler ve kayıtlar yeniden Masaüstü'ne gider.
    public func setScreenshotLocation(_ path: String?, restartService: Bool = true) {
        if let path, !path.isEmpty {
            store.writeString(domain: ScreenshotLocation.domain, key: ScreenshotLocation.key, value: path)
        } else {
            store.removeValue(domain: ScreenshotLocation.domain, key: ScreenshotLocation.key)
        }
        if restartService {
            store.restartService(.systemUIServer)
        }
    }

    /// Geçerli dosya adı öneki; anahtar yoksa boş döner (macOS varsayılanı).
    public func screenshotNamePrefix() -> String {
        store.readString(domain: ScreenshotNamePrefix.domain, key: ScreenshotNamePrefix.key, defaultValue: "")
    }

    /// Öneki temizleyip yazar ve yazılan değeri döndürür; temizlenince boş kalırsa anahtar silinir.
    @discardableResult
    public func setScreenshotNamePrefix(_ raw: String, restartService: Bool = true) -> String {
        let prefix = ScreenshotNamePrefix.sanitized(raw)
        if prefix.isEmpty {
            store.removeValue(domain: ScreenshotNamePrefix.domain, key: ScreenshotNamePrefix.key)
        } else {
            store.writeString(domain: ScreenshotNamePrefix.domain, key: ScreenshotNamePrefix.key, value: prefix)
        }
        if restartService {
            store.restartService(.systemUIServer)
        }
        return prefix
    }

    private func selectedOptionID(for def: SystemChoiceTweak) -> String? {
        guard let stored = store.readValue(domain: def.domain, key: def.key) else { return def.defaultOptionID }
        return def.options.first(where: { $0.value?.matches(stored) == true })?.id
    }

    private func readValue(for item: SystemTweakItem) -> Bool {
        if let enabledValue = item.enabledValue {
            return store.readValue(domain: item.domain, key: item.key).map(enabledValue.matches) ?? false
        }
        if item.id == "system.suppressCrashDialog" {
            let str = store.readString(domain: item.domain, key: item.key, defaultValue: "prompt")
            return str.lowercased() == "none"
        }
        if item.id == "system.pressAndHoldRepeat" || item.id == "finder.hideDesktopIcons" || item.id == "system.disableWindowAnimations" {
            let raw = store.readBool(domain: item.domain, key: item.key, defaultValue: true)
            return !raw
        }
        return store.readBool(domain: item.domain, key: item.key, defaultValue: item.defaultValue)
    }

    private func writeValue(for item: SystemTweakItem, value: Bool) {
        if let enabledValue = item.enabledValue {
            if value {
                store.writeValue(domain: item.domain, key: item.key, value: enabledValue)
            } else {
                store.removeValue(domain: item.domain, key: item.key)
            }
            return
        }
        if item.id == "system.suppressCrashDialog" {
            if value {
                store.writeString(domain: item.domain, key: item.key, value: "none")
            } else {
                store.removeValue(domain: item.domain, key: item.key)
            }
            return
        }
        if item.id == "system.pressAndHoldRepeat" || item.id == "finder.hideDesktopIcons" || item.id == "system.disableWindowAnimations" {
            store.writeBool(domain: item.domain, key: item.key, value: !value)
            return
        }
        store.writeBool(domain: item.domain, key: item.key, value: value)
    }

    public let definitions: [SystemTweakItem] = [
        // MARK: - Finder
        SystemTweakItem(
            id: "finder.showHiddenFiles",
            category: .finder,
            titleKey: .tweakShowHiddenFilesTitle,
            descriptionKey: .tweakShowHiddenFilesDesc,
            domain: "com.apple.finder",
            key: "AppleShowAllFiles",
            defaultValue: false,
            isEnabled: false,
            restartService: .finder
        ),
        SystemTweakItem(
            id: "finder.showFullPathInTitle",
            category: .finder,
            titleKey: .tweakShowFullPathInTitleTitle,
            descriptionKey: .tweakShowFullPathInTitleDesc,
            domain: "com.apple.finder",
            key: "_FXShowPosixPathInTitle",
            defaultValue: false,
            isEnabled: false,
            restartService: .finder
        ),
        SystemTweakItem(
            id: "finder.showAllExtensions",
            category: .finder,
            titleKey: .tweakShowAllExtensionsTitle,
            descriptionKey: .tweakShowAllExtensionsDesc,
            domain: "NSGlobalDomain",
            key: "AppleShowAllExtensions",
            defaultValue: false,
            isEnabled: false,
            restartService: .finder
        ),
        SystemTweakItem(
            id: "finder.quitMenuItem",
            category: .finder,
            titleKey: .tweakQuitFinderMenuTitle,
            descriptionKey: .tweakQuitFinderMenuDesc,
            domain: "com.apple.finder",
            key: "QuitMenuItem",
            defaultValue: false,
            isEnabled: false,
            restartService: .finder
        ),
        SystemTweakItem(
            id: "finder.hideDesktopIcons",
            category: .finder,
            titleKey: .tweakHideDesktopIconsTitle,
            descriptionKey: .tweakHideDesktopIconsDesc,
            domain: "com.apple.finder",
            key: "CreateDesktop",
            defaultValue: false,
            isEnabled: false,
            restartService: .finder
        ),
        SystemTweakItem(
            id: "finder.pathBarFromHome",
            category: .finder,
            titleKey: .tweakPathBarFromHomeTitle,
            descriptionKey: .tweakPathBarFromHomeDesc,
            domain: "com.apple.finder",
            key: "PathBarRootAtHome",
            defaultValue: false,
            isEnabled: false,
            restartService: .finder
        ),
        SystemTweakItem(
            id: "finder.quickLookNoAnimation",
            category: .finder,
            titleKey: .tweakQuickLookNoAnimationTitle,
            descriptionKey: .tweakQuickLookNoAnimationDesc,
            domain: "NSGlobalDomain",
            key: "QLPanelAnimationDuration",
            defaultValue: false,
            isEnabled: false,
            restartService: .finder,
            enabledValue: .double(0)
        ),
        SystemTweakItem(
            id: "finder.noWindowZoomAnimation",
            category: .finder,
            titleKey: .tweakFinderNoWindowZoomTitle,
            descriptionKey: .tweakFinderNoWindowZoomDesc,
            domain: "com.apple.finder",
            key: "AnimateWindowZoom",
            defaultValue: false,
            isEnabled: false,
            restartService: .finder,
            enabledValue: .bool(false)
        ),
        SystemTweakItem(
            id: "finder.noInfoPaneAnimation",
            category: .finder,
            titleKey: .tweakFinderNoInfoPaneAnimationTitle,
            descriptionKey: .tweakFinderNoInfoPaneAnimationDesc,
            domain: "com.apple.finder",
            key: "AnimateInfoPanes",
            defaultValue: false,
            isEnabled: false,
            restartService: .finder,
            enabledValue: .bool(false)
        ),

        // MARK: - Dock
        SystemTweakItem(
            id: "dock.staticOnly",
            category: .dock,
            titleKey: .tweakDockStaticOnlyTitle,
            descriptionKey: .tweakDockStaticOnlyDesc,
            domain: "com.apple.dock",
            key: "static-only",
            defaultValue: false,
            isEnabled: false,
            restartService: .dock
        ),
        SystemTweakItem(
            id: "dock.dimHidden",
            category: .dock,
            titleKey: .tweakDockDimHiddenTitle,
            descriptionKey: .tweakDockDimHiddenDesc,
            domain: "com.apple.dock",
            key: "showhidden",
            defaultValue: false,
            isEnabled: false,
            restartService: .dock
        ),
        SystemTweakItem(
            id: "dock.instantAutohide",
            category: .dock,
            titleKey: .tweakDockInstantAutohideTitle,
            descriptionKey: .tweakDockInstantAutohideDesc,
            domain: "com.apple.dock",
            key: "autohide-delay",
            defaultValue: false,
            isEnabled: false,
            restartService: .dock,
            enabledValue: .double(0)
        ),
        SystemTweakItem(
            id: "dock.lockContents",
            category: .dock,
            titleKey: .tweakDockLockContentsTitle,
            descriptionKey: .tweakDockLockContentsDesc,
            domain: "com.apple.dock",
            key: "contents-immutable",
            defaultValue: false,
            isEnabled: false,
            restartService: .dock
        ),
        SystemTweakItem(
            id: "dock.lockSize",
            category: .dock,
            titleKey: .tweakDockLockSizeTitle,
            descriptionKey: .tweakDockLockSizeDesc,
            domain: "com.apple.dock",
            key: "size-immutable",
            defaultValue: false,
            isEnabled: false,
            restartService: .dock
        ),
        SystemTweakItem(
            id: "dock.stackHoverHighlight",
            category: .dock,
            titleKey: .tweakDockStackHighlightTitle,
            descriptionKey: .tweakDockStackHighlightDesc,
            domain: "com.apple.dock",
            key: "mouse-over-hilite-stack",
            defaultValue: false,
            isEnabled: false,
            restartService: .dock
        ),
        SystemTweakItem(
            id: "dock.instantAnimation",
            category: .dock,
            titleKey: .tweakDockNoAnimationTitle,
            descriptionKey: .tweakDockNoAnimationDesc,
            domain: "com.apple.dock",
            key: "autohide-time-modifier",
            defaultValue: false,
            isEnabled: false,
            restartService: .dock,
            enabledValue: .double(0)
        ),
        SystemTweakItem(
            id: "dock.showRecents",
            category: .dock,
            titleKey: .tweakDockShowRecentsTitle,
            descriptionKey: .tweakDockShowRecentsDesc,
            domain: "com.apple.dock",
            key: "show-recents",
            defaultValue: true,
            isEnabled: true,
            restartService: .dock
        ),

        // MARK: - Disk ve Ağ
        SystemTweakItem(
            id: "disk.dontWriteNetworkStores",
            category: .diskAndNetwork,
            titleKey: .tweakNetworkStoresTitle,
            descriptionKey: .tweakNetworkStoresDesc,
            domain: "com.apple.desktopservices",
            key: "DSDontWriteNetworkStores",
            defaultValue: false,
            isEnabled: false,
            restartService: .none
        ),
        SystemTweakItem(
            id: "disk.dontWriteUSBStores",
            category: .diskAndNetwork,
            titleKey: .tweakUSBStoresTitle,
            descriptionKey: .tweakUSBStoresDesc,
            domain: "com.apple.desktopservices",
            key: "DSDontWriteUSBStores",
            defaultValue: false,
            isEnabled: false,
            restartService: .none
        ),

        // MARK: - Ekran Resmi
        SystemTweakItem(
            id: "screenshot.disableShadow",
            category: .screenshot,
            titleKey: .tweakScreenshotShadowTitle,
            descriptionKey: .tweakScreenshotShadowDesc,
            domain: "com.apple.screencapture",
            key: "disable-shadow",
            defaultValue: false,
            isEnabled: false,
            restartService: .systemUIServer
        ),
        SystemTweakItem(
            id: "screenshot.includeDate",
            category: .screenshot,
            titleKey: .tweakScreenshotIncludeDateTitle,
            descriptionKey: .tweakScreenshotIncludeDateDesc,
            domain: "com.apple.screencapture",
            key: "include-date",
            defaultValue: true,
            isEnabled: true,
            restartService: .systemUIServer
        ),
        SystemTweakItem(
            id: "screenshot.showThumbnail",
            category: .screenshot,
            titleKey: .tweakScreenshotThumbnailTitle,
            descriptionKey: .tweakScreenshotThumbnailDesc,
            domain: "com.apple.screencapture",
            key: "show-thumbnail",
            defaultValue: true,
            isEnabled: true,
            restartService: .systemUIServer
        ),
        SystemTweakItem(
            id: "screenshot.showCursor",
            category: .screenshot,
            titleKey: .tweakScreenshotCursorTitle,
            descriptionKey: .tweakScreenshotCursorDesc,
            domain: "com.apple.screencapture",
            key: "showsCursor",
            defaultValue: false,
            isEnabled: false,
            restartService: .systemUIServer
        ),

        // MARK: - Sistem & Uygulamalar
        SystemTweakItem(
            id: "system.suppressCrashDialog",
            category: .system,
            titleKey: .tweakCrashReporterDialogTitle,
            descriptionKey: .tweakCrashReporterDialogDesc,
            domain: "com.apple.CrashReporter",
            key: "DialogType",
            defaultValue: false,
            isEnabled: false,
            restartService: .none
        ),
        // Apple Music yarım yıldız ve TextEdit boş belge ayarları kaldırıldı: bu sandbox'lı uygulamaların tercihleri
        // korumalı kapsayıcıdadır; okumak açılışta Apple Music arşiv izni penceresi açıp uygulamayı donduruyordu ve
        // dışarıdan yazma güvenilir değil (Safari Geliştir menüsüyle aynı sınıf, 2026-11-03).
        SystemTweakItem(
            id: "system.windowDragOnGesture",
            category: .system,
            titleKey: .tweakWindowDragOnGestureTitle,
            descriptionKey: .tweakWindowDragOnGestureDesc,
            domain: "NSGlobalDomain",
            key: "NSWindowShouldDragOnGesture",
            defaultValue: false,
            isEnabled: false,
            restartService: .none
        ),
        SystemTweakItem(
            id: "system.pressAndHoldRepeat",
            category: .system,
            titleKey: .tweakPressAndHoldRepeatTitle,
            descriptionKey: .tweakPressAndHoldRepeatDesc,
            domain: "NSGlobalDomain",
            key: "ApplePressAndHoldEnabled",
            defaultValue: false,
            isEnabled: false,
            restartService: .none
        ),
        SystemTweakItem(
            id: "system.disableWindowAnimations",
            category: .system,
            titleKey: .tweakDisableWindowAnimationsTitle,
            descriptionKey: .tweakDisableWindowAnimationsDesc,
            domain: "NSGlobalDomain",
            key: "NSAutomaticWindowAnimationsEnabled",
            defaultValue: false,
            isEnabled: false,
            restartService: .none
        ),
        SystemTweakItem(
            id: "system.expandedSaveDialog",
            category: .system,
            titleKey: .tweakExpandedSaveDialogTitle,
            descriptionKey: .tweakExpandedSaveDialogDesc,
            domain: "NSGlobalDomain",
            key: "NSNavPanelExpandedStateForSaveMode",
            defaultValue: false,
            isEnabled: false,
            restartService: .none
        ),
        SystemTweakItem(
            id: "system.disableAppNap",
            category: .system,
            titleKey: .tweakDisableAppNapTitle,
            descriptionKey: .tweakDisableAppNapDesc,
            domain: "NSGlobalDomain",
            key: "NSAppSleepDisabled",
            defaultValue: false,
            isEnabled: false,
            restartService: .none
        ),
        SystemTweakItem(
            id: "system.toolbarTitleNoDelay",
            category: .system,
            titleKey: .tweakToolbarTitleNoDelayTitle,
            descriptionKey: .tweakToolbarTitleNoDelayDesc,
            domain: "NSGlobalDomain",
            key: "NSToolbarTitleViewRolloverDelay",
            defaultValue: false,
            isEnabled: false,
            restartService: .none,
            enabledValue: .double(0)
        )
    ]

    /// macOS varsayılanı kesin bilinmeyen ya da sayı/metin isteyen ayarlar; varsayılan seçenek anahtarı siler.
    public let choiceDefinitions: [SystemChoiceTweak] = [
        SystemChoiceTweak(
            id: "finder.columnAutoSizing",
            category: .finder,
            titleKey: .tweakColumnAutoSizingTitle,
            descriptionKey: .tweakColumnAutoSizingDesc,
            domain: "com.apple.finder",
            key: "_FXEnableColumnAutoSizing",
            options: [.systemDefault, .on, .off],
            restartService: .finder
        ),
        SystemChoiceTweak(
            id: "finder.quickLookHideOnDeactivate",
            category: .finder,
            titleKey: .tweakQuickLookHideOnDeactivateTitle,
            descriptionKey: .tweakQuickLookHideOnDeactivateDesc,
            domain: "com.apple.finder",
            key: "QLHidePanelOnDeactivate",
            options: [.systemDefault, .on, .off],
            restartService: .finder
        ),
        SystemChoiceTweak(
            id: "dock.minimizeEffect",
            category: .dock,
            titleKey: .tweakMinimizeEffectTitle,
            descriptionKey: .tweakMinimizeEffectDesc,
            domain: "com.apple.dock",
            key: "mineffect",
            options: [
                .init(id: "genie", titleKey: .tweakMinimizeEffectGenie, value: .string("genie")),
                .init(id: "scale", titleKey: .tweakMinimizeEffectScale, value: .string("scale")),
                .init(id: "suck", titleKey: .tweakMinimizeEffectSuck, value: .string("suck"))
            ],
            defaultOptionID: "genie",
            restartService: .dock
        ),
        SystemChoiceTweak(
            id: "dock.recentAppsCount",
            category: .dock,
            titleKey: .tweakDockRecentCountTitle,
            descriptionKey: .tweakDockRecentCountDesc,
            domain: "com.apple.dock",
            key: "show-recent-count",
            options: [.systemDefault, .count(1), .count(5), .count(10)],
            restartService: .dock
        ),
        SystemChoiceTweak(
            id: "system.recentDocumentsLimit",
            category: .system,
            titleKey: .tweakRecentDocumentsLimitTitle,
            descriptionKey: .tweakRecentDocumentsLimitDesc,
            domain: "NSGlobalDomain",
            key: "NSRecentDocumentsLimit",
            options: [.systemDefault, .count(0), .count(5), .count(20), .count(50)],
            restartService: .none
        ),
        SystemChoiceTweak(
            id: "system.recentPlacesLimit",
            category: .system,
            titleKey: .tweakRecentPlacesLimitTitle,
            descriptionKey: .tweakRecentPlacesLimitDesc,
            domain: "NSGlobalDomain",
            key: "NSNavRecentPlacesLimit",
            options: [.systemDefault, .count(0), .count(10), .count(20)],
            restartService: .none
        ),
        SystemChoiceTweak(
            id: "system.toolTipDelay",
            category: .system,
            titleKey: .tweakToolTipDelayTitle,
            descriptionKey: .tweakToolTipDelayDesc,
            domain: "NSGlobalDomain",
            key: "NSInitialToolTipDelay",
            options: [.systemDefault, .milliseconds(100), .milliseconds(500), .milliseconds(2000)],
            restartService: .none
        ),
        SystemChoiceTweak(
            id: "system.powerButtonSleep",
            category: .system,
            titleKey: .tweakPowerButtonSleepTitle,
            descriptionKey: .tweakPowerButtonSleepDesc,
            domain: "com.apple.loginwindow",
            key: "PowerButtonSleepsSystem",
            options: [.systemDefault, .on, .off],
            restartService: .none
        )
    ]
}
