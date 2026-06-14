import Foundation

/// Parsed inspect info for a container.
public struct ContainerInspectInfo: Sendable, Equatable {
    public let image: String
    public let imageDigest: String
    public let architecture: String
    public let os: String
    public let cpus: Int
    public let memoryBytes: Int64
    public let runtimeHandler: String
    public let stopSignal: String?
    public let mounts: [ContainerMountInfo]
    public let networks: [InspectContainerNetwork]
    public let env: [String]
    public let entrypoint: String?
    public let executable: String?
    public let workingDir: String?
    public let labels: [String: String]
    public let readOnly: Bool
    public let rosetta: Bool
    public let ssh: Bool
    public let virtualization: Bool
    public let useInit: Bool
    public let state: String
    public let startedAt: Date?
    public let ipAddress: String?

    public nonisolated init(
        image: String,
        imageDigest: String = "",
        architecture: String = "",
        os: String = "",
        cpus: Int = 0,
        memoryBytes: Int64 = 0,
        runtimeHandler: String = "",
        stopSignal: String? = nil,
        mounts: [ContainerMountInfo] = [],
        networks: [InspectContainerNetwork] = [],
        env: [String] = [],
        entrypoint: String? = nil,
        executable: String? = nil,
        workingDir: String? = nil,
        labels: [String: String] = [:],
        readOnly: Bool = false,
        rosetta: Bool = false,
        ssh: Bool = false,
        virtualization: Bool = false,
        useInit: Bool = false,
        state: String = "",
        startedAt: Date? = nil,
        ipAddress: String? = nil
    ) {
        self.image = image
        self.imageDigest = imageDigest
        self.architecture = architecture
        self.os = os
        self.cpus = cpus
        self.memoryBytes = memoryBytes
        self.runtimeHandler = runtimeHandler
        self.stopSignal = stopSignal
        self.mounts = mounts
        self.networks = networks
        self.env = env
        self.entrypoint = entrypoint
        self.executable = executable
        self.workingDir = workingDir
        self.labels = labels
        self.readOnly = readOnly
        self.rosetta = rosetta
        self.ssh = ssh
        self.virtualization = virtualization
        self.useInit = useInit
        self.state = state
        self.startedAt = startedAt
        self.ipAddress = ipAddress
    }
}

public struct ContainerMountInfo: Sendable, Equatable {
    public let destination: String
    public let source: String
    public let type: String

    public nonisolated init(destination: String, source: String, type: String) {
        self.destination = destination
        self.source = source
        self.type = type
    }
}

public struct InspectContainerNetwork: Sendable, Equatable {
    public let network: String
    public let hostname: String?
    public let ipAddress: String?

    public nonisolated init(network: String, hostname: String? = nil, ipAddress: String? = nil) {
        self.network = network
        self.hostname = hostname
        self.ipAddress = ipAddress
    }
}
