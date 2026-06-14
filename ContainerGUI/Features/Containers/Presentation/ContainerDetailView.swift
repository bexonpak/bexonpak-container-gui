import SwiftUI

struct ContainerDetailView: View {
    let containerId: String
    let viewModel: ContainerViewModel
    let onDelete: (() -> Void)?

    @State private var showRecreateSheet = false
    @State private var recreateImage = ""
    @State private var recreateName = ""
    @State private var recreateCommand = ""
    @State private var recreatePorts: [PortMappingEntry] = []
    @State private var isRecreating = false
    @State private var recreateError: String?
    @State private var showDeleteConfirmation = false

    private var container: Container? {
        if case .loaded(let containers) = viewModel.state {
            return containers.first { $0.id == containerId }
        }
        return nil
    }

    init(containerId: String, viewModel: ContainerViewModel, onDelete: (() -> Void)? = nil) {
        self.containerId = containerId
        self.viewModel = viewModel
        self.onDelete = onDelete
    }

    var body: some View {
        Group {
            if let container {
                detailContent(container: container)
            } else {
                EmptyStateView("Select a container", systemImage: "cube.box", description: "Choose a container from the list")
            }
        }
        .task { await viewModel.loadInspect(id: containerId) }
        .onChange(of: containerId) { _, newId in
            Task { await viewModel.loadInspect(id: newId) }
        }
    }

