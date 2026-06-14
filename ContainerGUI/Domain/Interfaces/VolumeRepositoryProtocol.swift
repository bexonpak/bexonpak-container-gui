import Foundation

public protocol VolumeRepositoryProtocol: Sendable {
    func listVolumes() async throws -> [Volume]
    func inspectVolume(name: String) async throws -> Volume
    func createVolume(options: VolumeCreateOptions) async throws -> String
    func removeVolume(name: String, force: Bool) async throws
    func pruneVolumes() async throws -> Int
}
