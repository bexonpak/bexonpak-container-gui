import Foundation

/// Encapsulates options for the `container build` command.
public struct ImageBuildOptions: Sendable, Equatable {
    public let contextDir: String
    public let dockerfile: String?
    public let tags: [String]
    public let buildArgs: [String: String]
    public let labels: [String: String]
    public let noCache: Bool
    public let pull: Bool
    public let target: String?
    public let platform: String?
    public let arch: String?
    public let os: String?
    public let cpus: Int?
    public let memory: String?
    public let secrets: [String]
    public let output: String?
    public let quiet: Bool

    public nonisolated init(
        contextDir: String,
        dockerfile: String? = nil,
        tags: [String] = [],
        buildArgs: [String: String] = [:],
        labels: [String: String] = [:],
        noCache: Bool = false,
        pull: Bool = false,
        target: String? = nil,
        platform: String? = nil,
        arch: String? = nil,
        os: String? = nil,
        cpus: Int? = nil,
        memory: String? = nil,
        secrets: [String] = [],
        output: String? = nil,
        quiet: Bool = false
    ) {
        self.contextDir = contextDir
        self.dockerfile = dockerfile
        self.tags = tags
        self.buildArgs = buildArgs
        self.labels = labels
        self.noCache = noCache
        self.pull = pull
        self.target = target
        self.platform = platform
        self.arch = arch
        self.os = os
        self.cpus = cpus
        self.memory = memory
        self.secrets = secrets
        self.output = output
        self.quiet = quiet
    }

    /// Builds the CLI argument list for `container build`.
    public nonisolated func buildArguments() -> [String] {
        var args: [String] = ["build"]

        if let dockerfile { args += ["--file", dockerfile] }
        for tag in tags { args += ["--tag", tag] }
        for (key, value) in buildArgs.sorted(by: { $0.key < $1.key }) {
            args += ["--build-arg", "\(key)=\(value)"]
        }
        for (key, value) in labels.sorted(by: { $0.key < $1.key }) {
            args += ["--label", "\(key)=\(value)"]
        }
        if noCache { args.append("--no-cache") }
        if pull { args.append("--pull") }
        if let target { args += ["--target", target] }
        if let platform { args += ["--platform", platform] }
        if let arch { args += ["--arch", arch] }
        if let os { args += ["--os", os] }
        if let cpus { args += ["--cpus", String(cpus)] }
        if let memory { args += ["--memory", memory] }
        for secret in secrets { args += ["--secret", secret] }
        if let output { args += ["--output", output] }
        if quiet { args.append("--quiet") }

        args.append(contextDir)
        return args
    }
}

/// Builder status returned by `container builder status --format json`.
public struct BuilderStatus: Sendable, Equatable, Identifiable {
    public let id: String
    public let state: String
    public let cpus: Int
    public let memory: Int64
    public let startedDate: Date?
    public let imageRef: String

    public nonisolated init(id: String, state: String, cpus: Int, memory: Int64, startedDate: Date?, imageRef: String) {
        self.id = id
        self.state = state
        self.cpus = cpus
        self.memory = memory
        self.startedDate = startedDate
        self.imageRef = imageRef
    }

    public var isRunning: Bool { state.lowercased() == "running" }
}
