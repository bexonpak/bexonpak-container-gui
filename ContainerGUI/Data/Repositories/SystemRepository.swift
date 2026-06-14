import Foundation

public actor SystemRepository: SystemRepositoryProtocol {
    private let cli: CLIExecutor

    public init(cli: CLIExecutor) {
        self.cli = cli
    }

    public func systemInfo() async throws -> SystemInfo {
        async let statusJSON = cli.run(arguments: ["system", "status", "--format", "json"])
        async let statusText = cli.run(arguments: ["system", "status"])
        async let dfOutput: SystemDFOutput = cli.runJSON(SystemDFOutput.self, arguments: ["system", "df", "--format", "json"])
        async let versionText = cli.run(arguments: ["system", "version", "--format", "json"])

        let (sJSON, sText, df, vText) = try await (statusJSON, statusText, dfOutput, versionText)
        return parseSystemInfo(statusJSON: sJSON, statusText: sText, df: df, versionJSON: vText)
    }

    public func systemStatus() async throws -> String {
        try await cli.run(arguments: ["system", "status"])
    }

    public func systemStatusJSON() async throws -> String {
        try await cli.run(arguments: ["system", "status", "--format", "json"])
    }

    public func systemVersion() async throws -> String {
        try await cli.run(arguments: ["system", "version", "--format", "json"])
    }

    public func systemLogs(tail: String = "5m") async throws -> String {
        try await cli.run(arguments: ["system", "logs", "--last", tail])
    }

    public func startServices() async throws {
        _ = try await cli.run(arguments: ["system", "start"])
    }

    public func stopServices() async throws {
        _ = try await cli.run(arguments: ["system", "stop"])
    }

    public func systemDf() async throws -> SystemInfo {
        try await systemInfo()
    }

    public func pruneContainers() async throws -> Int {
        _ = try await cli.run(arguments: ["prune"])
        return 1
    }

    public func pruneImages() async throws -> Int {
        let output = try await cli.run(arguments: ["image", "prune", "--all"])
        return countPrunedItems(from: output)
    }

    public func pruneVolumes() async throws -> Int {
        let output = try await cli.run(arguments: ["volume", "prune"])
        return countPrunedItems(from: output)
    }

    public func pruneNetworks() async throws -> Int {
        let output = try await cli.run(arguments: ["network", "prune"], input: "y\n")
        return countPrunedItems(from: output)
    }

    // MARK: - Parsing

    private func parseSystemInfo(statusJSON: String, statusText: String, df: SystemDFOutput, versionJSON: String) -> SystemInfo {
        let statusDict = parseJSONDict(statusJSON)
        let tableDict = parseStatusTable(statusText)
        let versions = parseVersionJSON(versionJSON)

        let c = df.containers
        let im = df.images
        let v = df.volumes

        return SystemInfo(
            containers: c?.total ?? 0,
            running: statusDict["status"]?.lowercased() == "running" ? (c?.active ?? 0) : 0,
            paused: 0,
            stopped: max(0, (c?.total ?? 0) - (c?.active ?? 0)),
            images: im?.total ?? 0,
            volumes: v?.total ?? 0,
            networks: 0,
            serverVersion: tableDict["apiserver.version"] ?? "",
            osType: "macOS",
            architecture: ProcessInfo.processInfo.machineName,
            cpus: ProcessInfo.processInfo.processorCount,
            totalMemory: Int64(ProcessInfo.processInfo.physicalMemory),
            containerActive: c?.active ?? 0,
            containerReclaimable: c?.reclaimable ?? 0,
            containerSize: c?.sizeInBytes ?? 0,
            imageActive: im?.active ?? 0,
            imageReclaimable: im?.reclaimable ?? 0,
            imageSize: im?.sizeInBytes ?? 0,
            volumeActive: v?.active ?? 0,
            volumeReclaimable: v?.reclaimable ?? 0,
            volumeSize: v?.sizeInBytes ?? 0,
            apiServerVersion: versions.apiserver,
            cliVersion: versions.cli,
            statusRaw: statusText
        )
    }

    /// Parse a simple flat JSON object into a [String: String] dict
    private func parseJSONDict(_ json: String) -> [String: String] {
        guard let data = json.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        var result: [String: String] = [:]
        for (key, value) in obj {
            result[key.lowercased()] = "\(value)"
        }
        return result
    }

    /// Parse a key-value table like "FIELD   VALUE\nname   value"
    private func parseStatusTable(_ text: String) -> [String: String] {
        var dict: [String: String] = [:]
        for line in text.split(separator: "\n") {
            let parts = line.split(maxSplits: 1) { $0.isWhitespace }
            if parts.count == 2 {
                dict[String(parts[0]).lowercased()] = String(parts[1])
            }
        }
        return dict
    }

    /// Parse version JSON array: [{"appName":"container",...}, {"appName":"container-apiserver",...}]
    private func parseVersionJSON(_ text: String) -> (cli: String, apiserver: String) {
        guard let data = text.data(using: .utf8),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return ("", "")
        }
        var cli = "", api = ""
        for item in arr {
            let name = item["appName"] as? String ?? ""
            let version = item["version"] as? String ?? ""
            if name == "container" { cli = version }
            if name == "container-apiserver" { api = version }
        }
        return (cli, api)
    }

    private func countPrunedItems(from output: String) -> Int {
        let lines = output.split(separator: "\n").map(String.init)
        return lines.filter { !$0.isEmpty && !$0.hasPrefix("Reclaimed") }.count
    }
}

// MARK: - DF JSON model

struct SystemDFOutput: Decodable, Sendable {
    let containers: DFEntry?
    let images: DFEntry?
    let volumes: DFEntry?

    enum CodingKeys: String, CodingKey {
        case containers
        case images
        case volumes
    }

    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.containers = try container.decodeIfPresent(DFEntry.self, forKey: .containers)
        self.images = try container.decodeIfPresent(DFEntry.self, forKey: .images)
        self.volumes = try container.decodeIfPresent(DFEntry.self, forKey: .volumes)
    }

    struct DFEntry: Decodable, Sendable {
        let total: Int?
        let active: Int?
        let reclaimable: Int64?
        let sizeInBytes: Int64?

        enum CodingKeys: String, CodingKey {
            case total
            case active
            case reclaimable
            case sizeInBytes
        }

        nonisolated init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.total = try container.decodeIfPresent(Int.self, forKey: .total)
            self.active = try container.decodeIfPresent(Int.self, forKey: .active)
            self.reclaimable = try container.decodeIfPresent(Int64.self, forKey: .reclaimable)
            self.sizeInBytes = try container.decodeIfPresent(Int64.self, forKey: .sizeInBytes)
        }
    }
}

extension ProcessInfo {
    /// e.g. "arm64" or "x86_64"
    fileprivate nonisolated var machineName: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let ptr = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: Int(_SYS_NAMELEN)) { String(cString: $0) }
        }
        return ptr
    }
}
