import SwiftUI

// MARK: - ViewModel

@MainActor
@Observable
final class SystemViewModel {
    var state: ViewState<SystemInfo> = .loading
    var errorMessage: String?
    var statusText: String = ""
    var isStarting = false
    var isStopping = false

    // Logs
    var logText: String = ""
    var isFetchingLogs = false
    var logTailDuration: String = "5m"

    // Prune
    var isPruningContainers = false
    var isPruningImages = false
    var isPruningVolumes = false
    var isPruningNetworks = false
    var pruneResult: String?
    var showPruneResult = false

    private let repository: SystemRepositoryProtocol

    init(repository: SystemRepositoryProtocol) {
        self.repository = repository
    }

    func load() async {
        state = .loading
        await refresh()
    }

    func refresh() async {
        do {
            let info = try await repository.systemInfo()
            statusText = info.statusRaw
            state = .loaded(info)
        } catch {
            state = .error(error.localizedDescription)
            errorMessage = error.localizedDescription
        }
    }

    func startServices() async {
        isStarting = true
        errorMessage = nil
        do {
            try await repository.startServices()
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
        isStarting = false
    }

    func stopServices() async {
        isStopping = true
        errorMessage = nil
        do {
            try await repository.stopServices()
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
        isStopping = false
    }

    func fetchLogs() async {
        isFetchingLogs = true
        do {
            logText = try await repository.systemLogs(tail: logTailDuration)
        } catch {
            logText = "Error fetching logs: \(error.localizedDescription)"
        }
        isFetchingLogs = false
    }

    func prune(type: PruneType) async {
        let (_, result) = switch type {
        case .containers: (isPruningContainers, "Containers")
        case .images: (isPruningImages, "Images")
        case .volumes: (isPruningVolumes, "Volumes")
        case .networks: (isPruningNetworks, "Networks")
        }

        do {
            let count: Int = switch type {
            case .containers: try await repository.pruneContainers()
            case .images: try await repository.pruneImages()
            case .volumes: try await repository.pruneVolumes()
            case .networks: try await repository.pruneNetworks()
            }
            pruneResult = "Reclaimed \(count) \(result.lowercased())."
            showPruneResult = true
            await refresh()
        } catch {
            errorMessage = "Prune \(result) failed: \(error.localizedDescription)"
        }

        switch type {
        case .containers: isPruningContainers = false
        case .images: isPruningImages = false
        case .volumes: isPruningVolumes = false
        case .networks: isPruningNetworks = false
        }
    }

    enum PruneType: String, CaseIterable, Identifiable {
        case containers, images, volumes, networks
        var id: String { rawValue }
        var icon: String {
            switch self {
            case .containers: return "cube.box"
            case .images: return "square.stack.3d.up"
            case .volumes: return "externaldrive"
            case .networks: return "network"
            }
        }
    }
}

// MARK: - System Screen

struct SystemScreen: View {
    @State private var viewModel: SystemViewModel
    @State private var showLogs = false

    init(repository: SystemRepositoryProtocol) {
        self._viewModel = State(wrappedValue: SystemViewModel(repository: repository))
    }

    var body: some View {
        Group {
            switch viewModel.state {
            case .loading:
                LoadingView("Loading system info...")
            case .loaded(let info):
                SystemInfoView(info: info, viewModel: viewModel, showLogs: $showLogs)
            case .error(let message):
                SystemErrorView(message: message, viewModel: viewModel)
            case .empty(let message):
                EmptyStateView(message, systemImage: "gearshape")
            }
        }
        .task { await viewModel.load() }
        .toolbar {
            ToolbarItemGroup {
                Button {
                    showLogs = true
                } label: {
                    Label("Logs", systemImage: "doc.text")
                }
                .help("View system logs")

                Button {
                    Task { await viewModel.refresh() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .help("Refresh system info")
            }
        }
        .sheet(isPresented: $showLogs) {
            LogsView(viewModel: viewModel)
        }
        .alert("Prune Complete", isPresented: $viewModel.showPruneResult) {
            Button("OK") { viewModel.pruneResult = nil }
        } message: {
            Text(viewModel.pruneResult ?? "")
        }
    }
}

// MARK: - Error View

struct SystemErrorView: View {
    let message: String
    let viewModel: SystemViewModel

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 36))
                .foregroundColor(.orange)

            Text("Container Services Not Running")
                .font(.title2).bold()

            Text("Start the container platform services to access system information.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            if !message.isEmpty {
                Text(message)
                    .font(.caption.monospaced())
                    .foregroundColor(.red)
            }

            HStack(spacing: 12) {
                Button {
                    Task { await viewModel.startServices() }
                } label: {
                    Label("Start Services", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isStarting)
                .overlay {
                    if viewModel.isStarting { ProgressView().scaleEffect(0.6) }
                }

                Button {
                    Task { await viewModel.load() }
                } label: {
                    Text("Retry")
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isStarting)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - System Info View

struct SystemInfoView: View {
    let info: SystemInfo
    let viewModel: SystemViewModel
    @Binding var showLogs: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                serviceSection
                Divider()
                summarySection
                Divider()
                diskUsageSection
                Divider()
                serverInfoSection
                Divider()
                pruneSection
                Divider()
                statusSection
            }
            .padding()
        }
        .frame(minWidth: 500)
    }

    // MARK: - Service Control

    private var serviceSection: some View {
        GroupBox("Service Control") {
            HStack(spacing: 16) {
                Button {
                    Task { await viewModel.startServices() }
                } label: {
                    Label("Start", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isStarting || viewModel.isStopping)
                .overlay {
                    if viewModel.isStarting { ProgressView().scaleEffect(0.6) }
                }

                Button(role: .destructive) {
                    Task { await viewModel.stopServices() }
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isStarting || viewModel.isStopping)
                .overlay {
                    if viewModel.isStopping { ProgressView().scaleEffect(0.6) }
                }

                Spacer()

                StatusBadge(
                    viewModel.statusText.contains("running") ? "Running" : "Stopped",
                    color: viewModel.statusText.contains("running") ? .green : .red
                )
            }
            .padding(.vertical, 4)

            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }
        }
    }

    // MARK: - Summary

    private var summarySection: some View {
        LazyVGrid(columns: [.init(.adaptive(minimum: 130))], spacing: 12) {
            SummaryCard(title: "Containers", value: "\(info.containers)", icon: "cube.box", color: .indigo,
                        subtitle: "\(info.running) running, \(info.stopped) stopped")
            SummaryCard(title: "Images", value: "\(info.images)", icon: "square.stack.3d.up", color: .purple,
                        subtitle: info.imageSize > 0 ? formatBytes(info.imageSize) : "")
            SummaryCard(title: "Volumes", value: "\(info.volumes)", icon: "externaldrive", color: .cyan,
                        subtitle: info.volumeSize > 0 ? formatBytes(info.volumeSize) : "")
        }
    }

    // MARK: - Disk Usage

    private var diskUsageSection: some View {
        GroupBox("Disk Usage") {
            VStack(spacing: 16) {
                DiskUsageRow(
                    title: "Containers",
                    icon: "cube.box",
                    color: .indigo,
                    total: info.containers,
                    active: info.containerActive,
                    size: info.containerSize,
                    reclaimable: info.containerReclaimable
                )
                DiskUsageRow(
                    title: "Images",
                    icon: "square.stack.3d.up",
                    color: .purple,
                    total: info.images,
                    active: info.imageActive,
                    size: info.imageSize,
                    reclaimable: info.imageReclaimable
                )
                DiskUsageRow(
                    title: "Volumes",
                    icon: "externaldrive",
                    color: .cyan,
                    total: info.volumes,
                    active: info.volumeActive,
                    size: info.volumeSize,
                    reclaimable: info.volumeReclaimable
                )
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Server Info

    private var serverInfoSection: some View {
        GroupBox("Server") {
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                GridRow { Text("Status").foregroundColor(.secondary); StatusBadge(info.statusRaw.contains("running") ? "Running" : "Stopped") }
                GridRow { Text("API Server").foregroundColor(.secondary); Text(info.apiServerVersion).font(.caption.monospaced()) }
                GridRow { Text("CLI Version").foregroundColor(.secondary); Text(info.cliVersion).font(.caption.monospaced()) }
                GridRow { Text("Server Version").foregroundColor(.secondary); Text(info.serverVersion).font(.caption.monospaced()) }
                GridRow { Text("OS").foregroundColor(.secondary); Text(info.osType) }
                GridRow { Text("Architecture").foregroundColor(.secondary); Text(info.architecture) }
                GridRow { Text("CPUs").foregroundColor(.secondary); Text("\(info.cpus)") }
                GridRow { Text("Memory").foregroundColor(.secondary); Text(formatBytes(info.totalMemory)) }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Prune

    private var pruneSection: some View {
        GroupBox("Prune") {
            VStack(spacing: 12) {
                Text("Remove unused resources to reclaim disk space.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                LazyVGrid(columns: [.init(.adaptive(minimum: 160))], spacing: 8) {
                    pruneButton(type: .containers, isPruning: viewModel.isPruningContainers)
                    pruneButton(type: .images, isPruning: viewModel.isPruningImages)
                    pruneButton(type: .volumes, isPruning: viewModel.isPruningVolumes)
                    pruneButton(type: .networks, isPruning: viewModel.isPruningNetworks)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func pruneButton(type: SystemViewModel.PruneType, isPruning: Bool) -> some View {
        Button {
            Task { await viewModel.prune(type: type) }
        } label: {
            HStack {
                if isPruning {
                    ProgressView().scaleEffect(0.7)
                } else {
                    Image(systemName: type.icon)
                }
                Text(type.rawValue.capitalized)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .disabled(isPruning)
    }

    // MARK: - Status Raw

    private var statusSection: some View {
        GroupBox("Status Output") {
            ScrollView {
                Text(viewModel.statusText)
                    .font(.caption2.monospaced())
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 100)
            .background(Color(nsColor: .textBackgroundColor))
            .cornerRadius(6)
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Summary Card

struct SummaryCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    var subtitle: String = ""

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            VStack(alignment: .leading) {
                Text(value)
                    .font(.title2).bold()
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(color.opacity(0.06))
        .cornerRadius(10)
    }
}

// MARK: - Disk Usage Row

struct DiskUsageRow: View {
    let title: String
    let icon: String
    let color: Color
    let total: Int
    let active: Int
    let size: Int64
    let reclaimable: Int64

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon).foregroundColor(color)
                Text(title).font(.subheadline).bold()
                Spacer()
                if total > 0 {
                    Text("\(active) active / \(total) total")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                if size > 0 {
                    Text(formatBytes(size))
                        .font(.caption.monospaced())
                        .foregroundColor(.secondary)
                }
            }

            if total > 0 {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(nsColor: .controlBackgroundColor))
                            .frame(height: 8)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(color)
                            .frame(width: max(CGFloat(active) / CGFloat(total) * geo.size.width, 2), height: 8)
                    }
                }
                .frame(height: 8)
            }

            if reclaimable > 0 {
                HStack {
                    Text("Reclaimable:")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(formatBytes(reclaimable))
                        .font(.caption2.monospaced())
                        .foregroundColor(.orange)
                }
            }
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Logs Sheet

struct LogsView: View {
    @Bindable var viewModel: SystemViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("System Logs")
                    .font(.title2).bold()
                Spacer()

                Picker("Duration", selection: $viewModel.logTailDuration) {
                    Text("1m").tag("1m")
                    Text("5m").tag("5m")
                    Text("30m").tag("30m")
                    Text("1h").tag("1h")
                    Text("6h").tag("6h")
                }
                .pickerStyle(.menu)
                .frame(width: 80)

                Button {
                    Task { await viewModel.fetchLogs() }
                } label: {
                    if viewModel.isFetchingLogs {
                        ProgressView().scaleEffect(0.7).frame(width: 16)
                    } else {
                        Label("Fetch", systemImage: "arrow.clockwise")
                    }
                }
                .disabled(viewModel.isFetchingLogs)

                Button("Close") { dismiss() }
                    .keyboardShortcut(.escape)
            }

            ScrollViewReader { proxy in
                ScrollView {
                    Text(viewModel.logText.isEmpty ? "No logs. Tap Fetch to load." : viewModel.logText)
                        .font(.caption2.monospaced())
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .id("logBottom")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .textBackgroundColor))
                .cornerRadius(8)
            }
        }
        .padding()
        .frame(width: 700, height: 500)
        .task { await viewModel.fetchLogs() }
    }
}
