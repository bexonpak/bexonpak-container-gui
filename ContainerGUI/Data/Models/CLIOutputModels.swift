@preconcurrency import Foundation

// Data-layer models that mirror the CLI JSON output.
// Mapped to Domain entities at the repository boundary.

// MARK: - Container
//
// CLI output (JSON) format:
//   [{
//     "id": "<container-id>",
//     "configuration": {
//       "creationDate": "2026-06-13T01:53:08Z",
//       "image": { "reference": "docker.io/arm64v8/alpine:latest", ... },
//       "platform": { "architecture": "arm64", "os": "linux" },
//       "publishedPorts": [],
//       "mounts": [],
//       "networks": [{"network": "default", ...}],
//       "resources": { "cpus": 4, "memoryInBytes": 1073741824, ... },
//       "runtimeHandler": "container-runtime-linux",
//       "capAdd": [],
//       "capDrop": [],
//       "labels": {},
//       "readOnly": false,
//       "rosetta": false,
//       "ssh": false,
//       "virtualization": false,
//       "useInit": false
//     },
//     "status": { "state": "stopped", "startedDate": "..." }
//   }]

struct ContainerListOutput: Decodable, Sendable {
    let id: String?
    let configuration: ContainerConfiguration?
    let status: ContainerStatusOutput?

    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(String.self, forKey: .id)
        self.configuration = try container.decodeIfPresent(ContainerConfiguration.self, forKey: .configuration)
        self.status = try container.decodeIfPresent(ContainerStatusOutput.self, forKey: .status)
    }

    enum CodingKeys: String, CodingKey {
        case id, configuration, status
    }
}

struct ContainerConfiguration: Decodable, Sendable {
    let creationDate: String?
    let image: CLIJsonImage?
    let platform: CLIJsonPlatform?
    let publishedPorts: [CLIJsonPort]?

    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.creationDate = try container.decodeIfPresent(String.self, forKey: .creationDate)
        self.image = try container.decodeIfPresent(CLIJsonImage.self, forKey: .image)
        self.platform = try container.decodeIfPresent(CLIJsonPlatform.self, forKey: .platform)
        self.publishedPorts = try container.decodeIfPresent([CLIJsonPort].self, forKey: .publishedPorts)
    }

    enum CodingKeys: String, CodingKey {
        case creationDate, image, platform, publishedPorts
    }
}

struct ContainerStatusOutput: Decodable, Sendable {
    let state: String?
    let startedDate: String?
    let networks: [ContainerNetworkInfo]?

    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.state = try container.decodeIfPresent(String.self, forKey: .state)
        self.startedDate = try container.decodeIfPresent(String.self, forKey: .startedDate)
        self.networks = try container.decodeIfPresent([ContainerNetworkInfo].self, forKey: .networks)
    }

    enum CodingKeys: String, CodingKey {
        case state, startedDate, networks
    }
}

struct ContainerNetworkInfo: Decodable, Sendable {
    let network: String?
    let ipv4Address: String?
    let ipv4Gateway: String?
    let macAddress: String?

    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.network = try container.decodeIfPresent(String.self, forKey: .network)
        self.ipv4Address = try container.decodeIfPresent(String.self, forKey: .ipv4Address)
        self.ipv4Gateway = try container.decodeIfPresent(String.self, forKey: .ipv4Gateway)
        self.macAddress = try container.decodeIfPresent(String.self, forKey: .macAddress)
    }

    enum CodingKeys: String, CodingKey {
        case network, ipv4Address, ipv4Gateway, macAddress
    }
}

struct CLIJsonImage: Decodable, Sendable {
    let reference: String?

    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.reference = try container.decodeIfPresent(String.self, forKey: .reference)
    }

    enum CodingKeys: String, CodingKey {
        case reference
    }
}

struct CLIJsonPlatform: Decodable, Sendable {
    let architecture: String?
    let os: String?

    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.architecture = try container.decodeIfPresent(String.self, forKey: .architecture)
        self.os = try container.decodeIfPresent(String.self, forKey: .os)
    }

    enum CodingKeys: String, CodingKey {
        case architecture, os
    }
}

