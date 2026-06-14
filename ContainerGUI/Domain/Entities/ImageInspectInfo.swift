import Foundation

/// Parsed inspect info for a container image.
public struct ImageInspectInfo: Sendable, Equatable {
    public let digest: String
    public let architecture: String
    public let os: String
    public let created: Date?
    public let labels: [String: String]
    public let env: [String]
    public let entrypoint: [String]
    public let cmd: [String]
    public let stopSignal: String?
    public let layers: Int
    public let size: Int64

    public nonisolated init(
        digest: String,
        architecture: String,
        os: String,
        created: Date?,
        labels: [String: String],
        env: [String],
        entrypoint: [String],
        cmd: [String],
        stopSignal: String?,
        layers: Int,
        size: Int64 = 0
    ) {
        self.digest = digest
        self.architecture = architecture
        self.os = os
        self.created = created
        self.labels = labels
        self.env = env
        self.entrypoint = entrypoint
        self.cmd = cmd
        self.stopSignal = stopSignal
        self.layers = layers
        self.size = size
    }
}
