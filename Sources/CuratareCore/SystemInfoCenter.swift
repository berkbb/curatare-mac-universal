// SPDX-License-Identifier: GPL-3.0-or-later
import AppKit
import Foundation
import IOKit

// MARK: - 1. Veri Yapıları (Sistem Merkezi Modelleri)

public struct SystemCenterHardware: Sendable, Codable, Equatable {
    public var modelName: String
    public var modelIdentifier: String
    public var chip: String
    public var architecture: String
    public var totalCores: String
    public var gpu: String
    public var gpuCores: Int
    public var resolution: String
    public var systemFirmwareVersion: String
    public var hardwareUUID: String
    public var physicalDisk: String
    public var serialNumber: String

    public init(
        modelName: String = "",
        modelIdentifier: String = "",
        chip: String = "",
        architecture: String = "",
        totalCores: String = "",
        gpu: String = "",
        gpuCores: Int = 0,
        resolution: String = "",
        systemFirmwareVersion: String = "",
        hardwareUUID: String = "",
        physicalDisk: String = "",
        serialNumber: String = ""
    ) {
        self.modelName = modelName
        self.modelIdentifier = modelIdentifier
        self.chip = chip
        self.architecture = architecture
        self.totalCores = totalCores
        self.gpu = gpu
        self.gpuCores = gpuCores
        self.resolution = resolution
        self.systemFirmwareVersion = systemFirmwareVersion
        self.hardwareUUID = hardwareUUID
        self.physicalDisk = physicalDisk
        self.serialNumber = serialNumber
    }
}

public struct SystemCenterMemory: Sendable, Codable, Equatable {
    public var physicalMemory: String
    public var memoryType: String
    public var usedMemoryBytes: Int64
    public var wiredMemoryBytes: Int64
    public var cachedFilesBytes: Int64
    public var pressurePercent: Int
    public var swapUsedBytes: Int64
    public var swapFileCount: Int
    public var pageInsBytes: Int64
    public var pageOutsBytes: Int64
    public var activeBytes: Int64
    public var inactiveBytes: Int64

    public init(
        physicalMemory: String = "",
        memoryType: String = "",
        usedMemoryBytes: Int64 = 0,
        wiredMemoryBytes: Int64 = 0,
        cachedFilesBytes: Int64 = 0,
        pressurePercent: Int = 0,
        swapUsedBytes: Int64 = 0,
        swapFileCount: Int = 0,
        pageInsBytes: Int64 = 0,
        pageOutsBytes: Int64 = 0,
        activeBytes: Int64 = 0,
        inactiveBytes: Int64 = 0
    ) {
        self.physicalMemory = physicalMemory
        self.memoryType = memoryType
        self.usedMemoryBytes = usedMemoryBytes
        self.wiredMemoryBytes = wiredMemoryBytes
        self.cachedFilesBytes = cachedFilesBytes
        self.pressurePercent = pressurePercent
        self.swapUsedBytes = swapUsedBytes
        self.swapFileCount = swapFileCount
        self.pageInsBytes = pageInsBytes
        self.pageOutsBytes = pageOutsBytes
        self.activeBytes = activeBytes
        self.inactiveBytes = inactiveBytes
    }
}

public struct SystemCenterVolumeItem: Sendable, Codable, Equatable, Identifiable {
    public var id: String { bsdNode }
    public var name: String
    public var kind: String
    public var usedBytes: Int64
    public var usedPercent: Int
    public var bsdNode: String
    public var mountPoint: String

    public init(name: String, kind: String, usedBytes: Int64, usedPercent: Int, bsdNode: String, mountPoint: String) {
        self.name = name
        self.kind = kind
        self.usedBytes = usedBytes
        self.usedPercent = usedPercent
        self.bsdNode = bsdNode
        self.mountPoint = mountPoint
    }
}

public struct SystemCenterVolumes: Sendable, Codable, Equatable {
    public var totalCapacityBytes: Int64
    public var availableBytes: Int64
    public var volumes: [SystemCenterVolumeItem]
    public var lastVerification: String

