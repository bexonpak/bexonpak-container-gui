import SwiftUI

// MARK: - ViewModel

@MainActor
@Observable
final class VolumeViewModel {
    var state: ViewState<[Volume]> = .loading
    var selectedVolume: Volume?
    var errorMessage: String?
    var isStarting = false

    // MARK: Create state
    var showCreateSheet = false
    var createForm = VolumeCreateFormModel()
    var isCreating = false
    var createErrorMessage: String?

    // MARK: Delete confirmation
    var volumeToDelete: Volume?
    var showDeleteConfirmation = false
    var isDeleting = false
    var deleteErrorMessage: String?

    var onDelete: (() -> Void)?

    // MARK: Prune
    var showPruneConfirmation = false
    var isPruning = false
    var prunedCount: Int?
    var pruneErrorMessage: String?

    private let repository: VolumeRepositoryProtocol
    private let systemRepository: SystemRepositoryProtocol

    init(repository: VolumeRepositoryProtocol, systemRepository: SystemRepositoryProtocol) {
        self.repository = repository
        self.systemRepository = systemRepository
    }

    func load() async {
        state = .loading
        await refresh()
    }

    func refresh() async {
        do {
            let volumes = try await repository.listVolumes()
            state = volumes.isEmpty ? .empty("No volumes found") : .loaded(volumes)
        } catch {
            state = .error(error.localizedDescription)
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Create

    func openCreateSheet() {
        createForm = VolumeCreateFormModel()
        createErrorMessage = nil
        showCreateSheet = true
    }

    func createVolume() async {
        guard !createForm.name.trimmingCharacters(in: .whitespaces).isEmpty else {
            createErrorMessage = "Volume name is required"
            return
        }

        isCreating = true
        createErrorMessage = nil

        do {
            let options = createForm.buildOptions()
            let result = try await repository.createVolume(options: options)
            createForm.createdVolumeName = result
            // Show success briefly, then dismiss sheet — refresh happens in onDisappear
            try? await Task.sleep(for: .seconds(1.5))
            showCreateSheet = false
        } catch {
            createErrorMessage = error.localizedDescription
        }

        isCreating = false
    }

    // MARK: - Delete

    func confirmDelete(_ volume: Volume) {
        volumeToDelete = volume
        showDeleteConfirmation = true
    }

    func deleteVolume() async {
        guard let volume = volumeToDelete else { return }
        isDeleting = true
        deleteErrorMessage = nil

        do {
            try await repository.removeVolume(name: volume.name, force: false)
            volumeToDelete = nil
            showDeleteConfirmation = false
            onDelete?()
            await refresh()
        } catch {
            deleteErrorMessage = error.localizedDescription
        }

        isDeleting = false
    }

    /// Direct creation without going through the form — for recreate from detail view.
    func createVolume(options: VolumeCreateOptions) async throws -> String {
        try await repository.createVolume(options: options)
    }

    /// Direct deletion without confirmation — used by the detail column view.
    func removeVolume(name: String) async throws {
        try await repository.removeVolume(name: name, force: false)
    }

    // MARK: - Prune

    func confirmPrune() {
        showPruneConfirmation = true
    }

    func pruneVolumes() async {
        isPruning = true
        pruneErrorMessage = nil

        do {
            prunedCount = try await repository.pruneVolumes()
            showPruneConfirmation = false
            await refresh()
        } catch {
            pruneErrorMessage = error.localizedDescription
        }

        isPruning = false
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
final class VolumeCreateFormModel {
    var name: String = ""
    var labels: [KeyValueEntry] = []
    var driverOpts: [KeyValueEntry] = []
    var size: String = ""

    var createdVolumeName: String?

    func buildOptions() -> VolumeCreateOptions {
        VolumeCreateOptions(
            name: name,
            labels: Dictionary(uniqueKeysWithValues: labels.filter { !$0.key.isEmpty }.map { ($0.key, $0.value) }),
            driverOpts: Dictionary(uniqueKeysWithValues: driverOpts.filter { !$0.key.isEmpty }.map { ($0.key, $0.value) }),
            size: size.isEmpty ? nil : size
        )
    }
}

// MARK: - Volumes Screen

struct VolumesScreen: View {
    @State private var viewModel: VolumeViewModel
    @Binding var selectedVolume: Volume?

    init(repository: VolumeRepositoryProtocol, systemRepository: SystemRepositoryProtocol, selectedVolume: Binding<Volume?> = .constant(nil)) {
        let vm = VolumeViewModel(repository: repository, systemRepository: systemRepository)
        self._viewModel = State(wrappedValue: vm)
        self._selectedVolume = selectedVolume
        vm.onDelete = { [weak vm] in
            Task { @MainActor in
                selectedVolume.wrappedValue = nil
                vm?.selectedVolume = nil
            }
        }
    }

    var body: some View {
        Group {
            switch viewModel.state {
            case .loading:
                LoadingView("Loading volumes...")
            case .loaded(let volumes):
                VolumeListView(volumes: volumes, viewModel: viewModel, selectedVolume: $selectedVolume)
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
                EmptyStateView(message, systemImage: "externaldrive")
            }
        }
        .task { await viewModel.load() }
        .toolbar {
            ToolbarItemGroup {
                Button {
                    viewModel.openCreateSheet()
                } label: {
                    Label("Create Volume", systemImage: "plus")
                }
                .help("Create a new volume")

                Button {
                    viewModel.confirmPrune()
                } label: {
                    Label("Prune", systemImage: "trash.slash")
                }
                .help("Remove unused volumes")

                Button {
                    Task { await viewModel.refresh() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .help("Refresh volume list")
            }
        }
        .sheet(isPresented: $viewModel.showCreateSheet) {
            CreateVolumeView(viewModel: viewModel)
                .onDisappear {
                    Task { await viewModel.refresh() }
                }
        }
        // Delete confirmation
        .alert("Delete Volume", isPresented: $viewModel.showDeleteConfirmation, presenting: viewModel.volumeToDelete) { volume in
            Button(role: .destructive) {
                Task { await viewModel.deleteVolume() }
            } label: {
                Text("Delete \"\(volume.name)\"")
            }
            Button("Cancel", role: .cancel) {
                viewModel.volumeToDelete = nil
            }
        } message: { volume in
            Text("Are you sure you want to delete the volume \"\(volume.name)\"? This action cannot be undone.")
        }
        // Prune confirmation
        .alert("Prune Volumes", isPresented: $viewModel.showPruneConfirmation) {
            Button(role: .destructive) {
                Task { await viewModel.pruneVolumes() }
            } label: {
                Text("Prune All Unused Volumes")
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Remove all unused volumes to reclaim disk space. This action cannot be undone.")
        }
        // Prune result
        .alert("Prune Complete", isPresented: .init(
            get: { viewModel.prunedCount != nil },
            set: { if !$0 { viewModel.prunedCount = nil } }
        )) {
            Button("OK") { viewModel.prunedCount = nil }
        } message: {
            if let count = viewModel.prunedCount {
                Text("Reclaimed \(count) volume\(count == 1 ? "" : "s").")
            }
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
        // Prune error
        .alert("Prune Failed", isPresented: .init(
            get: { viewModel.pruneErrorMessage != nil },
            set: { if !$0 { viewModel.pruneErrorMessage = nil } }
        )) {
            Button("OK") { viewModel.pruneErrorMessage = nil }
        } message: {
            Text(viewModel.pruneErrorMessage ?? "")
        }
    }
}

// MARK: - Volume List View

struct VolumeListView: View {
    let volumes: [Volume]
    let viewModel: VolumeViewModel
    @Binding var selectedVolume: Volume?

    var body: some View {
        List(volumes, selection: $selectedVolume) { volume in
            VolumeRow(volume: volume, viewModel: viewModel)
                .tag(volume)
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
    }
}

// MARK: - Volume Row

struct VolumeRow: View {
    let volume: Volume
    let viewModel: VolumeViewModel

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "externaldrive")
                .font(.title2)
                .foregroundColor(.cyan)

            VStack(alignment: .leading, spacing: 2) {
                Text(volume.name)
                    .font(.headline)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(volume.driver)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if let size = volume.size, size > 0 {
                        Text("· \(formatBytes(size))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    if !volume.scope.isEmpty {
                        Text("· \(volume.scope)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    if !volume.labels.isEmpty {
                        Text("· \(volume.labels.count) label\(volume.labels.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            if let created = volume.created {
                Text(created.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Button {
                viewModel.confirmDelete(volume)
            } label: {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
            .help("Remove volume")
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

// MARK: - Create Volume Sheet

struct CreateVolumeView: View {
    @Bindable var viewModel: VolumeViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("Create Volume")
                    .font(.title2).bold()
                Spacer()
                if !viewModel.isCreating {
                    Button("Close") { dismiss() }
                        .keyboardShortcut(.escape)
                }
            }

            if let createdName = viewModel.createForm.createdVolumeName {
                // Success
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.green)
                    Text("Volume Created")
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
                // Form
                formContent
            }
        }
        .padding()
        .frame(width: 480)
    }

    @ViewBuilder
    private var formContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Name
            VStack(alignment: .leading, spacing: 4) {
                Text("Volume Name *").font(.headline)
                TextField("e.g. my-data", text: $viewModel.createForm.name)
                    .textFieldStyle(.roundedBorder)
                    .font(.body.monospaced())
            }

            // Size
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 0) {
                    Text("Size").font(.headline)
                    Text(" (optional)").foregroundColor(.secondary).font(.headline)
                }
                TextField("e.g. 10G, 512M", text: $viewModel.createForm.size)
                    .textFieldStyle(.roundedBorder)
                    .font(.body.monospaced())
                    .frame(width: 160)
                Text("Minimum 1 MiB. Suffix: K, M, G, T, P")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Labels
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 0) {
                    Text("Labels").font(.headline)
                    Text(" (optional)").foregroundColor(.secondary).font(.headline)
                }
                ForEach(viewModel.createForm.labels.indices, id: \.self) { index in
                    HStack(spacing: 8) {
                        TextField("KEY", text: $viewModel.createForm.labels[index].key)
                            .textFieldStyle(.roundedBorder)
                            .font(.caption.monospaced())
                            .frame(width: 120)
                        Text("=").foregroundColor(.secondary)
                        TextField("value", text: $viewModel.createForm.labels[index].value)
                            .textFieldStyle(.roundedBorder)
                            .font(.caption.monospaced())
                        Button(role: .destructive) {
                            viewModel.createForm.labels.remove(at: index)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }
                Button {
                    viewModel.createForm.labels.append(KeyValueEntry())
                } label: {
                    Label("Add Label", systemImage: "plus")
                        .font(.caption)
                }
            }

            // Driver Options
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 0) {
                    Text("Driver Options").font(.headline)
                    Text(" (optional)").foregroundColor(.secondary).font(.headline)
                }
                Text("e.g. journal=ordered, nodiscard=true")
                    .font(.caption)
                    .foregroundColor(.secondary)

                ForEach(viewModel.createForm.driverOpts.indices, id: \.self) { index in
                    HStack(spacing: 8) {
                        TextField("key", text: $viewModel.createForm.driverOpts[index].key)
                            .textFieldStyle(.roundedBorder)
                            .font(.caption.monospaced())
                            .frame(width: 120)
                        Text("=").foregroundColor(.secondary)
                        TextField("value", text: $viewModel.createForm.driverOpts[index].value)
                            .textFieldStyle(.roundedBorder)
                            .font(.caption.monospaced())
                        Button(role: .destructive) {
                            viewModel.createForm.driverOpts.remove(at: index)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }
                Button {
                    viewModel.createForm.driverOpts.append(KeyValueEntry())
                } label: {
                    Label("Add Driver Option", systemImage: "plus")
                        .font(.caption)
                }
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
                    Task { await viewModel.createVolume() }
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
                .disabled(viewModel.isCreating || viewModel.createForm.name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }
}

// MARK: - Volume Detail View (for NavigationSplitView detail column)

struct VolumeDetailView: View {
    let volume: Volume
    let viewModel: VolumeViewModel
    let onDelete: (() -> Void)?

    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var showRecreateSheet = false
    @State private var recreateName = ""
    @State private var recreateSize = ""
    @State private var isRecreating = false
    @State private var recreateError: String?

    init(volume: Volume, viewModel: VolumeViewModel, onDelete: (() -> Void)? = nil) {
        self.volume = volume
        self.viewModel = viewModel
        self.onDelete = onDelete
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection
                Divider()
                infoSection
                if !volume.labels.isEmpty {
                    Divider()
                    labelsSection
                }
                Divider()
                actionsSection
            }
            .padding()
        }
        .frame(minWidth: 300)
        .sheet(isPresented: $showRecreateSheet) {
            recreateSheet
                .onDisappear {
                    Task { await viewModel.refresh() }
                }
        }
        .alert("Delete Volume", isPresented: $showDeleteConfirmation) {
            Button(role: .destructive) {
                Task { await performDelete() }
            } label: {
                Text("Delete \"\(volume.name)\"")
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete \"\(volume.name)\"? This cannot be undone.")
        }
    }

    private var headerSection: some View {
        HStack {
            Image(systemName: "externaldrive")
                .font(.title)
                .foregroundColor(.cyan)

            VStack(alignment: .leading, spacing: 4) {
                Text(volume.name)
                    .font(.largeTitle).bold()
                Text(volume.driver)
                    .font(.title3)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }

    private var infoSection: some View {
        GroupBox("Info") {
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                GridRow {
                    Text("Name").foregroundColor(.secondary)
                    Text(volume.name)
                        .font(.body.monospaced())
                        .textSelection(.enabled)
                        .lineLimit(nil)
                }
                GridRow {
                    Text("Driver").foregroundColor(.secondary)
                    Text(volume.driver)
                        .lineLimit(nil)
                }
                GridRow {
                    Text("Scope").foregroundColor(.secondary)
                    Text(volume.scope)
                        .lineLimit(nil)
                }
                GridRow {
                    Text("Mount Point").foregroundColor(.secondary)
                    Text(volume.mountPoint)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                        .lineLimit(3)
                }
                if let size = volume.size, size > 0 {
                    GridRow {
                        Text("Size").foregroundColor(.secondary)
                        Text(VolumeDetailView.formatBytes(size))
                            .font(.body.monospaced())
                            .lineLimit(nil)
                    }
                }
                if let created = volume.created {
                    GridRow {
                        Text("Created").foregroundColor(.secondary)
                        Text(created.formatted(date: .long, time: .shortened))
                            .lineLimit(nil)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var labelsSection: some View {
        GroupBox("Labels") {
            ForEach(Array(volume.labels.keys.sorted()), id: \.self) { key in
                HStack {
                    Text(key).font(.caption.monospaced()).bold()
                    Text(volume.labels[key] ?? "")
                        .font(.caption.monospaced())
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.vertical, 2)
            }
            .padding(.vertical, 4)
        }
    }

    private var actionsSection: some View {
        GroupBox("Actions") {
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        if isDeleting {
                            ProgressView().scaleEffect(0.7)
                        } else {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .disabled(isDeleting)

                    Button {
                        openRecreateSheet()
                    } label: {
                        Label("Modify", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func openRecreateSheet() {
        recreateName = volume.name
        recreateSize = ""
        recreateError = nil
        showRecreateSheet = true
    }

    private var recreateSheet: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Modify Volume")
                    .font(.title2).bold()
                Spacer()
                if !isRecreating {
                    Button("Close") { showRecreateSheet = false }
                        .keyboardShortcut(.escape)
                }
            }

            Text("This will create a new volume and delete \"\(volume.name)\".")
                .font(.callout).foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Name *").font(.headline)
                    TextField("Volume name", text: $recreateName)
                        .textFieldStyle(.roundedBorder)
                        .font(.body.monospaced())
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 0) {
                        Text("Size").font(.headline)
                        Text(" (optional)").foregroundColor(.secondary).font(.headline)
                    }
                    TextField("e.g. 10G, 512M", text: $recreateSize)
                        .textFieldStyle(.roundedBorder)
                        .font(.body.monospaced())
                        .frame(width: 160)
                }

                if let error = recreateError {
                    Text(error).foregroundColor(.red).font(.callout)
                }
            }

            HStack {
                Button(role: .cancel) { showRecreateSheet = false }
                    .disabled(isRecreating).buttonStyle(.bordered)
                Spacer()
                Button {
                    Task { await performRecreate() }
                } label: {
                    if isRecreating {
                        ProgressView().scaleEffect(0.7).frame(width: 16)
                        Text("Recreating...")
                    } else {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text("Recreate")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isRecreating || recreateName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding()
        .frame(width: 420)
    }

    private func performRecreate() async {
        isRecreating = true
        recreateError = nil
        do {
            let options = VolumeCreateOptions(
                name: recreateName,
                size: recreateSize.isEmpty ? nil : recreateSize
            )
            _ = try await viewModel.createVolume(options: options)
            try await viewModel.removeVolume(name: volume.name)
            onDelete?()
            showRecreateSheet = false
        } catch {
            recreateError = error.localizedDescription
        }
        isRecreating = false
    }

    fileprivate static func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: bytes)
    }

    private func performDelete() async {
        isDeleting = true
        do {
            try await viewModel.removeVolume(name: volume.name)
            onDelete?()
            await viewModel.refresh()
        } catch {
            // Error handled by the ViewModel's state
        }
        isDeleting = false
    }
}
