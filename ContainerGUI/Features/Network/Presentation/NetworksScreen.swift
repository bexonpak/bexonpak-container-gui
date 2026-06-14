import SwiftUI

// MARK: - ViewModel

@MainActor
@Observable
final class NetworkViewModel {
    var state: ViewState<[ContainerNetwork]> = .loading
    var selectedNetwork: ContainerNetwork?
    var errorMessage: String?
    var isStarting = false

    // MARK: Create state
    var showCreateSheet = false
    var createForm = NetworkCreateFormModel()
    var isCreating = false
    var createErrorMessage: String?

    // MARK: Delete confirmation
    var networkToDelete: ContainerNetwork?
    var showDeleteConfirmation = false
    var isDeleting = false
    var deleteErrorMessage: String?
    var onDelete: (() -> Void)?

    // MARK: Prune
    var showPruneConfirmation = false
    var isPruning = false
    var prunedCount: Int?
    var pruneErrorMessage: String?

    private let repository: NetworkRepositoryProtocol
    private let systemRepository: SystemRepositoryProtocol

    init(repository: NetworkRepositoryProtocol, systemRepository: SystemRepositoryProtocol) {
        self.repository = repository
        self.systemRepository = systemRepository
    }

    func load() async {
        state = .loading
        await refresh()
    }

