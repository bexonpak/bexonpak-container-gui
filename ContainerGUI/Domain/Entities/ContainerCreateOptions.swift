import Foundation

/// Encapsulates all options for the `container create` command.
/// `container create` accepts the same flags as `container run`.
public struct ContainerCreateOptions: Sendable, Equatable {
    // MARK: - Required
    public let image: String
    public let command: [String]

    // MARK: - Identification
    public let name: String?

    // MARK: - Process
    public let env: [String: String]
    public let envFile: String?
    public let user: String?
    public let uid: Int?
    public let gid: Int?
    public let workdir: String?
    public let entrypoint: String?
    public let interactive: Bool
    public let tty: Bool
    public let ulimit: [String]

    // MARK: - Resources
    public let cpus: Int?
    public let memory: String?

    // MARK: - Storage
    public let volume: [String]
    public let mount: [String]
    public let tmpfs: [String]
    public let readOnly: Bool
    public let shmSize: String?

    // MARK: - Network
    public let network: String?
    public let publish: [PortPublishSpec]
    public let publishSocket: [String]
    public let dns: [String]
    public let dnsSearch: [String]
    public let dnsOption: [String]
    public let dnsDomain: String?
    public let noDns: Bool

    // MARK: - Platform
    public let platform: String?
    public let arch: String?
    public let os: String?

    // MARK: - Security & Capabilities
    public let capAdd: [String]
    public let capDrop: [String]
    public let initProcess: Bool
    public let initImage: String?
    public let rosetta: Bool
    public let virtualization: Bool
    public let ssh: Bool
    public let runtime: String?

    // MARK: - Labels & Metadata
    public let labels: [String: String]
    public let cidfile: String?

    // MARK: - Lifecycle
    public let rm: Bool

    // MARK: - Machine
    public let machine: String?

    // MARK: - Registry
    public let scheme: String?

    // MARK: - Kernel
    public let kernel: String?

    public nonisolated init(
        image: String,
        command: [String] = [],
        name: String? = nil,
        env: [String: String] = [:],
        envFile: String? = nil,
        user: String? = nil,
        uid: Int? = nil,
        gid: Int? = nil,
        workdir: String? = nil,
        entrypoint: String? = nil,
        interactive: Bool = false,
        tty: Bool = false,
        ulimit: [String] = [],
        cpus: Int? = nil,
        memory: String? = nil,
        volume: [String] = [],
        mount: [String] = [],
        tmpfs: [String] = [],
        readOnly: Bool = false,
        shmSize: String? = nil,
        network: String? = nil,
        publish: [PortPublishSpec] = [],
        publishSocket: [String] = [],
        dns: [String] = [],
        dnsSearch: [String] = [],
        dnsOption: [String] = [],
        dnsDomain: String? = nil,
        noDns: Bool = false,
        platform: String? = nil,
        arch: String? = nil,
        os: String? = nil,
        capAdd: [String] = [],
        capDrop: [String] = [],
        initProcess: Bool = false,
        initImage: String? = nil,
        rosetta: Bool = false,
        virtualization: Bool = false,
        ssh: Bool = false,
        runtime: String? = nil,
        machine: String? = nil,
        labels: [String: String] = [:],
        cidfile: String? = nil,
        rm: Bool = false,
        scheme: String? = nil,
        kernel: String? = nil
    ) {
        self.image = image
        self.command = command
        self.name = name
        self.env = env
        self.envFile = envFile
        self.user = user
        self.uid = uid
        self.gid = gid
        self.workdir = workdir
        self.entrypoint = entrypoint
        self.interactive = interactive
        self.tty = tty
        self.ulimit = ulimit
        self.cpus = cpus
        self.memory = memory
        self.volume = volume
        self.mount = mount
        self.tmpfs = tmpfs
        self.readOnly = readOnly
        self.shmSize = shmSize
        self.network = network
        self.publish = publish
        self.publishSocket = publishSocket
        self.dns = dns
        self.dnsSearch = dnsSearch
        self.dnsOption = dnsOption
        self.dnsDomain = dnsDomain
        self.noDns = noDns
        self.platform = platform
        self.arch = arch
        self.os = os
        self.capAdd = capAdd
        self.capDrop = capDrop
        self.initProcess = initProcess
        self.initImage = initImage
        self.rosetta = rosetta
        self.virtualization = virtualization
        self.ssh = ssh
        self.runtime = runtime
        self.machine = machine
        self.labels = labels
        self.cidfile = cidfile
        self.rm = rm
        self.scheme = scheme
        self.kernel = kernel
    }

