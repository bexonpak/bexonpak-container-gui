import Foundation

/// Encapsulates options for the `container network create` command.
///
/// CLI reference:
/// ```
/// container network create <name>
///   --internal             Internal network (no external access)
///   --label <label>        Set a label (key=value, repeatable)
///   --option <option>      Network option (key=value, repeatable)
///   --plugin <plugin>      Network plugin (default: container-network-vmnet)
///   --subnet <subnet>      Subnet in CIDR notation
///   --subnet-v6 <subnet>   IPv6 subnet in CIDR notation
/// ```
///
/// Note: The `container` CLI does **not** support modifying networks after creation.
/// For "modify", the pattern is to delete and recreate.
public struct NetworkCreateOptions: Sendable, Equatable {
    public let name: String
    public let internalNetwork: Bool
    public let labels: [String: String]
    public let options: [String: String]
    public let plugin: String?
    public let subnet: String?
    public let subnetV6: String?

    public nonisolated init(
        name: String,
        internalNetwork: Bool = false,
        labels: [String: String] = [:],
        options: [String: String] = [:],
        plugin: String? = nil,
        subnet: String? = nil,
        subnetV6: String? = nil
    ) {
        self.name = name
        self.internalNetwork = internalNetwork
        self.labels = labels
        self.options = options
        self.plugin = plugin
        self.subnet = subnet
        self.subnetV6 = subnetV6
    }

    /// Builds the CLI argument list for `container network create`.
    public nonisolated func buildArguments() -> [String] {
        var args: [String] = ["network", "create"]

        if internalNetwork { args.append("--internal") }

        for (key, value) in labels.sorted(by: { $0.key < $1.key }) {
            args += ["--label", "\(key)=\(value)"]
        }

        for (key, value) in options.sorted(by: { $0.key < $1.key }) {
            args += ["--option", "\(key)=\(value)"]
        }

        if let plugin { args += ["--plugin", plugin] }
        if let subnet { args += ["--subnet", subnet] }
        if let subnetV6 { args += ["--subnet-v6", subnetV6] }

        args.append(name)

        return args
    }
}
