import SwiftUI

// MARK: - ViewModel

@MainActor
@Observable
final class MachineViewModel {
    var state: ViewState<[Machine]> = .loading
    var selectedMachine: Machine?
    var errorMessage: String?
    var isStarting = false

    // MARK: Create state
    var showCreateSheet = false
    var createForm = MachineCreateFormModel()
    var isCreating = false
    var createErrorMessage: String?

    // MARK: Delete confirmation
    var machineToDelete: Machine?
    var showDeleteConfirmation = false
    var isDeleting = false
    var deleteErrorMessage: String?
    var onDelete: (() -> Void)?

    // MARK: Set default
    var isSettingDefault = false

    // MARK: Available images for picker
    var availableImages: [ContainerImage] = []

    private let repository: MachineRepositoryProtocol
    private let systemRepository: SystemRepositoryProtocol
    private let imageRepository: ImageRepositoryProtocol?

    init(repository: MachineRepositoryProtocol, systemRepository: SystemRepositoryProtocol, imageRepository: ImageRepositoryProtocol? = nil) {
        self.repository = repository
        self.systemRepository = systemRepository
        self.imageRepository = imageRepository
    }

    func load() async {
        state = .loading
        await refresh()
        await loadImages()
    }

    func refresh() async {
        do {
            let machines = try await repository.listMachines()
            state = machines.isEmpty ? .empty("No machines found") : .loaded(machines)
        } catch {
            state = .error(error.localizedDescription)
            errorMessage = error.localizedDescription
        }
    }

    func loadImages() async {
        guard let imageRepository else { return }
        do {
            availableImages = try await imageRepository.listImages()
        } catch {
            // Non-critical
        }
    }

    // MARK: - Create

    func openCreateSheet() {
        createForm = MachineCreateFormModel()
        createErrorMessage = nil
        showCreateSheet = true
    }

    func createMachine() async {
        guard !createForm.image.trimmingCharacters(in: .whitespaces).isEmpty else {
            createErrorMessage = "Image is required"
            return
        }

        isCreating = true
        createErrorMessage = nil

        do {
            let options = createForm.buildOptions()
            let result = try await repository.createMachine(options: options)
            createForm.createdMachineName = result
            try? await Task.sleep(for: .seconds(1.5))
            showCreateSheet = false
        } catch {
            createErrorMessage = error.localizedDescription
        }

        isCreating = false
    }

    // MARK: - Actions

