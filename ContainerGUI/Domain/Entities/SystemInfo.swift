import Foundation

public struct SystemInfo: Sendable, Equatable {
    // Summary counts
    public let containers: Int
    public let running: Int
    public let paused: Int
    public let stopped: Int
    public let images: Int
    public let volumes: Int
    public let networks: Int

    // Server info
    public let serverVersion: String
    public let osType: String
    public let architecture: String
    public let cpus: Int
    public let totalMemory: Int64

    // DF detail
    public let containerActive: Int
    public let containerReclaimable: Int64
    public let containerSize: Int64
    public let imageActive: Int
    public let imageReclaimable: Int64
    public let imageSize: Int64
    public let volumeActive: Int
    public let volumeReclaimable: Int64
    public let volumeSize: Int64

    // Version info
    public let apiServerVersion: String
    public let cliVersion: String

    // Status
    public let statusRaw: String

    public nonisolated init(
        containers: Int, running: Int, paused: Int, stopped: Int,
        images: Int, volumes: Int, networks: Int,
        serverVersion: String, osType: String, architecture: String, cpus: Int, totalMemory: Int64,
        containerActive: Int = 0, containerReclaimable: Int64 = 0, containerSize: Int64 = 0,
        imageActive: Int = 0, imageReclaimable: Int64 = 0, imageSize: Int64 = 0,
        volumeActive: Int = 0, volumeReclaimable: Int64 = 0, volumeSize: Int64 = 0,
        apiServerVersion: String = "", cliVersion: String = "",
        statusRaw: String = ""
    ) {
        self.containers = containers
        self.running = running
        self.paused = paused
        self.stopped = stopped
        self.images = images
        self.volumes = volumes
        self.networks = networks
        self.serverVersion = serverVersion
        self.osType = osType
        self.architecture = architecture
        self.cpus = cpus
        self.totalMemory = totalMemory
        self.containerActive = containerActive
        self.containerReclaimable = containerReclaimable
        self.containerSize = containerSize
        self.imageActive = imageActive
        self.imageReclaimable = imageReclaimable
        self.imageSize = imageSize
        self.volumeActive = volumeActive
        self.volumeReclaimable = volumeReclaimable
        self.volumeSize = volumeSize
        self.apiServerVersion = apiServerVersion
        self.cliVersion = cliVersion
        self.statusRaw = statusRaw
    }
}

public struct ContainerStats: Sendable, Equatable {
    public let containerId: String
    public let name: String
    public let cpuPercent: Double
    public let memoryUsage: Int64
    public let memoryLimit: Int64
    public let networkRx: Int64
    public let networkTx: Int64
    public let blockRead: Int64
    public let blockWrite: Int64
    public let pids: Int
}