    private func detailContent(container: Container) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection(container: container)
                Divider()
                actionsSection(container: container)
                Divider()
                infoSection(container: container)
                Divider()
                inspectSection
                Divider()
                
            }
            .padding()
        }
        .sheet(isPresented: $showRecreateSheet) {
            recreateSheet
                .onDisappear {
                    Task { await viewModel.refresh() }
                }
        }
        .alert("Delete Container", isPresented: $showDeleteConfirmation) {
            Button(role: .destructive) {
                Task {
                    try? await viewModel.removeContainerDirect(id: container.id)
                    onDelete?()
                }
            } label: {
                Text("Delete \"\(container.name)\"")
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete \"\(container.name)\"? This cannot be undone.")
        }
    }

    // MARK: - Header

    private func headerSection(container: Container) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(container.name)
                    .font(.largeTitle).bold()
                Text("ID: \(container.id)")
                    .font(.caption.monospaced())
                    .foregroundColor(.secondary)
            }
            Spacer()
            StatusBadge(container.status.displayName)
        }
    }

    // MARK: - Info

    private func infoSection(container: Container) -> some View {
        GroupBox("Info") {
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                GridRow {
                    Text("Image").foregroundColor(.secondary)
                    Text(container.image)
                        .textSelection(.enabled)
                        .lineLimit(nil)
                }
                GridRow {
                    Text("Status").foregroundColor(.secondary)
                    Text(container.status.displayName)
                        .lineLimit(nil)
                }
                if let ip = container.containerIP {
                    GridRow {
                        Text("IP Address").foregroundColor(.secondary)
                        if let url = URL(string: "http://\(ip)") {
                            Link(destination: url) {
                                HStack(spacing: 4) {
                                    Text(ip)
                                        .font(.caption.monospaced())
                                    Image(systemName: "arrow.up.forward.app")
                                        .font(.caption2)
                                        .foregroundColor(.accentColor)
                                }
                            }
                        }
                    }
                }
                if let started = container.startedAt {
                    GridRow {
                        Text("Started").foregroundColor(.secondary)
                        Text(started.formatted(date: .long, time: .shortened))
                            .lineLimit(nil)
                    }
                }
                GridRow {
                    Text("Created").foregroundColor(.secondary)
                    Text(container.created.formatted(date: .long, time: .shortened))
                        .lineLimit(nil)
                }
                GridRow {
                    Text("Platform").foregroundColor(.secondary)
                    Text(container.platform.isEmpty ? "—" : container.platform)
                        .lineLimit(nil)
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Inspect

    @ViewBuilder
    private var inspectSection: some View {
        if viewModel.isLoadingInspect {
            loadingInspectSection
        } else if let error = viewModel.inspectError {
            errorInspectSection(error)
        } else if let info = viewModel.inspectInfo {
            GroupBox("Inspect") {
                VStack(alignment: .leading, spacing: 12) {
                    // Image
                    detailRow(label: "Image", value: info.image)

                    // Image Digest
                    if !info.imageDigest.isEmpty {
                        detailRow(label: "Digest", value: info.imageDigest, mono: true)
                    }

                    // Platform
                    if !info.architecture.isEmpty {
                        detailRow(label: "Platform", value: "\(info.architecture) / \(info.os)")
                    }

                    // Resources
                    if info.cpus > 0 {
                        detailRow(label: "CPUs", value: "\(info.cpus)")
                    }
                    if info.memoryBytes > 0 {
                        detailRow(label: "Memory", value: formatBytes(info.memoryBytes))
                    }

                    // Runtime
                    if !info.runtimeHandler.isEmpty {
                        detailRow(label: "Runtime", value: info.runtimeHandler)
                    }
                    if let signal = info.stopSignal {
                        detailRow(label: "Stop Signal", value: signal)
                    }

                    // Entrypoint / Executable
                    if let entrypoint = info.entrypoint, !entrypoint.isEmpty {
                        detailRow(label: "Entrypoint", value: entrypoint, mono: true)
                    }
                    if let exec = info.executable {
                        detailRow(label: "Executable", value: exec, mono: true)
                    }
                    if let wd = info.workingDir {
                        detailRow(label: "Workdir", value: wd, mono: true)
                    }

                    // Mounts
                    if !info.mounts.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Mounts").font(.caption).foregroundColor(.secondary)
                            ForEach(info.mounts, id: \.destination) { mount in
                                HStack(spacing: 4) {
                                    Text(mount.type)
                                        .font(.caption2.monospaced())
                                        .foregroundColor(.accentColor)
                                    Text("\(mount.source) → \(mount.destination)")
                                        .font(.caption2.monospaced())
                                        .textSelection(.enabled)
                                }
                            }
                        }
                    }

                    // Networks
                    if !info.networks.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Networks").font(.caption).foregroundColor(.secondary)
                            ForEach(info.networks, id: \.network) { net in
                                HStack(spacing: 4) {
                                    Text(net.network)
                                        .font(.caption.monospaced())
                                        .foregroundColor(.accentColor)
                                    if let ip = net.ipAddress {
                                        Text(ip)
                                            .font(.caption2.monospaced())
                                            .textSelection(.enabled)
                                    }
                                }
                            }
                        }
                    }

                    // Environment
                    if !info.env.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Environment").font(.caption).foregroundColor(.secondary)
                            ForEach(Array(info.env.enumerated()), id: \.offset) { _, line in
                                Text(line)
                                    .font(.caption2.monospaced())
                                    .textSelection(.enabled)
                            }
                        }
                    }

                    // Labels
                    if !info.labels.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Labels").font(.caption).foregroundColor(.secondary)
                            ForEach(Array(info.labels.sorted(by: { $0.key < $1.key })), id: \.key) { key, value in
                                HStack(alignment: .top, spacing: 4) {
                                    Text(key)
                                        .font(.caption.monospaced())
                                        .foregroundColor(.accentColor)
                                    Text(value)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }

                    // Flags
                    HStack(spacing: 16) {
                        flagChip("Read-only", enabled: info.readOnly)
                        flagChip("Rosetta", enabled: info.rosetta)
                        flagChip("SSH", enabled: info.ssh)
                        flagChip("Virtualization", enabled: info.virtualization)
                        flagChip("Init", enabled: info.useInit)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var loadingInspectSection: some View {
        GroupBox("Inspect") {
            HStack(spacing: 8) {
                ProgressView().scaleEffect(0.8)
                Text("Loading container details...")
                    .foregroundColor(.secondary).font(.caption)
            }
            .padding(.vertical, 4)
        }
    }

    private func errorInspectSection(_ error: String) -> some View {
        GroupBox("Inspect") {
            Text(error)
                .foregroundColor(.red).font(.caption)
                .padding(.vertical, 4)
        }
    }

    private func detailRow(label: String, value: String, mono: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption).foregroundColor(.secondary)
            Text(value)
                .font(mono ? .caption.monospaced() : .caption)
                .textSelection(.enabled)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func flagChip(_ label: String, enabled: Bool) -> some View {
        HStack(spacing: 3) {
            Circle().fill(enabled ? Color.green : Color.gray.opacity(0.3)).frame(width: 5, height: 5)
            Text(label)
                .font(.caption2)
                .foregroundColor(enabled ? .primary : .secondary)
        }
    }

    // MARK: - Ports

    private func portsSection(container: Container) -> some View {
        GroupBox("Ports") {
            if container.ports.isEmpty {
                Text("No port mappings")
                    .foregroundColor(.secondary)
                    .padding(.vertical, 4)
            } else {
                ForEach(container.ports, id: \.containerPort) { port in
                    HStack {
                        Text("\(port.hostPort) → \(port.containerPort)")
                            .font(.body.monospaced())
                        Spacer()
                        Text(port.protocolType.uppercased())
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func actionsSection(container: Container) -> some View {
        GroupBox("Actions") {
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    actionButton("Start", systemImage: "play.fill", color: .green,
                                 isLoading: viewModel.isStartingContainer) {
                        Task { await viewModel.startContainer(container.id) }
                    }
                    actionButton("Stop", systemImage: "stop.fill", color: .red,
                                 isLoading: viewModel.isStoppingContainer) {
                        Task { await viewModel.stopContainer(container.id) }
                    }
                }

                HStack(spacing: 12) {
                    actionButton("Restart", systemImage: "arrow.counterclockwise", color: .blue,
                                 isLoading: viewModel.isRestartingContainer) {
                        Task { await viewModel.restartContainer(container.id) }
                    }
                    actionButton("Kill", systemImage: "xmark.circle", color: .red,
                                 isLoading: viewModel.isKillingContainer) {
                        Task { await viewModel.killContainer(container.id) }
                    }
                }

                Divider()

                HStack(spacing: 12) {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)

                    Button {
                        openRecreateSheet(container: container)
                    } label: {
                        Label("Modify", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Recreate Sheet

    private var recreateSheet: some View { /* ... same as before ... */
        VStack(spacing: 16) {
            HStack {
                Text("Modify Container")
                    .font(.title2).bold()
                Spacer()
                if !isRecreating {
                    Button("Close") { showRecreateSheet = false }
                        .keyboardShortcut(.escape)
                }
            }
            Text("This will create a new container and delete the current one.")
                .font(.callout).foregroundColor(.secondary)
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Image *").font(.headline)
                    TextField("Image", text: $recreateImage)
                        .textFieldStyle(.roundedBorder).font(.body.monospaced())
                }
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 0) {
                        Text("Name").font(.headline)
                        Text(" (optional)").foregroundColor(.secondary).font(.headline)
                    }
                    TextField("Container name", text: $recreateName)
                        .textFieldStyle(.roundedBorder)
                }
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 0) {
                        Text("Command").font(.headline)
                        Text(" (optional)").foregroundColor(.secondary).font(.headline)
                    }
                    TextField("e.g. nginx -g 'daemon off;'", text: $recreateCommand)
                        .textFieldStyle(.roundedBorder).font(.body.monospaced())
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Port Mappings").font(.headline)
                    ForEach(recreatePorts.indices, id: \.self) { index in
                        HStack(spacing: 8) {
                            TextField("Host", value: $recreatePorts[index].hostPort, format: .number)
                                .textFieldStyle(.roundedBorder).frame(width: 70)
                            Text(":").foregroundColor(.secondary)
                            TextField("Container", value: $recreatePorts[index].containerPort, format: .number)
                                .textFieldStyle(.roundedBorder).frame(width: 70)
                            Picker("", selection: $recreatePorts[index].protocolType) {
                                Text("tcp").tag("tcp"); Text("udp").tag("udp")
                            }
                            .pickerStyle(.menu).frame(width: 60).labelsHidden()
                            Button(role: .destructive) { recreatePorts.remove(at: index) } label: {
                                Image(systemName: "minus.circle.fill").foregroundColor(.red)
                            }.buttonStyle(.plain)
                        }
                    }
                    Button { recreatePorts.append(PortMappingEntry()) } label: {
                        Label("Add Port", systemImage: "plus").font(.caption)
                    }
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
                .disabled(isRecreating || recreateImage.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding().frame(width: 480)
    }

    private func openRecreateSheet(container: Container) {
        recreateImage = container.image
        recreateName = container.name
        recreateCommand = ""
        recreatePorts = container.ports.map {
            PortMappingEntry(hostPort: $0.hostPort, containerPort: $0.containerPort, protocolType: $0.protocolType)
        }
        recreateError = nil
        showRecreateSheet = true
    }

    private func performRecreate() async {
        isRecreating = true
        recreateError = nil
        do {
            let options = ContainerCreateOptions(
                image: recreateImage,
                command: recreateCommand.isEmpty ? [] : recreateCommand.split(separator: " ").map(String.init),
                name: recreateName.isEmpty ? nil : recreateName,
                publish: recreatePorts.filter { $0.containerPort > 0 }.map {
                    PortPublishSpec(hostPort: $0.hostPort, containerPort: $0.containerPort, protocol: $0.protocolType.isEmpty ? nil : $0.protocolType)
                }
            )
            _ = try await viewModel.createContainer(options: options)
            try await viewModel.removeContainerDirect(id: containerId)
            onDelete?()
            showRecreateSheet = false
        } catch {
            recreateError = error.localizedDescription
        }
        isRecreating = false
    }

    // MARK: - Helpers

    private func actionButton(_ title: String, systemImage: String, color: Color, isLoading: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .frame(height: 20)
                } else {
                    Image(systemName: systemImage).font(.title3)
                }
                Text(title).font(.caption)
            }
            .frame(minWidth: 60)
            .padding(.vertical, 8).padding(.horizontal, 4)
            .background(color.opacity(0.1))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: bytes)
    }
}