struct CLIJsonPort: Decodable, Sendable {
    let hostPort: Int?
    let containerPort: Int?
    let protocolType: String?

    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.hostPort = try container.decodeIfPresent(Int.self, forKey: .hostPort)
        self.containerPort = try container.decodeIfPresent(Int.self, forKey: .containerPort)
        self.protocolType = try container.decodeIfPresent(String.self, forKey: .protocolType)
    }

    enum CodingKeys: String, CodingKey {
        case hostPort, containerPort
        case protocolType = "protocol"
    }
}

// MARK: - Image

struct ImageListOutput: Decodable, Sendable {
    let id: String?
    let configuration: ImageConfiguration?
    let variants: [ImageListVariant]?

    enum CodingKeys: String, CodingKey {
        case id
        case configuration
        case variants
    }

    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(String.self, forKey: .id)
        self.configuration = try container.decodeIfPresent(ImageConfiguration.self, forKey: .configuration)
        self.variants = try container.decodeIfPresent([ImageListVariant].self, forKey: .variants)
    }

    struct ImageListVariant: Decodable, Sendable {
        let size: Int64?
        let platform: ImageListPlatform?

        struct ImageListPlatform: Decodable, Sendable {
            let architecture: String?
            let os: String?
        }
    }

    struct ImageConfiguration: Decodable, Sendable {
        let name: String?
        let creationDate: String?
        let descriptor: ImageDescriptor?

        enum CodingKeys: String, CodingKey {
            case name
            case creationDate
            case descriptor
        }

        nonisolated init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.name = try container.decodeIfPresent(String.self, forKey: .name)
            self.creationDate = try container.decodeIfPresent(String.self, forKey: .creationDate)
            self.descriptor = try container.decodeIfPresent(ImageDescriptor.self, forKey: .descriptor)
        }
    }

    struct ImageDescriptor: Decodable, Sendable {
        let size: Int64?

        enum CodingKeys: String, CodingKey {
            case size
        }

        nonisolated init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.size = try container.decodeIfPresent(Int64.self, forKey: .size)
        }
    }

    nonisolated var repository: String? {
        guard let name = configuration?.name else { return nil }
        // Strip registry prefix (everything before first /) and optional library/
        // docker.io/library/nginx:latest   → nginx
        // docker.io/arm64v8/alpine:latest  → arm64v8/alpine
        let path = name
            .split(separator: "/", maxSplits: 1)
            .dropFirst()
            .joined(separator: "/")
            .replacingOccurrences(of: "^library/", with: "", options: .regularExpression)
        // Now split on : for tag
        let parts = path.split(separator: ":", maxSplits: 1)
        return parts.first.map(String.init)
    }

    nonisolated var tag: String? {
        guard let name = configuration?.name else { return nil }
        let path = name
            .split(separator: "/", maxSplits: 1)
            .dropFirst()
            .joined(separator: "/")
            .replacingOccurrences(of: "^library/", with: "", options: .regularExpression)
        let parts = path.split(separator: ":", maxSplits: 1)
        return parts.dropFirst().first.map(String.init)
    }

    nonisolated var size: Int64? {
        // The manifest descriptor size is always small (just the manifest).
        // Real image size is in variants[].size — pick the first non-unknown variant.
        if let variants {
            let main = variants.first(where: { $0.platform?.architecture?.lowercased() != "unknown" })
                ?? variants.first
            if let s = main?.size, s > 0 { return s }
        }
        return configuration?.descriptor?.size
    }

    nonisolated var created: String? {
        configuration?.creationDate
    }
}

// MARK: - Volume
//
// CLI output (JSON) format:
//   [{
//     "id": "my-data",
//     "configuration": {
//       "name": "my-data",
//       "driver": "local",
//       "source": "/path/to/volume.img",
//       "labels": {},
//       "creationDate": "2026-06-12T23:28:15Z",
//       "format": "ext4",
//       "options": {},
//       "sizeInBytes": 549755813888
//     }
//   }]

struct VolumeListOutput: Decodable, Sendable {
    let id: String?
    let configuration: VolumeConfiguration?

