import SwiftUI

// MARK: - Container ViewModel

@MainActor
@Observable
final class ContainerViewModel {
    var state: ViewState<[Container]> = .loading
    var selectedContainer: Container?
    var showAll: Bool = true
    var errorMessage: String?
    var isStarting = false

    // Create container
    var createForm = ContainerCreateFormModel()
    var isCreating = false
    var createErrorMessage: String?
    var showCreateSheet = false

    // Inspect state
    var inspectInfo: ContainerInspectInfo?
    var inspectError: String?
    var isLoadingInspect = false

    // Available images for image picker
    var availableImages: [ContainerImage] = []

    // Available resources for create form
    var availableVolumes: [Volume] = []
    var availableNetworks: [ContainerNetwork] = []
    var availableMachines: [Machine] = []

    private let repository: ContainerRepositoryProtocol
    private let systemRepository: SystemRepositoryProtocol
    private let imageRepository: ImageRepositoryProtocol?
    private let volumeRepository: VolumeRepositoryProtocol?
    private let networkRepository: NetworkRepositoryProtocol?
    private let machineRepository: MachineRepositoryProtocol?

    init(
        repository: ContainerRepositoryProtocol,
        systemRepository: SystemRepositoryProtocol,
        imageRepository: ImageRepositoryProtocol? = nil,
        volumeRepository: VolumeRepositoryProtocol? = nil,
        networkRepository: NetworkRepositoryProtocol? = nil,
        machineRepository: MachineRepositoryProtocol? = nil
    ) {
        self.repository = repository
        self.systemRepository = systemRepository
        self.imageRepository = imageRepository
        self.volumeRepository = volumeRepository
        self.networkRepository = networkRepository
        self.machineRepository = machineRepository
    }

    func load() async {
        state = .loading
        await refresh()
        await loadAvailableResources()
    }

    func refresh() async {
        do {
            let containers = try await repository.listContainers(all: showAll)
            state = containers.isEmpty ? .empty("No containers found") : .loaded(containers)
        } catch {
            state = .error(error.localizedDescription)
            errorMessage = error.localizedDescription
        }
    }

