import Foundation

public protocol NetworkRepositoryProtocol: Sendable {
    func listNetworks() async throws -> [ContainerNetwork]
    func inspectNetwork(id: String) async throws -> ContainerNetwork
    func createNetwork(options: NetworkCreateOptions) async throws -> String
    func removeNetwork(id: String) async throws
    func pruneNetworks() async throws -> Int
}
