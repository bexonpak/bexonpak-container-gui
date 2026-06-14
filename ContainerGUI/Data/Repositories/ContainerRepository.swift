import Foundation

public actor ContainerRepository: ContainerRepositoryProtocol {
    private let cli: CLIExecutor

    public init(cli: CLIExecutor) {
        self.cli = cli
    }

    public func listContainers(all: Bool) async throws -> [Container] {
        let args = ["ls", "-a", "--format", "json"]
        let output: [ContainerListOutput] = try await cli.runJSON([ContainerListOutput].self, arguments: args)
        return output.compactMap { mapToDomain($0) }
    }

    public func inspectContainer(id: String) async throws -> ContainerInspectInfo {
        let raw = try await cli.run(arguments: ["inspect", id])
        return try Self.parseContainerInspect(raw)
    }

    public func startContainer(id: String) async throws {
        _ = try await cli.run(arguments: ["start", id])
    }

    public func stopContainer(id: String) async throws {
        _ = try await cli.run(arguments: ["stop", id])
    }

    public func restartContainer(id: String) async throws {
        _ = try await cli.run(arguments: ["restart", id])
    }

    public func killContainer(id: String, signal: String?) async throws {
        var args = ["kill", id]
        if let signal { args += ["--signal", signal] }
        _ = try await cli.run(arguments: args)
    }

    public func pauseContainer(id: String) async throws {
        _ = try await cli.run(arguments: ["pause", id])
    }

    public func unpauseContainer(id: String) async throws {
        _ = try await cli.run(arguments: ["unpause", id])
    }

    public func removeContainer(id: String, force: Bool) async throws {
        var args = ["rm", id]
        if force { args.append("--force") }
        _ = try await cli.run(arguments: args)
    }

    public func containerLogs(id: String, tail: Int) async throws -> String {
        try await cli.run(arguments: ["logs", "--tail", String(tail), id])
    }

    public func containerStats(id: String) async throws -> ContainerStats {
        let output: StatsOutput = try await cli.runJSON(StatsOutput.self, arguments: ["stats", "--no-stream", "--format", "json", id])
        return mapStatsToDomain(output)
    }

    public func createContainer(options: ContainerCreateOptions) async throws -> String {
        let args = options.buildArguments()
        return try await cli.run(arguments: args)
    }

    public func execContainer(id: String, command: [String]) async throws -> String {
        try await cli.run(arguments: ["exec", id] + command)
    }

    public func pruneContainers() async throws -> Int {
        let output = try await cli.run(arguments: ["prune"])
        return countPrunedItems(from: output)
    }

    // MARK: - Mapping from CLI output

    private func mapToDomain(_ output: ContainerListOutput) -> Container? {
        guard let id = output.id else { return nil }
        let cfg = output.configuration
        let statusOutput = output.status

        // Extract the first network's IPv4 address (strip CIDR suffix)
        let ip = statusOutput?.networks?
            .first?
            .ipv4Address?
            .split(separator: "/")
            .first
            .map(String.init)

        return Container(
            id: id,
            name: id,
            image: cfg?.image?.reference ?? "",
            status: parseStatus(statusOutput?.state),
            created: parseDate(cfg?.creationDate) ?? Date(),
            ports: (cfg?.publishedPorts ?? []).map {
                PortMapping(hostPort: $0.hostPort ?? 0, containerPort: $0.containerPort ?? 0, protocolType: $0.protocolType ?? "tcp")
            },
            platform: [cfg?.platform?.architecture, cfg?.platform?.os]
                .compactMap { $0 }
                .joined(separator: "/"),
            containerIP: ip,
            startedAt: parseDate(statusOutput?.startedDate)
        )
    }

    private static nonisolated func parseContainerInspect(_ json: String) throws -> ContainerInspectInfo {
        struct RawInspect: Decodable, Sendable {
            let id: String?
            let configuration: InspectConfig?
            let status: InspectStatus?
        }
        struct InspectConfig: Decodable, Sendable {
            let image: InspectImageRef?
            let platform: InspectPlatform?
            let resources: InspectResources?
            let runtimeHandler: String?
            let stopSignal: String?
            let mounts: [InspectMount]?
            let networks: [InspectNetCfg]?
            let initProcess: InspectProcess?
            let labels: [String: String]?
            let publishedPorts: [CLIJsonPort]?
            let capAdd: [String]?
            let capDrop: [String]?
            let readOnly: Bool?
            let rosetta: Bool?
            let ssh: Bool?
            let virtualization: Bool?
            let useInit: Bool?
        }
        struct InspectImageRef: Decodable, Sendable {
            let reference: String?
            let descriptor: InspectDescriptor?
        }
        struct InspectDescriptor: Decodable, Sendable {
            let digest: String?
        }
        struct InspectPlatform: Decodable, Sendable {
            let architecture: String?
            let os: String?
        }
        struct InspectResources: Decodable, Sendable {
            let cpus: Int?
            let memoryInBytes: Int64?
        }
        struct InspectMount: Decodable, Sendable {
            let destination: String?
            let source: String?
            let type: InspectMountType?
        }
        struct InspectMountType: Decodable, Sendable {
            let virtiofs: String?
            let tmpfs: String?
            // other mount types
        }
        struct InspectNetCfg: Decodable, Sendable {
            let network: String?
        }
        struct InspectProcess: Decodable, Sendable {
            let executable: String?
            let arguments: [String]?
            let environment: [String]?
            let workingDirectory: String?
        }
        struct InspectStatus: Decodable, Sendable {
            let state: String?
            let startedDate: String?
            let networks: [InspectNetStatus]?
        }
        struct InspectNetStatus: Decodable, Sendable {
            let network: String?
            let ipv4Address: String?
            let hostname: String?
        }

        let data = json.data(using: .utf8) ?? Data()
        let decoder = JSONDecoder()

        let output: RawInspect
        if json.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("[") {
            let arr = try decoder.decode([RawInspect].self, from: data)
            guard let first = arr.first else {
                throw CLIError.invalidOutput("Empty inspect result")
            }
            output = first
        } else {
            output = try decoder.decode(RawInspect.self, from: data)
        }

        let cfg = output.configuration
        let st = output.status

        let mountInfos: [ContainerMountInfo] = (cfg?.mounts ?? []).compactMap { m in
            guard let dst = m.destination else { return nil }
            let src = m.source ?? ""
            let type: String
            if m.type?.virtiofs != nil { type = "virtiofs" }
            else if m.type?.tmpfs != nil { type = "tmpfs" }
            else { type = "unknown" }
            return ContainerMountInfo(destination: dst, source: src, type: type)
        }

        let netInfo: [InspectContainerNetwork] = (st?.networks ?? []).compactMap { n in
            guard let name = n.network else { return nil }
            let ip = n.ipv4Address?.split(separator: "/").first.map(String.init)
            return InspectContainerNetwork(network: name, hostname: n.hostname, ipAddress: ip)
        }

        let ip = st?.networks?.first?.ipv4Address?.split(separator: "/").first.map(String.init)

        return ContainerInspectInfo(
            image: cfg?.image?.reference ?? "",
            imageDigest: cfg?.image?.descriptor?.digest ?? "",
            architecture: cfg?.platform?.architecture ?? "",
            os: cfg?.platform?.os ?? "",
            cpus: cfg?.resources?.cpus ?? 0,
            memoryBytes: cfg?.resources?.memoryInBytes ?? 0,
            runtimeHandler: cfg?.runtimeHandler ?? "",
            stopSignal: cfg?.stopSignal,
            mounts: mountInfos,
            networks: netInfo,
            env: cfg?.initProcess?.environment ?? [],
            entrypoint: cfg?.initProcess?.arguments?.joined(separator: " "),
            executable: cfg?.initProcess?.executable,
            workingDir: cfg?.initProcess?.workingDirectory,
            labels: cfg?.labels ?? [:],
            readOnly: cfg?.readOnly ?? false,
            rosetta: cfg?.rosetta ?? false,
            ssh: cfg?.ssh ?? false,
            virtualization: cfg?.virtualization ?? false,
            useInit: cfg?.useInit ?? false,
            state: st?.state ?? "",
            startedAt: Self.parseDate(st?.startedDate),
            ipAddress: ip
        )
    }

    private static nonisolated func parseDate(_ raw: String?) -> Date? {
        guard let raw else { return nil }
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fmt.date(from: raw) ?? ISO8601DateFormatter().date(from: raw)
    }

    private func parseStatus(_ raw: String?) -> ContainerStatus {
        guard let raw else { return .unknown("") }
        let lower = raw.lowercased()
        if lower.hasPrefix("up") || lower == "running" { return .running }
        if lower.hasPrefix("paused") { return .paused }
        if lower.hasPrefix("exited") {
            let digits = lower.filter(\.isNumber)
            return .exited(code: Int(digits) ?? 0)
        }
        if lower.hasPrefix("stopped") { return .stopped }
        return .unknown(raw)
    }

    private func parseDate(_ raw: String?) -> Date? {
        guard let raw else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: raw) ?? ISO8601DateFormatter().date(from: raw)
    }

    private func mapStatsToDomain(_ output: StatsOutput) -> ContainerStats {
        ContainerStats(
            containerId: output.containerId ?? "",
            name: output.name ?? "",
            cpuPercent: output.cpuPercent ?? 0,
            memoryUsage: output.memoryUsage ?? 0,
            memoryLimit: output.memoryLimit ?? 0,
            networkRx: output.networkRx ?? 0,
            networkTx: output.networkTx ?? 0,
            blockRead: output.blockRead ?? 0,
            blockWrite: output.blockWrite ?? 0,
            pids: output.pids ?? 0
        )
    }

    private func countPrunedItems(from output: String) -> Int {
        // Output format: "Reclaimed X in disk space\nname1\nname2..."
        let lines = output.split(separator: "\n").map(String.init)
        // Count non-empty lines that aren't the "Reclaimed..." summary.
        return lines.filter { !$0.isEmpty && !$0.hasPrefix("Reclaimed") }.count
    }
}
