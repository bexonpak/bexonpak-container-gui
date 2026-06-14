import Foundation

public protocol MachineRepositoryProtocol: Sendable {
    func listMachines() async throws -> [Machine]
    func inspectMachine(name: String) async throws -> Machine
    func startMachine(name: String) async throws
    func stopMachine(name: String) async throws
    func removeMachine(name: String) async throws
    func createMachine(options: MachineCreateOptions) async throws -> String
    func setMachineSetting(setting: MachineSetting) async throws
    func setDefaultMachine(name: String) async throws
}
