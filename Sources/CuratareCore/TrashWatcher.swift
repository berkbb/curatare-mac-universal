// SPDX-License-Identifier: GPL-3.0-or-later
import Darwin
import Foundation

/// **SmartDelete** akıllı Çöp (`~/.Trash`) izleyicisi.
///
/// Kullanıcı Finder'da bir `.app` paketini Çöp Sepeti'ne taşıdığında bunu algılar, uygulamanın `~/Library` içinde
/// kalan artık dosyalarını (`AssociatedFile`) bulur ve kullanıcının tek tıkla tarihli `Curatare-...` Çöp klasörüne
/// taşıyabilmesi için `TrashedAppEvent` yayınlar.
public struct TrashedAppEvent: Sendable, Equatable, Identifiable {
    public let id: String
    public let trashedAppURL: URL
    public let bundle: InstalledBundle
    public let orphanedFiles: [AssociatedFile]
    public let detectedAt: Date

    public var totalOrphanBytes: Int64 {
        orphanedFiles.map(\.sizeBytes).saturatingSum()
    }

    public init(
        trashedAppURL: URL,
        bundle: InstalledBundle,
        orphanedFiles: [AssociatedFile],
        detectedAt: Date = Date()
    ) {
        self.id = trashedAppURL.path
        self.trashedAppURL = trashedAppURL
        self.bundle = bundle
        self.orphanedFiles = orphanedFiles
        self.detectedAt = detectedAt
    }
}

public final class TrashWatcher: @unchecked Sendable {
    public let trashURL: URL
    public let uninstaller: AppUninstaller
    private let lock = NSLock()
    private var knownAppNames: Set<String> = []
    private var source: DispatchSourceFileSystemObject?
    private var descriptor: Int32 = -1
    private let onAppTrashed: @Sendable (TrashedAppEvent) -> Void

    public init(
        trashURL: URL = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".Trash", isDirectory: true),
        uninstaller: AppUninstaller = AppUninstaller(),
        onAppTrashed: @escaping @Sendable (TrashedAppEvent) -> Void
    ) {
        self.trashURL = trashURL
        self.uninstaller = uninstaller
        self.onAppTrashed = onAppTrashed
        self.knownAppNames = Self.currentAppNames(in: trashURL)
    }

    deinit {
        stop()
    }

    public func start() {
        lock.lock()
        defer { lock.unlock() }
        guard source == nil else { return }

        knownAppNames = Self.currentAppNames(in: trashURL)
        let fd = open(trashURL.path, O_EVTONLY)
        guard fd >= 0 else { return }
        descriptor = fd

        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename, .extend],
            queue: DispatchQueue.global(qos: .utility)
        )
        src.setEventHandler { [weak self] in
            self?.checkForNewTrashedApps()
        }
        src.setCancelHandler {
            close(fd)
        }
        source = src
        src.resume()
    }

    public func stop() {
        lock.lock()
        let src = source
        source = nil
        descriptor = -1
        lock.unlock()
        src?.cancel()
    }

    /// Çöp klasörünü denetler ve yeni eklenen `.app` paketlerinin `~/Library` artıklarını döner (testlerde doğrudan da çağrılabilir).
    @discardableResult
    public func checkForNewTrashedApps() -> [TrashedAppEvent] {
        let current = Self.currentAppNames(in: trashURL)
        var newlyAdded: Set<String> = []
        lock.lock()
        newlyAdded = current.subtracting(knownAppNames)
        knownAppNames = current
        lock.unlock()

        var events: [TrashedAppEvent] = []
        for appName in newlyAdded.sorted() {
            let appURL = trashURL.appendingPathComponent(appName, isDirectory: true)
            guard let bundle = uninstaller.inspectBundle(at: appURL, kind: .application, computeSize: false) else {
                continue
            }
            let leftovers = uninstaller.discoverAssociatedFiles(for: bundle, includeBundleItself: false)
            guard !leftovers.isEmpty else { continue }
            let event = TrashedAppEvent(trashedAppURL: appURL, bundle: bundle, orphanedFiles: leftovers)
            events.append(event)
            onAppTrashed(event)
        }
        return events
    }

    private static func currentAppNames(in trashURL: URL) -> Set<String> {
        guard let entries = try? FileManager.default.contentsOfDirectory(at: trashURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else {
            return []
        }
        var names: Set<String> = []
        for entry in entries where entry.pathExtension.lowercased() == "app" {
            names.insert(entry.lastPathComponent)
        }
        return names
    }
}