    func loadAvailableResources() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadImages() }
            group.addTask { await self.loadVolumes() }
            group.addTask { await self.loadNetworks() }
            group.addTask { await self.loadMachines() }
        }
    }

    func loadImages() async {
        guard let imageRepository else { return }
        do { availableImages = try await imageRepository.listImages() }
        catch { /* Non-critical */ }
    }

    func loadVolumes() async {
        guard let volumeRepository else { return }
        do { availableVolumes = try await volumeRepository.listVolumes() }
        catch { /* Non-critical */ }
    }

    func loadNetworks() async {
        guard let networkRepository else { return }
        do { availableNetworks = try await networkRepository.listNetworks() }
        catch { /* Non-critical */ }
    }

    func loadMachines() async {
        guard let machineRepository else { return }
        do { availableMachines = try await machineRepository.listMachines() }
        catch { /* Non-critical */ }
    }

    func toggleShowAll() {
        showAll.toggle()
        Task { await refresh() }
    }

    func startServices() async {
        isStarting = true
        do {
            try await systemRepository.startServices()
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
            state = .error(error.localizedDescription)
        }
        isStarting = false
    }

    // MARK: - Create Container

    func openCreateSheet() {
        createForm.reset()
        createErrorMessage = nil
        showCreateSheet = true
        Task { await loadAvailableResources() }
    }

    func createContainer() async {
        guard !createForm.image.trimmingCharacters(in: .whitespaces).isEmpty else {
            createErrorMessage = "Image is required"
            return
        }

        isCreating = true
        createErrorMessage = nil

        do {
            let options = createForm.buildOptions()
            let containerId = try await repository.createContainer(options: options)
            createForm.createdContainerId = containerId
            try? await Task.sleep(for: .seconds(1.5))
            showCreateSheet = false
            await refresh()
        } catch {
            createErrorMessage = error.localizedDescription
        }

        isCreating = false
    }

    /// Direct create without the form — used by recreate from detail view.
    func createContainer(options: ContainerCreateOptions) async throws -> String {
        try await repository.createContainer(options: options)
    }

    /// Direct remove without state management — used by recreate from detail view.
    func removeContainerDirect(id: String) async throws {
        try await repository.removeContainer(id: id, force: true)
    }

    // MARK: - Container Action Loading States

    private(set) var isStartingContainer = false
    private(set) var isStoppingContainer = false
    private(set) var isRestartingContainer = false
    private(set) var isKillingContainer = false

    // MARK: - Container Actions

    func startContainer(_ id: String) async {
        isStartingContainer = true
        defer { isStartingContainer = false }
        do {
            try await repository.startContainer(id: id)
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func stopContainer(_ id: String) async {
        isStoppingContainer = true
        defer { isStoppingContainer = false }
        do {
            try await repository.stopContainer(id: id)
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func restartContainer(_ id: String) async {
        isRestartingContainer = true
        defer { isRestartingContainer = false }
        do {
            try await repository.stopContainer(id: id)
            try await repository.startContainer(id: id)
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func killContainer(_ id: String) async {
        isKillingContainer = true
        defer { isKillingContainer = false }
        do {
            try await repository.killContainer(id: id, signal: nil)
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func removeContainer(_ id: String) async {
        do {
            try await repository.removeContainer(id: id, force: false)
            if selectedContainer?.id == id { selectedContainer = nil }
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Inspect

    func loadInspect(id: String) async {
        isLoadingInspect = true
        inspectInfo = nil
        inspectError = nil
        do {
            inspectInfo = try await repository.inspectContainer(id: id)
        } catch {
            inspectError = error.localizedDescription
        }
        isLoadingInspect = false
    }
}

// MARK: - Create Form Model

@MainActor
@Observable
final class ContainerCreateFormModel {
    // Required
    var image: String = ""
    var command: String = ""

    // Identification
    var name: String = ""

    // Process
    var envVars: [KeyValueEntry] = []
    var user: String = ""
    var workdir: String = ""
    var entrypoint: String = ""
    var interactive: Bool = false
    var tty: Bool = false

    // Resources
    var cpus: Int? = nil
    var memory: String = ""

    // Storage
    var volumeMounts: [VolumeMountEntry] = []
    var readOnly: Bool = false
    var shmSize: String = ""

    // Network
    var network: String = ""
    var portMappings: [PortMappingEntry] = []
    var dnsServers: [String] = []

    // Machine
    var selectedMachine: String = ""

    // Platform
    var platform: String = ""
    var arch: String = ""
    var os: String = ""

    // Lifecycle
    var autoRemove: Bool = false

    // Labels
    var labels: [KeyValueEntry] = []

    // State
    var createdContainerId: String?

    func reset() {
        image = ""
        command = ""
        name = ""
        envVars = []
        user = ""
        workdir = ""
        entrypoint = ""
        interactive = false
        tty = false
        cpus = nil
        memory = ""
        volumeMounts = []
        readOnly = false
        shmSize = ""
        network = ""
        portMappings = []
        dnsServers = []
        selectedMachine = ""
        platform = ""
        arch = ""
        os = ""
        autoRemove = false
        labels = []
        createdContainerId = nil
    }

    /// Parse raw port spec format: `[host-ip:]host-port:container-port[/protocol]`
    private func parseRawPortSpec(_ spec: String) -> PortPublishSpec? {
        let parts = spec.split(separator: ":", maxSplits: 2)
        guard parts.count >= 2 else { return nil }

        // Check if first part looks like an IP address (contains ".")
        if parts.count == 3 && parts[0].contains(".") {
            // Format: 127.0.0.1:8080:80 or 127.0.0.1:8080:80/udp
            let portAndProto = parts[2].split(separator: "/")
            return PortPublishSpec(
                hostPort: Int(parts[1]) ?? 0,
                containerPort: Int(portAndProto[0]) ?? 0,
                hostIP: String(parts[0]),
                protocol: portAndProto.dropFirst().first.map(String.init)
            )
        } else if parts.count == 3 {
            // Format: 8080:80/udp (3 parts but first part is numeric)
            let portAndProto = parts[2].split(separator: "/")
            return PortPublishSpec(
                hostPort: Int(parts[0]) ?? 0,
                containerPort: Int(portAndProto[0]) ?? 0,
                protocol: portAndProto.dropFirst().first.map(String.init)
            )
        } else {
            // Format: 8080:80 or 8080:80/udp
            let portAndProto = parts[1].split(separator: "/")
            return PortPublishSpec(
                hostPort: Int(parts[0]) ?? 0,
                containerPort: Int(portAndProto[0]) ?? 0,
                protocol: portAndProto.dropFirst().first.map(String.init)
            )
        }
    }

    func buildOptions() -> ContainerCreateOptions {
        ContainerCreateOptions(
            image: image,
            command: command.isEmpty ? [] : command.split(separator: " ").map(String.init),
            name: name.isEmpty ? nil : name,
            env: Dictionary(
                uniqueKeysWithValues: envVars
                    .filter { !$0.key.trimmingCharacters(in: .whitespaces).isEmpty }
                    .map { ($0.key.trimmingCharacters(in: .whitespaces), $0.value) }
            ),
            user: user.isEmpty ? nil : user,
            workdir: workdir.isEmpty ? nil : workdir,
            entrypoint: entrypoint.isEmpty ? nil : entrypoint,
            interactive: interactive,
            tty: tty,
            cpus: cpus,
            memory: memory.isEmpty ? nil : memory,
            volume: volumeMounts
                .filter { !$0.source.trimmingCharacters(in: .whitespaces).isEmpty }
                .map { "\($0.source):\($0.target)" },
            readOnly: readOnly,
            shmSize: shmSize.isEmpty ? nil : shmSize,
            network: network.isEmpty ? nil : network,
            publish: portMappings.compactMap { entry -> PortPublishSpec? in
                if entry.useRawSpec && !entry.rawSpec.trimmingCharacters(in: .whitespaces).isEmpty {
                    return parseRawPortSpec(entry.rawSpec)
                }
                guard entry.containerPort > 0 else { return nil }
                return PortPublishSpec(
                    hostPort: entry.hostPort,
                    containerPort: entry.containerPort,
                    protocol: entry.protocolType.isEmpty ? nil : entry.protocolType
                )
            },
            dns: dnsServers.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty },
            platform: platform.isEmpty ? nil : platform,
            arch: arch.isEmpty ? nil : arch,
            os: os.isEmpty ? nil : os,
            machine: selectedMachine.isEmpty ? nil : selectedMachine,
            labels: Dictionary(
                uniqueKeysWithValues: labels
                    .filter { !$0.key.trimmingCharacters(in: .whitespaces).isEmpty }
                    .map { ($0.key.trimmingCharacters(in: .whitespaces), $0.value) }
            ),
            rm: autoRemove
        )
    }
}

// MARK: - Reusable Entry Types

struct KeyValueEntry: Identifiable, Sendable, Equatable {
    var id = UUID()
    var key: String = ""
    var value: String = ""
}

struct PortMappingEntry: Identifiable, Sendable, Equatable {
    var id = UUID()
    var hostPort: Int = 0
    var containerPort: Int = 0
    var protocolType: String = "tcp"
    var useRawSpec: Bool = false
    var rawSpec: String = ""
}

struct VolumeMountEntry: Identifiable, Sendable, Equatable {
    var id = UUID()
    var source: String = ""
    var target: String = ""
    var useExistingVolume: Bool = false
}