    public init(
        totalCapacityBytes: Int64 = 0,
        availableBytes: Int64 = 0,
        volumes: [SystemCenterVolumeItem] = [],
        lastVerification: String = ""
    ) {
        self.totalCapacityBytes = totalCapacityBytes
        self.availableBytes = availableBytes
        self.volumes = volumes
        self.lastVerification = lastVerification
    }
}

public struct SystemCenterOSAndIdentity: Sendable, Codable, Equatable {
    public var osMarketingName: String
    public var osVersionAndBuild: String
    public var darwinKernel: String
    public var finderVersion: String
    public var appleScriptVersion: String
    public var sqliteVersion: String
    public var computerName: String
    public var userName: String
    public var userUUID: String
    public var uptime: String
    public var identityDump: String

    public init(
        osMarketingName: String = "",
        osVersionAndBuild: String = "",
        darwinKernel: String = "",
        finderVersion: String = "",
        appleScriptVersion: String = "",
        sqliteVersion: String = "",
        computerName: String = "",
        userName: String = "",
        userUUID: String = "",
        uptime: String = "",
        identityDump: String = ""
    ) {
        self.osMarketingName = osMarketingName
        self.osVersionAndBuild = osVersionAndBuild
        self.darwinKernel = darwinKernel
        self.finderVersion = finderVersion
        self.appleScriptVersion = appleScriptVersion
        self.sqliteVersion = sqliteVersion
        self.computerName = computerName
        self.userName = userName
        self.userUUID = userUUID
        self.uptime = uptime
        self.identityDump = identityDump
    }
}

public enum SystemProfilerProfileKind: String, Sendable, CaseIterable, Identifiable {
    case hardware = "SPHardwareDataType"
    case memory = "SPMemoryDataType"
    case storage = "SPStorageDataType"
    case display = "SPDisplaysDataType"
    case network = "SPNetworkDataType"
    case software = "SPSoftwareDataType"

    public var id: String { rawValue }

    public var titleTR: String {
        switch self {
        case .hardware: "Donanım Özeti"
        case .memory: "Bellek Yapılandırması"
        case .storage: "Depolama ve Birimler"
        case .display: "Ekranlar ve GPU"
        case .network: "Ağ Yapılandırması"
        case .software: "Yazılım ve Uygulamalar"
        }
    }
}

public enum SystemProfilerFormat: String, Sendable, CaseIterable, Identifiable {
    case text = "txt"
    case json = "json"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .text: "Düz Metin (.txt)"
        case .json: "JSON (.json)"
        }
    }
}

// MARK: - 2. Bilgi Toplayıcı Motor (`SystemCenterCollector`)

public enum SystemCenterCollector {

