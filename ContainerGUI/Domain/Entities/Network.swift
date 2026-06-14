import Foundation

public struct ContainerNetwork: Identifiable, Sendable, Equatable, Hashable {
    public let id: String
    public let name: String
    public let driver: String
    public let scope: String
    public let subnet: String?
    public let gateway: String?
    public let containers: [String]

    public nonisolated init(
        id: String,
        name: String,
        driver: String,
        scope: String,
        subnet: String?,
        gateway: String?,
        containers: [String]
    ) {
        self.id = id
        self.name = name
        self.driver = driver
        self.scope = scope
        self.subnet = subnet
        self.gateway = gateway
        self.containers = containers
    }
}
