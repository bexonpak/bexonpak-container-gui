import Foundation

public actor MachineRepository: MachineRepositoryProtocol {
    private let cli: CLIExecutor

    public init(cli: CLIExecutor) {
        self.cli = cli
    }

    public func listMachines() async throws -> [Machine] {
        let output: [MachineListOutput] = try await cli.runJSON([MachineListOutput].self, arguments: ["machine", "list", "--format", "json"])
        return output.compactMap { mapToDomain($0) }
    }

    public func inspectMachine(name: String) async throws -> Machine {
        let output: [MachineListOutput] = try await cli.runJSON([MachineListOutput].self, arguments: ["machine", "inspect", name])
        guard let first = output.first, let machine = mapToDomain(first) else {
            throw CLIError.invalidOutput("Failed to parse machine: \(name)")
        }
        return machine
    }

    public func startMachine(name: String) async throws {
        _ = try await cli.run(arguments: ["machine", "start", name])
    }

    public func stopMachine(name: String) async throws {
        _ = try await cli.run(arguments: ["machine", "stop", name])
    }

    public func removeMachine(name: String) async throws {
        _ = try await cli.run(arguments: ["machine", "rm", name])
    }

    public func createMachine(options: MachineCreateOptions) async throws -> String {
        let args = options.buildCreateArguments()
        return try await cli.run(arguments: args)
    }

    public func setMachineSetting(setting: MachineSetting) async throws {
        let args = setting.buildArguments()
        _ = try await cli.run(arguments: args)
    }

    public func setDefaultMachine(name: String) async throws {
        _ = try await cli.run(arguments: ["machine", "set-default", name])
    }

    // MARK: - Mapping

    private func mapToDomain(_ output: MachineListOutput) -> Machine? {
        guard let name = output.id else { return nil }
        return Machine(
            name: name,
            status: parseStatus(output.status),
            cpus: output.cpus ?? 0,
            memory: output.memory ?? 0,
            diskSize: output.diskSize ?? 0,
            vmDirectory: "",
            runningSince: parseDate(output.runningSince)
        )
    }

    private func parseStatus(_ raw: String?) -> MachineStatus {
        guard let raw else { return .unknown("") }
        let lower = raw.lowercased()
        if lower == "running" { return .running }
        if lower == "stopped" { return .stopped }
        if lower == "starting" { return .starting }
        if lower == "stopping" { return .stopping }
        return .unknown(raw)
    }

    private func parseDate(_ raw: String?) -> Date? {
        guard let raw else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: raw) ?? ISO8601DateFormatter().date(from: raw)
    }
}
