import Foundation

public struct Container: Identifiable, Sendable, Equatable, Hashable {
    public let id: String
    public let name: String
    public let image: String
    public let status: ContainerStatus
    public let created: Date
    public let ports: [PortMapping]
    public let platform: String
    public let containerIP: String?
    public let startedAt: Date?

    public nonisolated init(
        id: String,
        name: String,
        image: String,
        status: ContainerStatus,
        created: Date,
        ports: [PortMapping],
        platform: String,
        containerIP: String? = nil,
        startedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.image = image
        self.status = status
        self.created = created
        self.ports = ports
        self.platform = platform
        self.containerIP = containerIP
        self.startedAt = startedAt
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

public enum ContainerStatus: Sendable, Equatable, Hashable {
    case running
    case paused
    case stopped
    case exited(code: Int)
    case unknown(String)

    public var displayName: String {
        switch self {
        case .running: return "Running"
        case .paused: return "Paused"
        case .stopped: return "Stopped"
        case .exited(let code): return "Exited (\(code))"
        case .unknown(let raw): return raw
        }
    }
}

public struct PortMapping: Sendable, Equatable, Hashable {
    public let hostPort: Int
    public let containerPort: Int
    public let protocolType: String

    public nonisolated init(hostPort: Int, containerPort: Int, protocolType: String) {
        self.hostPort = hostPort
        self.containerPort = containerPort
        self.protocolType = protocolType
    }
}
