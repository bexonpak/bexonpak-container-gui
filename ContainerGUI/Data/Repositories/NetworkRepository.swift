import Foundation

public actor NetworkRepository: NetworkRepositoryProtocol {
    private let cli: CLIExecutor

    public init(cli: CLIExecutor) {
        self.cli = cli
    }

    public func listNetworks() async throws -> [ContainerNetwork] {
        let output: [NetworkListOutput] = try await cli.runJSON([NetworkListOutput].self, arguments: ["network", "list", "--format", "json"])
        return output.compactMap { mapToDomain($0) }
    }

    public func inspectNetwork(id: String) async throws -> ContainerNetwork {
        let output: [NetworkListOutput] = try await cli.runJSON([NetworkListOutput].self, arguments: ["network", "inspect", id])
        guard let first = output.first, let network = mapToDomain(first) else {
            throw CLIError.invalidOutput("Failed to parse network: \(id)")
        }
        return network
    }

    public func createNetwork(options: NetworkCreateOptions) async throws -> String {
        let args = options.buildArguments()
        return try await cli.run(arguments: args)
    }

    public func removeNetwork(id: String) async throws {
        _ = try await cli.run(arguments: ["network", "rm", id])
    }

    public func pruneNetworks() async throws -> Int {
        let output = try await cli.run(arguments: ["network", "prune"], input: "y\n")
        return countPrunedItems(from: output)
    }

    // MARK: - Mapping

    private func mapToDomain(_ output: NetworkListOutput) -> ContainerNetwork? {
        let config = output.configuration
        let status = output.status
        guard let id = output.id, let name = config?.name else { return nil }
        return ContainerNetwork(
            id: id,
            name: name,
            driver: config?.plugin ?? config?.mode ?? "",
            scope: "",
            subnet: status?.ipv4Subnet,
            gateway: status?.ipv4Gateway,
            containers: []
        )
    }

    private func countPrunedItems(from output: String) -> Int {
        let lines = output.split(separator: "\n").map(String.init)
        return lines.filter { !$0.isEmpty && !$0.hasPrefix("Reclaimed") }.count
    }
}