    struct VolumeConfiguration: Decodable, Sendable {
        let name: String?
        let driver: String?
        let source: String?
        let labels: [String: String]?
        let scope: String?
        let created: String?
        let sizeInBytes: Int64?
        let format: String?
        let options: [String: String]?

        enum CodingKeys: String, CodingKey {
            case name
            case driver
            case source
            case labels
            case scope
            case created = "creationDate"
            case sizeInBytes
            case format
            case options
        }

        nonisolated init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.name = try container.decodeIfPresent(String.self, forKey: .name)
            self.driver = try container.decodeIfPresent(String.self, forKey: .driver)
            self.source = try container.decodeIfPresent(String.self, forKey: .source)
            self.labels = try container.decodeIfPresent([String: String].self, forKey: .labels)
            self.scope = try container.decodeIfPresent(String.self, forKey: .scope)
            self.created = try container.decodeIfPresent(String.self, forKey: .created)
            self.sizeInBytes = try container.decodeIfPresent(Int64.self, forKey: .sizeInBytes)
            self.format = try container.decodeIfPresent(String.self, forKey: .format)
            self.options = try container.decodeIfPresent([String: String].self, forKey: .options)
        }
    }

    enum CodingKeys: String, CodingKey {
        case id
        case configuration
    }

    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(String.self, forKey: .id)
        self.configuration = try container.decodeIfPresent(VolumeConfiguration.self, forKey: .configuration)
    }
}

// MARK: - Machine
//
// CLI output (JSON) format:
//   [{
//     "id": "test-vm",
//     "default": true,
//     "diskSize": 78725120,
//     "createdDate": "...",
//     "status": "stopped",
//     "cpus": 5,
//     "memory": 12884901888
//   }]
//
// Inspect adds: homeMount, image, platform, userSetup

struct MachineListOutput: Decodable, Sendable {
    let id: String?
    let status: String?
    let cpus: Int?
    let memory: Int64?
    let diskSize: Int64?
    let runningSince: String?
    let createdDate: String?
    let isDefault: Bool?
    let homeMount: String?

    enum CodingKeys: String, CodingKey {
        case id
        case status
        case cpus
        case memory
        case diskSize
        case runningSince
        case createdDate
        case isDefault = "default"
        case homeMount
    }

    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(String.self, forKey: .id)
        self.status = try container.decodeIfPresent(String.self, forKey: .status)
        self.cpus = try container.decodeIfPresent(Int.self, forKey: .cpus)
        self.memory = try container.decodeIfPresent(Int64.self, forKey: .memory)
        self.diskSize = try container.decodeIfPresent(Int64.self, forKey: .diskSize)
        self.runningSince = try container.decodeIfPresent(String.self, forKey: .runningSince)
        self.createdDate = try container.decodeIfPresent(String.self, forKey: .createdDate)
        self.isDefault = try container.decodeIfPresent(Bool.self, forKey: .isDefault)
        self.homeMount = try container.decodeIfPresent(String.self, forKey: .homeMount)
    }
}

// MARK: - Network
//
// CLI output (JSON) format:
//   [{
//     "id": "default",
//     "configuration": {
//       "name": "default",
//       "creationDate": "...",
//       "labels": {...},
//       "mode": "nat",
//       "plugin": "container-network-vmnet",
//       "options": {...}
//     },
//     "status": {
//       "ipv4Gateway": "192.168.64.1",
//       "ipv4Subnet": "192.168.64.0/24",
//       "ipv6Subnet": "fd38:64dc:b654:b7c6::/64"
//     }
//   }]

struct NetworkListOutput: Decodable, Sendable {
    let id: String?
    let configuration: NetworkConfiguration?
    let status: NetworkStatus?

    struct NetworkConfiguration: Decodable, Sendable {
        let name: String?
        let creationDate: String?
        let labels: [String: String]?
        let mode: String?
        let plugin: String?
        let options: [String: String]?

        enum CodingKeys: String, CodingKey {
            case name
            case creationDate
            case labels
            case mode
            case plugin
            case options
        }

