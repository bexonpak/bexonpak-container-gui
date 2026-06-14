import Foundation

public protocol SystemRepositoryProtocol: Sendable {
    func systemInfo() async throws -> SystemInfo
    func systemStatus() async throws -> String
    func systemStatusJSON() async throws -> String
    func systemVersion() async throws -> String
    func systemLogs(tail: String) async throws -> String
    func systemDf() async throws -> SystemInfo
    func startServices() async throws
    func stopServices() async throws
    func pruneContainers() async throws -> Int
    func pruneImages() async throws -> Int
    func pruneVolumes() async throws -> Int
    func pruneNetworks() async throws -> Int
}