    public static func fetchHardware() async -> SystemCenterHardware {
        var hw = SystemCenterHardware()

        // Model identifier & name
        hw.modelIdentifier = readSysctl("hw.model")
        let archStr = readSysctl("hw.machine")
        hw.architecture = archStr.isEmpty ? "ARM64" : archStr.uppercased()

        // CPU Brand
        let cpuBrand = readSysctl("machdep.cpu.brand_string")
        hw.chip = cpuBrand.isEmpty ? "Apple Silicon" : cpuBrand

        // Cores
        let totalCores = readSysctlInt("hw.ncpu")
        let pCores = readSysctlInt("hw.perflevel0.logicalcpu")
        let eCores = readSysctlInt("hw.perflevel1.logicalcpu")
        if pCores > 0 && eCores > 0 {
            hw.totalCores = "\(totalCores) (\(pCores) performans ve \(eCores) verimlilik)"
        } else if totalCores > 0 {
            hw.totalCores = "\(totalCores)"
        }

        // IOKit: UUID, Serial Number
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPlatformExpertDevice"))
        if service != 0 {
            defer { IOObjectRelease(service) }
            if let uuid = IORegistryEntryCreateCFProperty(service, "IOPlatformUUID" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? String {
                hw.hardwareUUID = uuid
            }
            if let sn = IORegistryEntryCreateCFProperty(service, "IOPlatformSerialNumber" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? String {
                hw.serialNumber = sn
            }
        }

        // Resolution via NSScreen (Main / active displays)
        await MainActor.run {
            if let mainScreen = NSScreen.main {
                let frame = mainScreen.frame
                let scale = mainScreen.backingScaleFactor
                let w = Int(frame.width * scale)
                let h = Int(frame.height * scale)
                hw.resolution = "\(Int(frame.width)) x \(Int(frame.height))"
                if scale > 1 {
                    hw.resolution += " (Retina \(w) x \(h))"
                }
            }
        }

        // Hardware details from system_profiler SPHardwareDataType
        if let stdout = await runCommand("/usr/sbin/system_profiler", arguments: ["SPHardwareDataType", "-json"]) {
            if let data = stdout.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let arr = json["SPHardwareDataType"] as? [[String: Any]],
               let first = arr.first {
                if let name = first["machine_name"] as? String, !name.isEmpty {
                    hw.modelName = name
                }
                if let fw = first["boot_rom_version"] as? String, !fw.isEmpty {
                    hw.systemFirmwareVersion = fw
                }
            }
        }

        // GPU & Displays from SPDisplaysDataType
        if let stdout = await runCommand("/usr/sbin/system_profiler", arguments: ["SPDisplaysDataType", "-json"]) {
            if let data = stdout.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let arr = json["SPDisplaysDataType"] as? [[String: Any]],
               let first = arr.first {
                if let chipModel = first["sppci_model"] as? String {
                    hw.gpu = "Yerleşik (\(chipModel))"
                } else {
                    hw.gpu = "Yerleşik"
                }
                if let coresStr = first["sppci_cores"] as? String, let c = Int(coresStr) {
                    hw.gpuCores = c
                } else if let c = first["sppci_cores"] as? Int {
                    hw.gpuCores = c
                } else {
                    hw.gpuCores = 8
                }
            }
        }

        // Physical Disk
        if let stdout = await runCommand("/usr/sbin/diskutil", arguments: ["info", "disk0"]) {
            for line in stdout.components(separatedBy: .newlines) {
                if line.contains("Device / Media Name:") {
                    let parts = line.components(separatedBy: ":")
                    if parts.count >= 2 {
                        hw.physicalDisk = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                        break
                    }
                }
            }
        }
        if hw.physicalDisk.isEmpty {
            hw.physicalDisk = "Apple Internal NVMe SSD"
        }

        if hw.modelName.isEmpty {
            hw.modelName = hw.modelIdentifier
        }

        return hw
    }

    public static func fetchMemory() async -> SystemCenterMemory {
        var mem = SystemCenterMemory()

        // Physical Memory
        let memBytes = Int64(readSysctlUInt64("hw.memsize"))
        mem.physicalMemory = DiskSpace.formatBytes(memBytes)

        // Memory Type from SPMemoryDataType
        if let stdout = await runCommand("/usr/sbin/system_profiler", arguments: ["SPMemoryDataType", "-json"]) {
            if let data = stdout.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let arr = json["SPMemoryDataType"] as? [[String: Any]],
               let first = arr.first {
                if let type = first["dimm_type"] as? String, !type.isEmpty {
                    mem.memoryType = type
                }
            }
        }
        if mem.memoryType.isEmpty {
            mem.memoryType = "Unified Memory (LPDDR)"
        }

        // vm_stat statistics
        if let stdout = await runCommand("/usr/bin/vm_stat", arguments: []) {
            var pageSize: Int64 = 16384
            var pagesWired: Int64 = 0
            var pagesActive: Int64 = 0
            var pagesInactive: Int64 = 0
            var pagesFileBacked: Int64 = 0
            var pageins: Int64 = 0
            var pageouts: Int64 = 0
            var pagesPurgeable: Int64 = 0
            var pagesCompressor: Int64 = 0

            for line in stdout.components(separatedBy: .newlines) {
                if line.contains("page size of") {
                    let scanner = Scanner(string: line)
                    if scanner.scanUpToString("page size of") != nil {
                        _ = scanner.scanString("page size of")
                        if let size = scanner.scanInt64() {
                            pageSize = size
                        }
                    }
                } else if line.hasPrefix("Pages wired down:") {
                    pagesWired = extractNumber(from: line)
                } else if line.hasPrefix("Pages active:") {
                    pagesActive = extractNumber(from: line)
                } else if line.hasPrefix("Pages inactive:") {
                    pagesInactive = extractNumber(from: line)
                } else if line.hasPrefix("File-backed pages:") {
                    pagesFileBacked = extractNumber(from: line)
                } else if line.hasPrefix("Pageins:") {
                    pageins = extractNumber(from: line)
                } else if line.hasPrefix("Pageouts:") {
                    pageouts = extractNumber(from: line)
                } else if line.hasPrefix("Pages purgeable:") {
                    pagesPurgeable = extractNumber(from: line)
                } else if line.hasPrefix("Pages occupied by compressor:") {
                    pagesCompressor = extractNumber(from: line)
                }
            }

            mem.wiredMemoryBytes = pagesWired * pageSize
            mem.activeBytes = pagesActive * pageSize
            mem.inactiveBytes = pagesInactive * pageSize
            mem.cachedFilesBytes = (pagesFileBacked + pagesPurgeable) * pageSize
            mem.usedMemoryBytes = (pagesWired + pagesActive + pagesCompressor) * pageSize
            mem.pageInsBytes = pageins * pageSize
            mem.pageOutsBytes = pageouts * pageSize

            // Pressure Percentage estimate
            if memBytes > 0 {
                let usedTotal = mem.usedMemoryBytes
                let pct = Int((Double(usedTotal) / Double(memBytes)) * 100)
                mem.pressurePercent = min(100, max(0, pct))
            }
        }

        // Swap Usage via sysctl
        let swapStr = readSysctl("vm.swapusage")
        if !swapStr.isEmpty {
            // total = 0.00M used = 0.00M free = 0.00M
            let parts = swapStr.components(separatedBy: " ")
            if let usedIdx = parts.firstIndex(of: "used"), usedIdx + 2 < parts.count {
                let valStr = parts[usedIdx + 2].replacingOccurrences(of: "M", with: "")
                if let mb = Double(valStr) {
                    mem.swapUsedBytes = Int64(mb * 1024 * 1024)
                }
            }
        }

        // Swap file count in /private/var/vm
        let vmDir = URL(fileURLWithPath: "/private/var/vm")
        if let files = try? FileManager.default.contentsOfDirectory(at: vmDir, includingPropertiesForKeys: nil) {
            mem.swapFileCount = files.filter { $0.lastPathComponent.hasPrefix("swapfile") }.count
        }

        return mem
    }

    public static func fetchVolumes() async -> SystemCenterVolumes {
        var vols = SystemCenterVolumes()

        // Total & available capacity on root
        let rootURL = URL(fileURLWithPath: "/")
        if let vals = try? rootURL.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityKey]) {
            vols.totalCapacityBytes = Int64(vals.volumeTotalCapacity ?? 0)
            vols.availableBytes = Int64(vals.volumeAvailableCapacity ?? 0)
        }

        var items: [SystemCenterVolumeItem] = []

        // 1. Root Boot Snapshot
        if let stdout = await runCommand("/usr/sbin/diskutil", arguments: ["info", "/"]) {
            var node = "disk3s1s1"
            var name = "Macintosh HD"
            var usedBytes: Int64 = 0

            for line in stdout.components(separatedBy: .newlines) {
                if line.contains("Device Node:") {
                    node = line.components(separatedBy: ":").last?.trimmingCharacters(in: .whitespacesAndNewlines) ?? node
                } else if line.contains("Volume Name:") {
                    name = line.components(separatedBy: ":").last?.trimmingCharacters(in: .whitespacesAndNewlines) ?? name
                } else if line.contains("Volume Used Space:") {
                    usedBytes = extractBytes(from: line)
                }
            }
            let pct = vols.totalCapacityBytes > 0 ? Int((Double(usedBytes) / Double(vols.totalCapacityBytes)) * 100) : 3
            items.append(SystemCenterVolumeItem(
                name: name,
                kind: "APFS başlatma anlık görüntüsü",
                usedBytes: usedBytes,
                usedPercent: max(1, pct),
                bsdNode: node.replacingOccurrences(of: "/dev/", with: ""),
                mountPoint: "/"
            ))
        }

        // 2. Data Volume (/System/Volumes/Data)
        let dataMount = "/System/Volumes/Data"
        if FileManager.default.fileExists(atPath: dataMount),
           let stdout = await runCommand("/usr/sbin/diskutil", arguments: ["info", dataMount]) {
            var node = "disk3s5"
            var name = "Macintosh HD - Data"
            var usedBytes: Int64 = 0

            for line in stdout.components(separatedBy: .newlines) {
                if line.contains("Device Node:") {
                    node = line.components(separatedBy: ":").last?.trimmingCharacters(in: .whitespacesAndNewlines) ?? node
                } else if line.contains("Volume Name:") {
                    name = line.components(separatedBy: ":").last?.trimmingCharacters(in: .whitespacesAndNewlines) ?? name
                } else if line.contains("Volume Used Space:") {
                    usedBytes = extractBytes(from: line)
                }
            }
            let pct = vols.totalCapacityBytes > 0 ? Int((Double(usedBytes) / Double(vols.totalCapacityBytes)) * 100) : 41
            items.append(SystemCenterVolumeItem(
                name: name,
                kind: "APFS veri birimi",
                usedBytes: usedBytes,
                usedPercent: min(100, max(1, pct)),
                bsdNode: node.replacingOccurrences(of: "/dev/", with: ""),
                mountPoint: dataMount
            ))
        }

        vols.volumes = items

        let df = DateFormatter()
        df.dateStyle = .long
        df.timeStyle = .short
        vols.lastVerification = df.string(from: Date())

        return vols
    }

