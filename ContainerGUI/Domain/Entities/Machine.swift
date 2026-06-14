import Foundation

public struct Machine: Identifiable, Sendable, Equatable, Hashable {
    public let name: String
    public let status: MachineStatus
    public let cpus: Int
    public let memory: Int64
    public let diskSize: Int64
    public let vmDirectory: String
    public let runningSince: Date?

    public var id: String { name }

    public nonisolated init(
        name: String,
        status: MachineStatus,
        cpus: Int,
        memory: Int64,
        diskSize: Int64,
        vmDirectory: String,
        runningSince: Date?
    ) {
        self.name = name
        self.status = status
        self.cpus = cpus
        self.memory = memory
        self.diskSize = diskSize
        self.vmDirectory = vmDirectory
        self.runningSince = runningSince
    }
}

public enum MachineStatus: Sendable, Equatable, Hashable {
    case running
    case stopped
    case starting
    case stopping
    case unknown(String)

    public var displayName: String {
        switch self {
        case .running: return "Running"
        case .stopped: return "Stopped"
        case .starting: return "Starting"
        case .stopping: return "Stopping"
        case .unknown(let raw): return raw
        }
    }
}
