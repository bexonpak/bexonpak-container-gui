import Foundation

public struct Volume: Identifiable, Sendable, Equatable, Hashable {
    public let name: String
    public let driver: String
    public let mountPoint: String
    public let labels: [String: String]
    public let scope: String
    public let created: Date?
    public let size: Int64?

    public var id: String { name }

    public nonisolated init(
        name: String,
        driver: String,
        mountPoint: String,
        labels: [String: String],
        scope: String,
        created: Date?,
        size: Int64? = nil
    ) {
        self.name = name
        self.driver = driver
        self.mountPoint = mountPoint
        self.labels = labels
        self.scope = scope
        self.created = created
        self.size = size
    }
}