    /// Builds the CLI argument list for `container create`.
    /// Each flag is added only when the corresponding option differs from its default.
    public nonisolated func buildArguments() -> [String] {
        var args: [String] = ["create"]

        // Identification
        if let name { args += ["--name", name] }

        // Process
        for (key, value) in env.sorted(by: { $0.key < $1.key }) {
            args += ["--env", "\(key)=\(value)"]
        }
        if let envFile { args += ["--env-file", envFile] }
        if let user { args += ["--user", user] }
        if let uid { args += ["--uid", String(uid)] }
        if let gid { args += ["--gid", String(gid)] }
        if let workdir { args += ["--workdir", workdir] }
        if let entrypoint { args += ["--entrypoint", entrypoint] }
        if interactive { args.append("--interactive") }
        if tty { args.append("--tty") }
        for limit in ulimit { args += ["--ulimit", limit] }

        // Resources
        if let cpus { args += ["--cpus", String(cpus)] }
        if let memory { args += ["--memory", memory] }

        // Storage
        for v in volume { args += ["--volume", v] }
        for m in mount { args += ["--mount", m] }
        for t in tmpfs { args += ["--tmpfs", t] }
        if readOnly { args.append("--read-only") }
        if let shmSize { args += ["--shm-size", shmSize] }

        // Network
        if let network { args += ["--network", network] }
        for p in publish { args += ["--publish", p.specString] }
        for ps in publishSocket { args += ["--publish-socket", ps] }
        for server in dns { args += ["--dns", server] }
        for search in dnsSearch { args += ["--dns-search", search] }
        for opt in dnsOption { args += ["--dns-option", opt] }
        if let dnsDomain { args += ["--dns-domain", dnsDomain] }
        if noDns { args.append("--no-dns") }

        // Platform
        if let platform { args += ["--platform", platform] }
        if let arch { args += ["--arch", arch] }
        if let os { args += ["--os", os] }

        // Security & Capabilities
        for cap in capAdd { args += ["--cap-add", cap] }
        for cap in capDrop { args += ["--cap-drop", cap] }
        if initProcess { args.append("--init") }
        if let initImage { args += ["--init-image", initImage] }
        if rosetta { args.append("--rosetta") }
        if virtualization { args.append("--virtualization") }
        if ssh { args.append("--ssh") }
        if let runtime { args += ["--runtime", runtime] }
        if let machine { args += ["--machine", machine] }

        // Labels
        for (key, value) in labels.sorted(by: { $0.key < $1.key }) {
            args += ["--label", "\(key)=\(value)"]
        }
        if let cidfile { args += ["--cidfile", cidfile] }

        // Lifecycle
        if rm { args.append("--rm") }

        // Registry
        if let scheme { args += ["--scheme", scheme] }

        // Kernel
        if let kernel { args += ["--kernel", kernel] }

        // Image (required)
        args.append(image)
        args += command

        return args
    }
}

/// A port publishing specification: `hostPort:containerPort[/protocol]`
public struct PortPublishSpec: Sendable, Equatable, Identifiable, Hashable {
    public let hostPort: Int
    public let containerPort: Int
    public let hostIP: String?
    public let `protocol`: String?

    public nonisolated init(hostPort: Int, containerPort: Int, hostIP: String? = nil, protocol: String? = nil) {
        self.hostPort = hostPort
        self.containerPort = containerPort
        self.hostIP = hostIP
        self.protocol = `protocol`
    }

    public var id: String { specString }

    /// Format: `[host-ip:]host-port:container-port[/protocol]`
    public nonisolated var specString: String {
        let portPart = "\(hostPort):\(containerPort)"
        let ipPart = hostIP.map { "\($0):" } ?? ""
        let protoPart = `protocol`.map { "/\($0)" } ?? ""
        return "\(ipPart)\(portPart)\(protoPart)"
    }
}
