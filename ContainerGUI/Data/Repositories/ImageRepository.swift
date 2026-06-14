import Foundation

public actor ImageRepository: ImageRepositoryProtocol {
    private let cli: CLIExecutor

    public init(cli: CLIExecutor) {
        self.cli = cli
    }

    public func listImages() async throws -> [ContainerImage] {
        let output: [ImageListOutput] = try await cli.runJSON([ImageListOutput].self, arguments: ["image", "list", "--format", "json"])
        return output.compactMap { mapToDomain($0) }
    }

    public func buildImage(options: ImageBuildOptions) async throws -> AsyncThrowingStream<ImageBuildLog, Error> {
        let args = options.buildArguments()
        let stream = await cli.streamOutput(arguments: args)
        return stream.map { line in
            let step = Self.parseBuildStep(from: line)
            return ImageBuildLog(step: step ?? "output", message: line)
        }
    }

    public func pullImage(reference: String, platform: String?) async throws -> AsyncThrowingStream<ImageBuildLog, Error> {
        var args = ["image", "pull", "--progress", "plain", reference]
        if let platform { args += ["--platform", platform] }
        let stream = await cli.streamOutput(arguments: args)
        return stream.map { line in
            ImageBuildLog(step: "pulling", message: line)
        }
    }

    public func inspectImage(reference: String) async throws -> ImageInspectInfo {
        let raw = try await cli.run(arguments: ["image", "inspect", reference])
        return try Self.parseImageInspect(raw)
    }

    /// Parse `container image inspect` JSON (returns an array with one element) into `ImageInspectInfo`.
    private static nonisolated func parseImageInspect(_ json: String) throws -> ImageInspectInfo {
        struct RawInspect: Decodable, Sendable {
            let id: String?
            let configuration: ImageListOutput.ImageConfiguration?
            let variants: [Variant]?
        }
        struct Variant: Decodable, Sendable {
            let config: VariantConfig?
            let size: Int64?
        }
        struct VariantConfig: Decodable, Sendable {
            let architecture: String?
            let os: String?
            let config: VariantDetail?
            let created: String?
            let history: [HistoryEntry]?
        }
        struct VariantDetail: Decodable, Sendable {
            let Cmd: [String]?
            let Entrypoint: [String]?
            let Env: [String]?
            let Labels: [String: String]?
            let StopSignal: String?
        }
        struct HistoryEntry: Decodable, Sendable {
            let created: String?
        }

        let data = json.data(using: .utf8) ?? Data()
        let decoder = JSONDecoder()

        // The CLI returns an array. Decode as array then take the first element.
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

        // Pick the first non-unknown variant for platform info
        let mainVariant = output.variants?.first(where: { $0.config?.architecture?.lowercased() != "unknown" })
            ?? output.variants?.first
        let variant = mainVariant?.config
        let detail = variant?.config

        let mainSize = mainVariant?.size
        let digest = output.id ?? ""
        let architecture = variant?.architecture ?? ""
        let os = variant?.os ?? ""
        let created = variant.flatMap { Self.parseDate($0.created) }
        let labels = detail?.Labels ?? [:]
        let env = detail?.Env ?? []
        let entrypoint = detail?.Entrypoint ?? []
        let cmd = detail?.Cmd ?? []
        let stopSignal = detail?.StopSignal
        let layers = variant?.history?.count ?? 0

        return ImageInspectInfo(
            digest: digest,
            architecture: architecture,
            os: os,
            created: created,
            labels: labels,
            env: env,
            entrypoint: entrypoint,
            cmd: cmd,
            stopSignal: stopSignal,
            layers: layers,
            size: mainSize ?? 0
        )
    }

    private static nonisolated func parseDate(_ raw: String?) -> Date? {
        guard let raw else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: raw) ?? ISO8601DateFormatter().date(from: raw)
    }

    public func removeImage(id: String, force: Bool) async throws {
        var args = ["image", "rm", id]
        if force { args.append("--force") }
        _ = try await cli.run(arguments: args)
    }

    public func pruneImages() async throws -> Int {
        let output = try await cli.run(arguments: ["image", "prune"])
        return countPrunedItems(from: output)
    }

    // MARK: - Builder Management

    public func builderStart(cpus: Int? = nil, memory: String? = nil) async throws {
        var args = ["builder", "start"]
        if let cpus { args += ["--cpus", String(cpus)] }
        if let memory { args += ["--memory", memory] }
        _ = try await cli.run(arguments: args)
    }

    public func builderStatus() async throws -> BuilderStatus? {
        let output: [BuilderStatusOutput] = try await cli.runJSON([BuilderStatusOutput].self, arguments: ["builder", "status", "--format", "json"])
        return output.first.map { mapBuilderStatus($0) }
    }

    public func builderStop() async throws {
        _ = try await cli.run(arguments: ["builder", "stop"])
    }

    // MARK: - Mapping

    private func mapToDomain(_ output: ImageListOutput) -> ContainerImage? {
        guard let id = output.id else { return nil }
        return ContainerImage(
            id: id,
            repository: output.repository ?? "<none>",
            tag: output.tag ?? "<none>",
            size: output.size ?? 0,
            created: parseDate(output.created) ?? Date(),
            fullName: output.configuration?.name ?? ""
        )
    }

    private func mapBuilderStatus(_ output: BuilderStatusOutput) -> BuilderStatus {
        let config = output.configuration
        let res = config?.resources
        return BuilderStatus(
            id: output.id ?? "buildkit",
            state: output.status?.state ?? "unknown",
            cpus: res?.cpus ?? 0,
            memory: res?.memoryInBytes ?? 0,
            startedDate: parseDate(output.status?.startedDate),
            imageRef: config?.image?.reference ?? ""
        )
    }

    private func parseDate(_ raw: String?) -> Date? {
        guard let raw else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: raw) ?? ISO8601DateFormatter().date(from: raw)
    }

    private static nonisolated func parseBuildStep(from line: String) -> String? {
        if line.hasPrefix("#") || line.contains("Step ") {
            return line.components(separatedBy: CharacterSet.whitespaces).first
        }
        return nil
    }

    private func countPrunedItems(from output: String) -> Int {
        let lines = output.split(separator: "\n").map(String.init)
        return lines.filter { !$0.isEmpty && !$0.hasPrefix("Reclaimed") }.count
    }
}

// MARK: - Builder Status CLI Model

struct BuilderStatusOutput: Decodable, Sendable {
    let id: String?
    let configuration: BuilderConfig?
    let status: BuilderState?

    struct BuilderConfig: Decodable, Sendable {
        let resources: BuilderResources?
        let image: BuilderImage?

        struct BuilderResources: Decodable, Sendable {
            let cpus: Int?
            let memoryInBytes: Int64?
        }

        struct BuilderImage: Decodable, Sendable {
            let reference: String?
        }
    }

    struct BuilderState: Decodable, Sendable {
        let state: String?
        let startedDate: String?
    }

    enum CodingKeys: String, CodingKey {
        case id, configuration, status
    }

    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(String.self, forKey: .id)
        self.configuration = try container.decodeIfPresent(BuilderConfig.self, forKey: .configuration)
        self.status = try container.decodeIfPresent(BuilderState.self, forKey: .status)
    }
}

// MARK: - AsyncThrowingStream map helper

extension AsyncThrowingStream {
    nonisolated func map<T>(_ transform: @escaping (Element) -> T) -> AsyncThrowingStream<T, Error> {
        AsyncThrowingStream<T, Error> { continuation in
            Task { [self] in
                do {
                    for try await element in self {
                        continuation.yield(transform(element))
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
