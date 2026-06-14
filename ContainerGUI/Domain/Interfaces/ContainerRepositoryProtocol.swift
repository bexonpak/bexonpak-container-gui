import Foundation

public protocol ContainerRepositoryProtocol: Sendable {
    func listContainers(all: Bool) async throws -> [Container]
    func inspectContainer(id: String) async throws -> ContainerInspectInfo
    func startContainer(id: String) async throws
    func stopContainer(id: String) async throws
    func restartContainer(id: String) async throws
    func killContainer(id: String, signal: String?) async throws
    func pauseContainer(id: String) async throws
    func unpauseContainer(id: String) async throws
    func removeContainer(id: String, force: Bool) async throws
    func containerLogs(id: String, tail: Int) async throws -> String
    func containerStats(id: String) async throws -> ContainerStats
    func createContainer(options: ContainerCreateOptions) async throws -> String
    func execContainer(id: String, command: [String]) async throws -> String
    func pruneContainers() async throws -> Int
}