    func startMachine(_ name: String) async {
        do {
            try await repository.startMachine(name: name)
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func stopMachine(_ name: String) async {
        do {
            try await repository.stopMachine(name: name)
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func confirmDelete(_ machine: Machine) {
        machineToDelete = machine
        showDeleteConfirmation = true
    }

    func deleteMachine() async {
        guard let machine = machineToDelete else { return }
        isDeleting = true
        deleteErrorMessage = nil

        do {
            try await repository.removeMachine(name: machine.name)
            machineToDelete = nil
            showDeleteConfirmation = false
            onDelete?()
            await refresh()
        } catch {
            deleteErrorMessage = error.localizedDescription
        }

        isDeleting = false
    }

    /// Direct deletion without confirmation — used by the detail column view.
    func removeMachine(name: String) async throws {
        try await repository.removeMachine(name: name)
    }

    func setAsDefault(_ name: String) async {
        isSettingDefault = true
        do {
            try await repository.setDefaultMachine(name: name)
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
        isSettingDefault = false
    }

    // MARK: - Settings

    func applySetting(_ setting: MachineSetting) async throws {
        try await repository.setMachineSetting(setting: setting)
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
}

// MARK: - Create Form Model

@MainActor
@Observable
final class MachineCreateFormModel {
    var image: String = ""
    var name: String = ""
    var noBoot: Bool = true
    var setDefault: Bool = false
    var cpus: Int? = nil
    var memory: String = ""
    var homeMount: String = "rw"
    var arch: String = ""
    var os: String = ""

    var createdMachineName: String?

    func buildOptions() -> MachineCreateOptions {
        MachineCreateOptions(
            image: image,
            name: name.isEmpty ? nil : name,
            setDefault: setDefault,
            noBoot: noBoot,
            cpus: cpus,
            memory: memory.isEmpty ? nil : memory,
            homeMount: homeMount == "rw" ? nil : homeMount,
            arch: arch.isEmpty ? nil : arch,
            os: os.isEmpty ? nil : os
        )
    }
}

// MARK: - Machine Screen

struct MachineScreen: View {
    @State private var viewModel: MachineViewModel
    @Binding var selectedMachine: Machine?

    init(repository: MachineRepositoryProtocol, systemRepository: SystemRepositoryProtocol, imageRepository: ImageRepositoryProtocol? = nil, selectedMachine: Binding<Machine?> = .constant(nil)) {
        let vm = MachineViewModel(repository: repository, systemRepository: systemRepository, imageRepository: imageRepository)
        self._viewModel = State(wrappedValue: vm)
        self._selectedMachine = selectedMachine
        vm.onDelete = { [weak vm] in
            Task { @MainActor in
                selectedMachine.wrappedValue = nil
                vm?.selectedMachine = nil
            }
        }
    }

    var body: some View {
        Group {
            switch viewModel.state {
            case .loading:
                LoadingView("Loading machines...")
            case .loaded(let machines):
                MachineListView(machines: machines, viewModel: viewModel, selectedMachine: $selectedMachine)
            case .error(let message):
                if ServiceErrorDetector.isServiceNotRunning(message) {
                    ServiceUnavailableView(
                        errorMessage: message,
                        isStarting: viewModel.isStarting,
                        onStart: { await viewModel.startServices() },
                        onRetry: { await viewModel.load() }
                    )
                } else {
                    ErrorView(message) { Task { await viewModel.load() } }
                }
            case .empty(let message):
                EmptyStateView(message, systemImage: "desktopcomputer")
            }
        }
        .task { await viewModel.load() }
        .toolbar {
            ToolbarItemGroup {
                Button {
                    viewModel.openCreateSheet()
                } label: {
                    Label("Create Machine", systemImage: "plus")
                }
                .help("Create a new machine")

                Button {
                    Task { await viewModel.refresh() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .help("Refresh machine list")
            }
        }
        .sheet(isPresented: $viewModel.showCreateSheet) {
            CreateMachineView(viewModel: viewModel)
                .onDisappear {
                    Task { await viewModel.refresh() }
                }
        }
        // Delete confirmation
        .alert("Delete Machine", isPresented: $viewModel.showDeleteConfirmation, presenting: viewModel.machineToDelete) { machine in
            Button(role: .destructive) {
                Task { await viewModel.deleteMachine() }
            } label: {
                Text("Delete \"\(machine.name)\"")
            }
            Button("Cancel", role: .cancel) {
                viewModel.machineToDelete = nil
            }
        } message: { machine in
            Text("Delete the machine \"\(machine.name)\"? It will be stopped first if running.")
        }
        // Delete error
        .alert("Delete Failed", isPresented: .init(
            get: { viewModel.deleteErrorMessage != nil },
            set: { if !$0 { viewModel.deleteErrorMessage = nil } }
        )) {
            Button("OK") { viewModel.deleteErrorMessage = nil }
        } message: {
            Text(viewModel.deleteErrorMessage ?? "")
        }
    }
}

// MARK: - Machine List View

struct MachineListView: View {
    let machines: [Machine]
    let viewModel: MachineViewModel
    @Binding var selectedMachine: Machine?

    var body: some View {
        List(machines, selection: $selectedMachine) { machine in
            MachineRow(machine: machine, viewModel: viewModel)
                .tag(machine)
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
    }
}

// MARK: - Machine Row

struct MachineRow: View {
    let machine: Machine
    let viewModel: MachineViewModel

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "desktopcomputer")
                .font(.title2)
                .foregroundColor(.blue)

            StatusBadge(machine.status.displayName)

            VStack(alignment: .leading, spacing: 2) {
                Text(machine.name)
                    .font(.headline)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text("\(machine.cpus) CPUs")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if machine.memory > 0 {
                        Text("⋅ \(formatBytes(machine.memory)) RAM")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    if machine.diskSize > 0 {
                        Text("⋅ \(formatBytes(machine.diskSize)) disk")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            HStack(spacing: 4) {
                Button {
                    Task { await viewModel.startMachine(machine.name) }
                } label: {
                    Image(systemName: "play.fill")
                }
                .disabled(machine.status == .running || machine.status == .starting)
                .help("Start machine")

                Button {
                    Task { await viewModel.stopMachine(machine.name) }
                } label: {
                    Image(systemName: "stop.fill")
                }
                .disabled(machine.status != .running)
                .help("Stop machine")

                Button {
                    viewModel.confirmDelete(machine)
                } label: {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
                .help("Delete machine")
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Create Machine Sheet

struct CreateMachineView: View {
    @Bindable var viewModel: MachineViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Create Machine")
                    .font(.title2).bold()
                Spacer()
                if !viewModel.isCreating {
                    Button("Close") { dismiss() }
                        .keyboardShortcut(.escape)
                }
            }

            if let createdName = viewModel.createForm.createdMachineName {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.green)
                    Text("Machine Created")
                        .font(.title3).bold()
                    Text(createdName)
                        .font(.body.monospaced())
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                    ProgressView().scaleEffect(0.8)
                    Text("Closing...").font(.caption).foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                formContent
            }
        }
        .padding()
        .frame(width: 520)
    }

    @ViewBuilder
    private var formContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Image
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Image *").font(.headline)
                    Spacer()
                    if !viewModel.availableImages.isEmpty {
                        Picker("Pick", selection: $viewModel.createForm.image) {
                            Text("").tag("")
                            ForEach(viewModel.availableImages, id: \.id) { img in
                                Text(img.reference).tag(img.reference)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                    }
                }
                TextField("e.g. alpine:latest", text: $viewModel.createForm.image)
                    .textFieldStyle(.roundedBorder)
                    .font(.body.monospaced())
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 0) {
                    Text("Name").font(.headline)
                    Text(" (optional)").foregroundColor(.secondary).font(.headline)
                }
                TextField("e.g. my-machine", text: $viewModel.createForm.name)
                    .textFieldStyle(.roundedBorder)
                    .font(.body.monospaced())
            }

            // CPUs & Memory
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                GridRow {
                    Text("CPUs").foregroundColor(.secondary)
                    TextField("Default", value: $viewModel.createForm.cpus, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                }
                GridRow {
                    Text("Memory").foregroundColor(.secondary)
                    TextField("e.g. 4G, 2048M", text: $viewModel.createForm.memory)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 150)
                }
            }

            // Home mount
            VStack(alignment: .leading, spacing: 4) {
                Text("Home Mount").font(.headline)
                Picker("", selection: $viewModel.createForm.homeMount) {
                    Text("Read/Write").tag("rw")
                    Text("Read-Only").tag("ro")
                    Text("None").tag("none")
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()
            }

            // Options
            Toggle("Don't boot after creation", isOn: $viewModel.createForm.noBoot)
            Toggle("Set as default machine", isOn: $viewModel.createForm.setDefault)

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 0) {
                    Text("Platform").font(.headline)
                    Text(" (optional)").foregroundColor(.secondary).font(.headline)
                }
                Picker("Arch", selection: $viewModel.createForm.arch) {
                    Text("Default (host)").tag("")
                    Text("arm64").tag("arm64")
                    Text("x86_64").tag("x86_64")
                }
                .pickerStyle(.segmented)

                Picker("OS", selection: $viewModel.createForm.os) {
                    Text("Default (linux)").tag("")
                    Text("linux").tag("linux")
                    Text("darwin").tag("darwin")
                }
                .pickerStyle(.segmented)
            }

            // Error
            if let error = viewModel.createErrorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.callout)
            }

            // Buttons
            HStack {
                Button(role: .cancel) { dismiss() }
                    .disabled(viewModel.isCreating)
                    .buttonStyle(.bordered)
                    .keyboardShortcut(.cancelAction)

                Spacer()

                Button {
                    Task { await viewModel.createMachine() }
                } label: {
                    if viewModel.isCreating {
                        ProgressView().scaleEffect(0.7).frame(width: 16)
                        Text("Creating...")
                    } else {
                        Image(systemName: "plus")
                        Text("Create")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isCreating || viewModel.createForm.image.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }
}

// MARK: - Machine Detail View (for NavigationSplitView detail column)

struct MachineDetailView: View {
    let machine: Machine
    let viewModel: MachineViewModel
    let onDelete: (() -> Void)?

    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false

    // Setting sheet
    @State private var showSettingsSheet = false
    @State private var editCpus: Int
    @State private var editMemory: String
    @State private var editHomeMount: String

    init(machine: Machine, viewModel: MachineViewModel, onDelete: (() -> Void)? = nil) {
        self.machine = machine
        self.viewModel = viewModel
        self.onDelete = onDelete
        self._editCpus = State(initialValue: machine.cpus)
        self._editMemory = State(initialValue: "")
        self._editHomeMount = State(initialValue: "rw")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection
                Divider()
                statusSection
                Divider()
                infoSection
                Divider()
                actionsSection
            }
            .padding()
        }
        .frame(minWidth: 300)
        .alert("Delete Machine", isPresented: $showDeleteConfirmation) {
            Button(role: .destructive) {
                Task { await performDelete() }
            } label: {
                Text("Delete \"\(machine.name)\"")
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Delete \"\(machine.name)\"? It will be stopped first if running.")
        }
        .sheet(isPresented: $showSettingsSheet) {
            settingsSheet
        }
    }

    private var headerSection: some View {
        HStack {
            Image(systemName: "desktopcomputer")
                .font(.title)
                .foregroundColor(.blue)

            VStack(alignment: .leading, spacing: 4) {
                Text(machine.name)
                    .font(.largeTitle).bold()
                Text("\(machine.cpus) CPUs ⋅ \(formatBytes(machine.memory)) RAM")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }

    private var statusSection: some View {
        GroupBox("Status") {
            HStack {
                StatusBadge(machine.status.displayName)
                Spacer()
                if let runningSince = machine.runningSince {
                    Text("Since \(runningSince.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var infoSection: some View {
        GroupBox("Info") {
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                GridRow {
                    Text("Name").foregroundColor(.secondary)
                    Text(machine.name)
                        .font(.body.monospaced())
                        .textSelection(.enabled)
                }
                GridRow {
                    Text("CPUs").foregroundColor(.secondary)
                    Text("\(machine.cpus)")
                }
                GridRow {
                    Text("Memory").foregroundColor(.secondary)
                    Text(formatBytes(machine.memory))
                }
                GridRow {
                    Text("Disk Size").foregroundColor(.secondary)
                    Text(formatBytes(machine.diskSize))
                }
                if !machine.vmDirectory.isEmpty {
                    GridRow {
                        Text("VM Directory").foregroundColor(.secondary)
                        Text(machine.vmDirectory)
                            .font(.caption.monospaced())
                    }
                }
                if let runningSince = machine.runningSince {
                    GridRow {
                        Text("Running Since").foregroundColor(.secondary)
                        Text(runningSince.formatted(date: .long, time: .shortened))
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var actionsSection: some View {
        GroupBox("Actions") {
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    Button {
                        Task { await viewModel.startMachine(machine.name) }
                    } label: {
                        Label("Start", systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(machine.status == .running || machine.status == .starting)

                    Button {
                        Task { await viewModel.stopMachine(machine.name) }
                    } label: {
                        Label("Stop", systemImage: "stop.fill")
                    }
                    .buttonStyle(.bordered)
                    .disabled(machine.status != .running)

                    Button {
                        Task { await viewModel.setAsDefault(machine.name) }
                    } label: {
                        if viewModel.isSettingDefault {
                            ProgressView().scaleEffect(0.7)
                        } else {
                            Label("Set Default", systemImage: "star")
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.isSettingDefault)

                    Button {
                        editCpus = machine.cpus
                        editMemory = ""
                        editHomeMount = "rw"
                        showSettingsSheet = true
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                    .buttonStyle(.bordered)
                }

                Divider()

                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    if isDeleting {
                        ProgressView().scaleEffect(0.7)
                    } else {
                        Label("Delete Machine", systemImage: "trash")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .disabled(isDeleting)
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 4)
        }
    }

    private var settingsSheet: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Settings: \(machine.name)")
                    .font(.title2).bold()
                Spacer()
                Button("Close") { showSettingsSheet = false }
                    .keyboardShortcut(.escape)
            }

            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("CPUs").font(.headline)
                    TextField("CPUs", value: $editCpus, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 0) {
                        Text("Memory").font(.headline)
                        Text(" (e.g. 4G, 2048M)").foregroundColor(.secondary).font(.headline)
                    }
                    TextField("Memory", text: $editMemory)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 150)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Home Mount").font(.headline)
                    Picker("", selection: $editHomeMount) {
                        Text("Read/Write").tag("rw")
                        Text("Read-Only").tag("ro")
                        Text("None").tag("none")
                    }
                    .pickerStyle(.radioGroup)
                    .labelsHidden()
                }
            }

            HStack {
                Button("Cancel") { showSettingsSheet = false }
                    .buttonStyle(.bordered)

                Spacer()

                Button {
                    Task { await applySettings() }
                } label: {
                    Text("Apply & Restart Required")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 400)
    }

    private func applySettings() async {
        // Apply each changed setting
        do {
            if editCpus != machine.cpus {
                let setting = MachineSetting(setting: .cpus(editCpus), machineName: machine.name)
                try await viewModel.applySetting(setting)
            }
            if !editMemory.isEmpty {
                let setting = MachineSetting(setting: .memory(editMemory), machineName: machine.name)
                try await viewModel.applySetting(setting)
            }
            let homeMountSetting = MachineSetting(setting: .homeMount(editHomeMount), machineName: machine.name)
            try await viewModel.applySetting(homeMountSetting)

            showSettingsSheet = false
            await viewModel.refresh()
        } catch {
            viewModel.errorMessage = error.localizedDescription
        }
    }

    private func performDelete() async {
        isDeleting = true
        do {
            try await viewModel.removeMachine(name: machine.name)
            onDelete?()
            await viewModel.refresh()
        } catch {
            // Error handled by the ViewModel's state
        }
        isDeleting = false
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: bytes)
    }
}

