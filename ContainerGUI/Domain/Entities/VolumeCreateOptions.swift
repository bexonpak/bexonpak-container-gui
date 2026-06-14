import Foundation

/// Encapsulates options for the `container volume create` command.
///
/// According to the CLI reference:
/// ```
/// container volume create <name>
///   --label <label>       Set a label (key=value, repeatable)
///   --opt <opt>           Driver-specific options (key=value, repeatable)
///   -s <s>                Volume size (K/M/G/T/P suffix)
/// ```
///
/// Note: The `container` CLI does **not** support modifying volumes after creation.
/// For "modify", the pattern is to delete and recreate.
public struct VolumeCreateOptions: Sendable, Equatable {
    public let name: String
    public let labels: [String: String]
    public let driverOpts: [String: String]
    public let size: String?

    public nonisolated init(
        name: String,
        labels: [String: String] = [:],
        driverOpts: [String: String] = [:],
        size: String? = nil
    ) {
        self.name = name
        self.labels = labels
        self.driverOpts = driverOpts
        self.size = size
    }

    /// Builds the CLI argument list for `container volume create`.
    public nonisolated func buildArguments() -> [String] {
        var args: [String] = ["volume", "create"]

        // Labels
        for (key, value) in labels.sorted(by: { $0.key < $1.key }) {
            args += ["--label", "\(key)=\(value)"]
        }

        // Driver-specific options
        for (key, value) in driverOpts.sorted(by: { $0.key < $1.key }) {
            args += ["--opt", "\(key)=\(value)"]
        }

        // Size
        if let size { args += ["-s", size] }

        // Name
        args.append(name)

        return args
    }
}
