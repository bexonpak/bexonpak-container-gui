import Foundation

public actor VolumeRepository: VolumeRepositoryProtocol {
    private let cli: CLIExecutor

    public init(cli: CLIExecutor) {
        self.cli = cli
    }

    public func listVolumes() async throws -> [Volume] {
        let output: [VolumeListOutput] = try await cli.runJSON([VolumeListOutput].self, arguments: ["volume", "list", "--format", "json"])
        return output.compactMap { mapToDomain($0) }
    }

    public func inspectVolume(name: String) async throws -> Volume {
        // The CLI returns a JSON array — decode and take the first element.
        let output: [VolumeListOutput] = try await cli.runJSON([VolumeListOutput].self, arguments: ["volume", "inspect", name])
        guard let first = output.first, let volume = mapToDomain(first) else {
            throw CLIError.invalidOutput("Failed to parse volume: \(name)")
        }
        return volume
    }

    public func createVolume(options: VolumeCreateOptions) async throws -> String {
        let args = options.buildArguments()
        return try await cli.run(arguments: args)
    }

    public func removeVolume(name: String, force: Bool) async throws {
        var args = ["volume", "rm", name]
        if force { args.append("--force") }
        _ = try await cli.run(arguments: args)
    }

    public func pruneVolumes() async throws -> Int {
        let output = try await cli.run(arguments: ["volume", "prune"])
        return countPrunedItems(from: output)
    }

    // MARK: - Mapping

    private func mapToDomain(_ output: VolumeListOutput) -> Volume? {
        let config = output.configuration
        guard let name = config?.name ?? output.id else { return nil }
        return Volume(
            name: name,
            driver: config?.driver ?? "",
            mountPoint: config?.source ?? "",
            labels: config?.labels ?? [:],
            scope: config?.scope ?? "",
            created: parseDate(config?.created),
            size: config?.sizeInBytes
        )
    }

    private func parseDate(_ raw: String?) -> Date? {
        guard let raw else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: raw) ?? ISO8601DateFormatter().date(from: raw)
    }

    private func countPrunedItems(from output: String) -> Int {
        let lines = output.split(separator: "\n").map(String.init)
        return lines.filter { !$0.isEmpty && !$0.hasPrefix("Reclaimed") }.count
    }
}
