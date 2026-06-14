import Foundation

public struct ContainerImage: Identifiable, Sendable, Equatable, Hashable {
    public let id: String
    public let repository: String
    public let tag: String
    public let size: Int64
    public let created: Date
    /// Original full name from registry, e.g. "docker.io/library/nginx:latest"
    public let fullName: String

    public nonisolated init(id: String, repository: String, tag: String, size: Int64, created: Date, fullName: String = "") {
        self.id = id
        self.repository = repository
        self.tag = tag
        self.size = size
        self.created = created
        self.fullName = fullName
    }

    public var displaySize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }

    /// Reference string for CLI operations (e.g. "arm64v8/alpine:latest").
    public var reference: String {
        tag == "<none>" ? repository : "\(repository):\(tag)"
    }

    /// Registry URL for browsing this image.
    public var registryURL: URL? {
        guard !fullName.isEmpty else { return nil }
        let parts = fullName.split(separator: "/", maxSplits: 1)
        guard parts.count == 2 else { return nil }
        let registry = String(parts[0])
        let path = parts[1].split(separator: ":").dropLast().joined(separator: ":")

        switch registry {
        case "docker.io":
            if path.hasPrefix("library/") {
                let name = String(path.dropFirst("library/".count))
                return URL(string: "https://hub.docker.com/_/\(name)")
            }
            return URL(string: "https://hub.docker.com/r/\(path)")
        case "ghcr.io":
            return URL(string: "https://github.com/orgs/\(path)/packages")
        default:
            return URL(string: "https://\(registry)/\(path)")
        }
    }
}

public struct ImageBuildLog: Sendable, Equatable {
    public let step: String
    public let message: String
}