    public static func fetchOSAndIdentity() async -> SystemCenterOSAndIdentity {
        var os = SystemCenterOSAndIdentity()

        let osVer = ProcessInfo.processInfo.operatingSystemVersion
        let buildID = readSysctl("kern.osversion")
        os.osMarketingName = "macOS"
        os.osVersionAndBuild = "\(osVer.majorVersion).\(osVer.minorVersion).\(osVer.patchVersion) (\(buildID))"
        os.darwinKernel = "Darwin " + readSysctl("kern.osrelease")

        // Finder Version
        let finderPlist = "/System/Library/CoreServices/Finder.app/Contents/Info.plist"
        if let dict = NSDictionary(contentsOfFile: finderPlist) as? [String: Any],
           let v = dict["CFBundleShortVersionString"] as? String {
            os.finderVersion = v
        } else {
            os.finderVersion = "\(osVer.majorVersion).0"
        }

        // AppleScript Version
        if let stdout = await runCommand("/usr/bin/osascript", arguments: ["-e", "AppleScript's version"]) {
            os.appleScriptVersion = stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if os.appleScriptVersion.isEmpty {
            os.appleScriptVersion = "2.8"
        }

        // SQLite3 Version
        if let stdout = await runCommand("/usr/bin/sqlite3", arguments: ["--version"]) {
            os.sqliteVersion = stdout.components(separatedBy: .whitespaces).first ?? "3.43"
        }
        if os.sqliteVersion.isEmpty {
            os.sqliteVersion = "3.54.0"
        }

        // Host and Computer Name
        if let compName = Host.current().localizedName {
            os.computerName = compName
        } else {
            os.computerName = ProcessInfo.processInfo.hostName
        }

        // User and Full Name
        let user = NSUserName()
        let full = NSFullUserName()
        os.userName = "\(full) (\(user))"

        // User UUID via dscl
        if let stdout = await runCommand("/usr/bin/dscl", arguments: [".", "-read", "/Users/\(user)", "GeneratedUID"]) {
            let parts = stdout.components(separatedBy: ":")
            if parts.count >= 2 {
                os.userUUID = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        // Uptime
        var boottime = timeval()
        var size = MemoryLayout<timeval>.size
        if sysctlbyname("kern.boottime", &boottime, &size, nil, 0) == 0 {
            let bootDate = Date(timeIntervalSince1970: TimeInterval(boottime.tv_sec))
            let diff = Date().timeIntervalSince(bootDate)
            let days = Int(diff) / 86400
            let hours = (Int(diff) % 86400) / 3600
            let mins = (Int(diff) % 3600) / 60
            if days > 0 {
                os.uptime = "\(days) gün, \(hours) saat, \(mins) dakika"
            } else {
                os.uptime = "\(hours) saat, \(mins) dakika"
            }
        }

        // Identity dump via `id`
        if let stdout = await runCommand("/usr/bin/id", arguments: []) {
            let raw = stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            // Format into nice multi-line
            var formatted = raw
            if let groupsIdx = raw.range(of: "groups=") {
                let header = String(raw[..<groupsIdx.lowerBound])
                let groupsPart = String(raw[groupsIdx.upperBound...])
                let groupItems = groupsPart.components(separatedBy: ",")
                formatted = header + "\nGruplar:\n" + groupItems.map { "  • \($0)" }.joined(separator: "\n")
            }
            os.identityDump = formatted
        }

        return os
    }

    public static func generateProfile(kind: SystemProfilerProfileKind, format: SystemProfilerFormat) async -> String {
        var args = [kind.rawValue]
        if format == .json {
            args.append("-json")
        }
        if let stdout = await runCommand("/usr/sbin/system_profiler", arguments: args, timeout: 30) {
            return stdout
        }
        return "Sistem profili alınamadı."
    }

    // MARK: - Yardımcılar

    private static func runCommand(_ path: String, arguments: [String], timeout: TimeInterval = 10) async -> String? {
        let url = URL(fileURLWithPath: path)
        guard FileManager.default.isExecutableFile(atPath: path) else { return nil }
        guard let res = try? await CommandRunner(executableURL: url).run(arguments, timeout: timeout) else { return nil }
        return res.stdout
    }

    private static func readSysctl(_ name: String) -> String {
        var size: Int = 0
        sysctlbyname(name, nil, &size, nil, 0)
        guard size > 0 else { return "" }
        var data = [CChar](repeating: 0, count: size)
        sysctlbyname(name, &data, &size, nil, 0)
        return data.withUnsafeBufferPointer { ptr in
            guard let base = ptr.baseAddress else { return "" }
            return String(cString: base)
        }.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func readSysctlInt(_ name: String) -> Int {
        var val: Int32 = 0
        var size = MemoryLayout<Int32>.size
        sysctlbyname(name, &val, &size, nil, 0)
        return Int(val)
    }

    private static func readSysctlUInt64(_ name: String) -> UInt64 {
        var val: UInt64 = 0
        var size = MemoryLayout<UInt64>.size
        sysctlbyname(name, &val, &size, nil, 0)
        return val
    }

    private static func extractNumber(from line: String) -> Int64 {
        let digits = line.components(separatedBy: CharacterSet.decimalDigits.inverted).filter { !$0.isEmpty }
        if let first = digits.first, let num = Int64(first) {
            return num
        }
        return 0
    }

    private static func extractBytes(from line: String) -> Int64 {
        // e.g. "Volume Used Space: 13.7 GB (13655715840 Bytes)"
        if let openParen = line.range(of: "("), let bytesIdx = line.range(of: " Bytes") {
            let str = String(line[openParen.upperBound..<bytesIdx.lowerBound]).trimmingCharacters(in: .whitespaces)
            return Int64(str) ?? 0
        }
        return 0
    }
}