    func refresh() async {
        do {
            let networks = try await repository.listNetworks()
            state = networks.isEmpty ? .empty("No networks found") : .loaded(networks)
        } catch {
            state = .error(error.localizedDescription)
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Create

    func openCreateSheet() {
        createForm = NetworkCreateFormModel()
        createErrorMessage = nil
        showCreateSheet = true
    }

    func createNetwork() async {
        guard !createForm.name.trimmingCharacters(in: .whitespaces).isEmpty else {
            createErrorMessage = "Network name is required"
            return
        }

        isCreating = true
        createErrorMessage = nil

        do {
            let options = createForm.buildOptions()
            let result = try await repository.createNetwork(options: options)
            createForm.createdNetworkName = result
            try? await Task.sleep(for: .seconds(1.5))
            showCreateSheet = false
        } catch {
            createErrorMessage = error.localizedDescription
        }

        isCreating = false
    }

    // MARK: - Delete

    func confirmDelete(_ network: ContainerNetwork) {
        networkToDelete = network
        showDeleteConfirmation = true
    }

    func deleteNetwork() async {
        guard let network = networkToDelete else { return }
        isDeleting = true
        deleteErrorMessage = nil

        do {
            try await repository.removeNetwork(id: network.id)
            networkToDelete = nil
            showDeleteConfirmation = false
            onDelete?()
            await refresh()
        } catch {
            deleteErrorMessage = error.localizedDescription
        }

        isDeleting = false
    }

    /// Direct creation without going through the form — for recreate from detail view.
    func createNetwork(options: NetworkCreateOptions) async throws -> String {
        try await repository.createNetwork(options: options)
    }

    /// Direct deletion without confirmation — used by the detail column view.
    func removeNetwork(id: String) async throws {
        try await repository.removeNetwork(id: id)
    }

    // MARK: - Prune

    func confirmPrune() {
        showPruneConfirmation = true
    }

    func pruneNetworks() async {
        isPruning = true
        pruneErrorMessage = nil

        do {
            prunedCount = try await repository.pruneNetworks()
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
final class NetworkCreateFormModel {
    var name: String = ""
    var labels: [KeyValueEntry] = []
    var options: [KeyValueEntry] = []
    var subnet: String = ""
    var subnetV6: String = ""
    var plugin: String = ""
    var internalNetwork: Bool = false

    var createdNetworkName: String?

    func buildOptions() -> NetworkCreateOptions {
        NetworkCreateOptions(
            name: name,
            internalNetwork: internalNetwork,
            labels: Dictionary(uniqueKeysWithValues: labels.filter { !$0.key.isEmpty }.map { ($0.key, $0.value) }),
            options: Dictionary(uniqueKeysWithValues: options.filter { !$0.key.isEmpty }.map { ($0.key, $0.value) }),
            plugin: plugin.isEmpty ? nil : plugin,
            subnet: subnet.isEmpty ? nil : subnet,
            subnetV6: subnetV6.isEmpty ? nil : subnetV6
        )
    }
}

// MARK: - Networks Screen

struct NetworksScreen: View {
    @State private var viewModel: NetworkViewModel
    @Binding var selectedNetwork: ContainerNetwork?

    init(repository: NetworkRepositoryProtocol, systemRepository: SystemRepositoryProtocol, selectedNetwork: Binding<ContainerNetwork?> = .constant(nil)) {
        let vm = NetworkViewModel(repository: repository, systemRepository: systemRepository)
        self._viewModel = State(wrappedValue: vm)
        self._selectedNetwork = selectedNetwork
        vm.onDelete = { [weak vm] in
            Task { @MainActor in
                selectedNetwork.wrappedValue = nil
                vm?.selectedNetwork = nil
            }
        }
    }

    var body: some View {
        Group {
            switch viewModel.state {
            case .loading:
                LoadingView("Loading networks...")
            case .loaded(let networks):
                NetworkListView(networks: networks, viewModel: viewModel, selectedNetwork: $selectedNetwork)
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
                EmptyStateView(message, systemImage: "network")
            }
        }
        .task { await viewModel.load() }
        .toolbar {
            ToolbarItemGroup {
                Button {
                    viewModel.openCreateSheet()
                } label: {
                    Label("Create Network", systemImage: "plus")
                }
                .help("Create a new network")

                Button {
                    viewModel.confirmPrune()
                } label: {
                    Label("Prune", systemImage: "trash.slash")
                }
                .help("Remove unused networks")

                Button {
                    Task { await viewModel.refresh() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .help("Refresh network list")
            }
        }
        .sheet(isPresented: $viewModel.showCreateSheet) {
            CreateNetworkView(viewModel: viewModel)
                .onDisappear {
                    Task { await viewModel.refresh() }
                }
        }
        // Delete confirmation
        .alert("Delete Network", isPresented: $viewModel.showDeleteConfirmation, presenting: viewModel.networkToDelete) { network in
            Button(role: .destructive) {
                Task { await viewModel.deleteNetwork() }
            } label: {
                Text("Delete \"\(network.name)\"")
            }
            Button("Cancel", role: .cancel) {
                viewModel.networkToDelete = nil
            }
        } message: { network in
            Text("Are you sure you want to delete the network \"\(network.name)\"? This action cannot be undone.")
        }
        // Prune confirmation
        .alert("Prune Networks", isPresented: $viewModel.showPruneConfirmation) {
            Button(role: .destructive) {
                Task { await viewModel.pruneNetworks() }
            } label: {
                Text("Prune All Unused Networks")
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Remove all unused networks to reclaim resources. This action cannot be undone.")
        }
        // Prune result
        .alert("Prune Complete", isPresented: .init(
            get: { viewModel.prunedCount != nil },
            set: { if !$0 { viewModel.prunedCount = nil } }
        )) {
            Button("OK") { viewModel.prunedCount = nil }
        } message: {
            if let count = viewModel.prunedCount {
                Text("Reclaimed \(count) network\(count == 1 ? "" : "s").")
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

// MARK: - Network List View

struct NetworkListView: View {
    let networks: [ContainerNetwork]
    let viewModel: NetworkViewModel
    @Binding var selectedNetwork: ContainerNetwork?

    var body: some View {
        List(networks, selection: $selectedNetwork) { network in
            NetworkRow(network: network, viewModel: viewModel)
                .tag(network)
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
    }
}

// MARK: - Network Row

struct NetworkRow: View {
    let network: ContainerNetwork
    let viewModel: NetworkViewModel

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "network")
                .font(.title2)
                .foregroundColor(.mint)

            VStack(alignment: .leading, spacing: 2) {
                Text(network.name)
                    .font(.headline)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(network.driver)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if let subnet = network.subnet, !subnet.isEmpty {
                        Text("· \(subnet)")
                            .font(.caption.monospaced())
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            Text(network.scope)
                .font(.caption)
                .foregroundColor(.secondary)

            Button {
                viewModel.confirmDelete(network)
            } label: {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
            .help("Remove network")
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

// MARK: - Create Network Sheet

struct CreateNetworkView: View {
    @Bindable var viewModel: NetworkViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Create Network")
                    .font(.title2).bold()
                Spacer()
                if !viewModel.isCreating {
                    Button("Close") { dismiss() }
                        .keyboardShortcut(.escape)
                }
            }

            if let createdName = viewModel.createForm.createdNetworkName {
                // Success
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.green)
                    Text("Network Created")
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
        .frame(width: 500)
    }

    @ViewBuilder
    private var formContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Name
            VStack(alignment: .leading, spacing: 4) {
                Text("Network Name *").font(.headline)
                TextField("e.g. my-network", text: $viewModel.createForm.name)
                    .textFieldStyle(.roundedBorder)
                    .font(.body.monospaced())
            }

            // Plugin
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 0) {
                    Text("Plugin").font(.headline)
                    Text(" (optional)").foregroundColor(.secondary).font(.headline)
                }
                Picker("", selection: $viewModel.createForm.plugin) {
                    Text("Default (vmnet)").tag("")
                    Text("container-network-vmnet").tag("container-network-vmnet")
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()
            }

            // Subnets
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 0) {
                    Text("Subnet").font(.headline)
                    Text(" (optional)").foregroundColor(.secondary).font(.headline)
                }
                TextField("e.g. 10.0.0.0/24", text: $viewModel.createForm.subnet)
                    .textFieldStyle(.roundedBorder)
                    .font(.body.monospaced())
                HStack(spacing: 0) {
                    Text("IPv6 Subnet").font(.headline)
                    Text(" (optional)").foregroundColor(.secondary).font(.headline)
                }
                TextField("e.g. fd00::/64", text: $viewModel.createForm.subnetV6)
                    .textFieldStyle(.roundedBorder)
                    .font(.body.monospaced())
            }

            // Internal
            Toggle("Internal network (no external access)", isOn: $viewModel.createForm.internalNetwork)

            Divider()

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

            // Options
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 0) {
                    Text("Options").font(.headline)
                    Text(" (optional)").foregroundColor(.secondary).font(.headline)
                }
                ForEach(viewModel.createForm.options.indices, id: \.self) { index in
                    HStack(spacing: 8) {
                        TextField("key", text: $viewModel.createForm.options[index].key)
                            .textFieldStyle(.roundedBorder)
                            .font(.caption.monospaced())
                            .frame(width: 120)
                        Text("=").foregroundColor(.secondary)
                        TextField("value", text: $viewModel.createForm.options[index].value)
                            .textFieldStyle(.roundedBorder)
                            .font(.caption.monospaced())
                        Button(role: .destructive) {
                            viewModel.createForm.options.remove(at: index)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }
                Button {
                    viewModel.createForm.options.append(KeyValueEntry())
                } label: {
                    Label("Add Option", systemImage: "plus")
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
                    Task { await viewModel.createNetwork() }
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

// MARK: - Network Detail View (for NavigationSplitView detail column)

struct NetworkDetailView: View {
    let network: ContainerNetwork
    let viewModel: NetworkViewModel
    let onDelete: (() -> Void)?

    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var showRecreateSheet = false
    @State private var recreateName = ""
    @State private var recreateSubnet = ""
    @State private var isRecreating = false
    @State private var recreateError: String?

    init(network: ContainerNetwork, viewModel: NetworkViewModel, onDelete: (() -> Void)? = nil) {
        self.network = network
        self.viewModel = viewModel
        self.onDelete = onDelete
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection
                Divider()
                infoSection
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
        .alert("Delete Network", isPresented: $showDeleteConfirmation) {
            Button(role: .destructive) {
                Task { await performDelete() }
            } label: {
                Text("Delete \"\(network.name)\"")
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete \"\(network.name)\"? This cannot be undone.")
        }
    }

    private var headerSection: some View {
        HStack {
            Image(systemName: "network")
                .font(.title)
                .foregroundColor(.mint)

            VStack(alignment: .leading, spacing: 4) {
                Text(network.name)
                    .font(.largeTitle).bold()
                Text(network.driver)
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
                    Text("ID").foregroundColor(.secondary)
                    Text(network.id)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                }
                GridRow {
                    Text("Name").foregroundColor(.secondary)
                    Text(network.name)
                        .font(.body.monospaced())
                        .textSelection(.enabled)
                }
                GridRow {
                    Text("Driver").foregroundColor(.secondary)
                    Text(network.driver)
                }
                if let subnet = network.subnet, !subnet.isEmpty {
                    GridRow {
                        Text("Subnet").foregroundColor(.secondary)
                        Text(subnet).font(.caption.monospaced())
                    }
                }
                if let gateway = network.gateway, !gateway.isEmpty {
                    GridRow {
                        Text("Gateway").foregroundColor(.secondary)
                        Text(gateway).font(.caption.monospaced())
                    }
                }
                if !network.containers.isEmpty {
                    GridRow {
                        Text("Containers").foregroundColor(.secondary)
                        Text("\(network.containers.count) attached")
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
        recreateName = network.name
        recreateSubnet = network.subnet ?? ""
        recreateError = nil
        showRecreateSheet = true
    }

    private var recreateSheet: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Modify Network")
                    .font(.title2).bold()
                Spacer()
                if !isRecreating {
                    Button("Close") { showRecreateSheet = false }
                        .keyboardShortcut(.escape)
                }
            }

            Text("This will create a new network and delete \"\(network.name)\".")
                .font(.callout).foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Name *").font(.headline)
                    TextField("Network name", text: $recreateName)
                        .textFieldStyle(.roundedBorder)
                        .font(.body.monospaced())
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 0) {
                        Text("Subnet").font(.headline)
                        Text(" (optional)").foregroundColor(.secondary).font(.headline)
                    }
                    TextField("e.g. 10.0.0.0/24", text: $recreateSubnet)
                        .textFieldStyle(.roundedBorder)
                        .font(.body.monospaced())
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
            let options = NetworkCreateOptions(
                name: recreateName,
                subnet: recreateSubnet.isEmpty ? nil : recreateSubnet
            )
            _ = try await viewModel.createNetwork(options: options)
            try await viewModel.removeNetwork(id: network.id)
            onDelete?()
            showRecreateSheet = false
        } catch {
            recreateError = error.localizedDescription
        }
        isRecreating = false
    }

    private func performDelete() async {
        isDeleting = true
        do {
            try await viewModel.removeNetwork(id: network.id)
            onDelete?()
            await viewModel.refresh()
        } catch {
            // Error handled by the ViewModel's state
        }
        isDeleting = false
    }
}