        nonisolated init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.name = try container.decodeIfPresent(String.self, forKey: .name)
            self.creationDate = try container.decodeIfPresent(String.self, forKey: .creationDate)
            self.labels = try container.decodeIfPresent([String: String].self, forKey: .labels)
            self.mode = try container.decodeIfPresent(String.self, forKey: .mode)
            self.plugin = try container.decodeIfPresent(String.self, forKey: .plugin)
            self.options = try container.decodeIfPresent([String: String].self, forKey: .options)
        }
    }

    struct NetworkStatus: Decodable, Sendable {
        let ipv4Gateway: String?
        let ipv4Subnet: String?
        let ipv6Subnet: String?

        enum CodingKeys: String, CodingKey {
            case ipv4Gateway
            case ipv4Subnet
            case ipv6Subnet
        }

        nonisolated init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.ipv4Gateway = try container.decodeIfPresent(String.self, forKey: .ipv4Gateway)
            self.ipv4Subnet = try container.decodeIfPresent(String.self, forKey: .ipv4Subnet)
            self.ipv6Subnet = try container.decodeIfPresent(String.self, forKey: .ipv6Subnet)
        }
    }

    enum CodingKeys: String, CodingKey {
        case id
        case configuration
        case status
    }

    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(String.self, forKey: .id)
        self.configuration = try container.decodeIfPresent(NetworkConfiguration.self, forKey: .configuration)
        self.status = try container.decodeIfPresent(NetworkStatus.self, forKey: .status)
    }
}

// MARK: - Stats

struct StatsOutput: Decodable, Sendable {
    let containerId: String?
    let name: String?
    let cpuPercent: Double?
    let memoryUsage: Int64?
    let memoryLimit: Int64?
    let networkRx: Int64?
    let networkTx: Int64?
    let blockRead: Int64?
    let blockWrite: Int64?
    let pids: Int?

    enum CodingKeys: String, CodingKey {
        case containerId = "ContainerID"
        case name = "Name"
        case cpuPercent = "CPUPercent"
        case memoryUsage = "MemUsage"
        case memoryLimit = "MemLimit"
        case networkRx = "NetRx"
        case networkTx = "NetTx"
        case blockRead = "BlockRead"
        case blockWrite = "BlockWrite"
        case pids = "Pids"
    }

    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.containerId = try container.decodeIfPresent(String.self, forKey: .containerId)
        self.name = try container.decodeIfPresent(String.self, forKey: .name)
        self.cpuPercent = try container.decodeIfPresent(Double.self, forKey: .cpuPercent)
        self.memoryUsage = try container.decodeIfPresent(Int64.self, forKey: .memoryUsage)
        self.memoryLimit = try container.decodeIfPresent(Int64.self, forKey: .memoryLimit)
        self.networkRx = try container.decodeIfPresent(Int64.self, forKey: .networkRx)
        self.networkTx = try container.decodeIfPresent(Int64.self, forKey: .networkTx)
        self.blockRead = try container.decodeIfPresent(Int64.self, forKey: .blockRead)
        self.blockWrite = try container.decodeIfPresent(Int64.self, forKey: .blockWrite)
        self.pids = try container.decodeIfPresent(Int.self, forKey: .pids)
    }
}

// MARK: - System

struct SystemInfoOutput: Decodable, Sendable {
    let containers: Int?
    let running: Int?
    let paused: Int?
    let stopped: Int?
    let images: Int?
    let volumes: Int?
    let networks: Int?
    let serverVersion: String?
    let osType: String?
    let architecture: String?
    let cpus: Int?
    let totalMemory: Int64?

    enum CodingKeys: String, CodingKey {
        case containers = "Containers"
        case running = "ContainersRunning"
        case paused = "ContainersPaused"
        case stopped = "ContainersStopped"
        case images = "Images"
        case volumes = "Volumes"
        case networks = "Networks"
        case serverVersion = "ServerVersion"
        case osType = "OSType"
        case architecture = "Architecture"
        case cpus = "NCPU"
        case totalMemory = "MemTotal"
    }
}
