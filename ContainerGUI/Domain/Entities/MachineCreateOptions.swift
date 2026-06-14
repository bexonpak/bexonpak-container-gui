import Foundation

/// Encapsulates options for `container machine create` and `container machine set`.
///
/// Create CLI reference:
/// ```
/// container machine create <image>
///   --name <name>              Name for the machine
///   --set-default              Set as default machine
///   --no-boot                  Create without booting
///   --cpus <cpus>              Virtual CPUs
///   --memory <memory>          Memory allocation
///   --home-mount <opt>         Home mount option (ro|rw|none)
///   --arch <arch>              Architecture (default: host)
///   --os <os>                  OS (default: linux)
///   --platform <platform>      Platform override
///   --scheme <scheme>          Registry scheme
///   --progress <type>          Progress type
///   --max-concurrent-downloads Max concurrent downloads
/// ```
///
/// Set reference:
/// ```
/// container machine set <setting>
///   settings: cpus=<number>, memory=<size>, home-mount=<string>
///   --name <name> (-n)
/// ```
public struct MachineCreateOptions: Sendable, Equatable {
    public let image: String
    public let name: String?
    public let setDefault: Bool
    public let noBoot: Bool
    public let cpus: Int?
    public let memory: String?
    public let homeMount: String?
    public let arch: String?
    public let os: String?
    public let platform: String?
    public let scheme: String?
    public let maxConcurrentDownloads: Int?

    public nonisolated init(
        image: String,
        name: String? = nil,
        setDefault: Bool = false,
        noBoot: Bool = false,
        cpus: Int? = nil,
        memory: String? = nil,
        homeMount: String? = nil,
        arch: String? = nil,
        os: String? = nil,
        platform: String? = nil,
        scheme: String? = nil,
        maxConcurrentDownloads: Int? = nil
    ) {
        self.image = image
        self.name = name
        self.setDefault = setDefault
        self.noBoot = noBoot
        self.cpus = cpus
        self.memory = memory
        self.homeMount = homeMount
        self.arch = arch
        self.os = os
        self.platform = platform
        self.scheme = scheme
        self.maxConcurrentDownloads = maxConcurrentDownloads
    }

    /// Builds argument list for `container machine create`.
    public nonisolated func buildCreateArguments() -> [String] {
        var args: [String] = ["machine", "create"]

        if let name { args += ["--name", name] }
        if setDefault { args.append("--set-default") }
        if noBoot { args.append("--no-boot") }
        if let cpus { args += ["--cpus", String(cpus)] }
        if let memory { args += ["--memory", memory] }
        if let homeMount { args += ["--home-mount", homeMount] }
        if let arch { args += ["--arch", arch] }
        if let os { args += ["--os", os] }
        if let platform { args += ["--platform", platform] }
        if let scheme { args += ["--scheme", scheme] }
        if let maxConcurrentDownloads { args += ["--max-concurrent-downloads", String(maxConcurrentDownloads)] }

        args.append(image)
        return args
    }
}

/// Represents a setting change for `container machine set`.
public struct MachineSetting: Sendable, Equatable {
    public enum Setting: Sendable, Equatable, Identifiable {
        case cpus(Int)
        case memory(String)
        case homeMount(String)

        public nonisolated var id: String {
            switch self {
            case .cpus: return "cpus"
            case .memory: return "memory"
            case .homeMount: return "home-mount"
            }
        }

        public nonisolated var key: String {
            switch self {
            case .cpus: return "cpus"
            case .memory: return "memory"
            case .homeMount: return "home-mount"
            }
        }

        public nonisolated var value: String {
            switch self {
            case .cpus(let v): return String(v)
            case .memory(let v): return v
            case .homeMount(let v): return v
            }
        }
    }

    public let setting: Setting
    public let machineName: String?

    public nonisolated init(setting: Setting, machineName: String? = nil) {
        self.setting = setting
        self.machineName = machineName
    }

    /// Builds argument list for `container machine set`.
    public nonisolated func buildArguments() -> [String] {
        var args: [String] = ["machine", "set"]
        if let machineName { args += ["--name", machineName] }
        args.append("\(setting.key)=\(setting.value)")
        return args
    }
}
