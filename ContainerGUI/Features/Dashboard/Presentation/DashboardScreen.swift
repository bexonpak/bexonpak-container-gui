import SwiftUI

// MARK: - ViewModel

@MainActor
@Observable
final class DashboardViewModel {
    var state: ViewState<SystemInfo> = .loading
    var isStarting = false
    var isStopping = false
    var errorMessage: String?

    // Actual counts from entity list APIs (not system df aggregates)
    var actualImageCount = 0

    private let systemRepository: SystemRepositoryProtocol
    private let imageRepository: ImageRepositoryProtocol?

    init(systemRepository: SystemRepositoryProtocol, imageRepository: ImageRepositoryProtocol? = nil) {
        self.systemRepository = systemRepository
        self.imageRepository = imageRepository
    }

    func load() async {
        state = .loading
        await refresh()
    }

    func refresh() async {
        do {
            async let infoTask = systemRepository.systemInfo()
            async let imageCountTask = loadActualImageCount()

            let info = try await infoTask
            actualImageCount = await imageCountTask
            state = .loaded(info)
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    private func loadActualImageCount() async -> Int {
        guard let imageRepository else { return 0 }
        do {
            return try await imageRepository.listImages().count
        } catch {
            return 0
        }
    }

    func startServices() async {
        isStarting = true
        errorMessage = nil
        do {
            try await systemRepository.startServices()
            await refresh()
        } catch {
            state = .error(error.localizedDescription)
            errorMessage = error.localizedDescription
        }
        isStarting = false
    }

    func stopServices() async {
        isStopping = true
        errorMessage = nil
        do {
            try await systemRepository.stopServices()
            await refresh()
        } catch {
            state = .error(error.localizedDescription)
            errorMessage = error.localizedDescription
        }
        isStopping = false
    }
}

// MARK: - Dashboard Screen

struct DashboardScreen: View {
    @State private var viewModel: DashboardViewModel
    let onNavigate: ((NavigationCategory) -> Void)?

    init(systemRepository: SystemRepositoryProtocol, imageRepository: ImageRepositoryProtocol? = nil, onNavigate: ((NavigationCategory) -> Void)? = nil) {
        self._viewModel = State(wrappedValue: DashboardViewModel(systemRepository: systemRepository, imageRepository: imageRepository))
        self.onNavigate = onNavigate
    }

    var body: some View {
        Group {
            switch viewModel.state {
            case .loading:
                LoadingView("Loading dashboard...")
            case .loaded(let info):
                DashboardContentView(info: info, viewModel: viewModel, onNavigate: onNavigate)
            case .error(let message):
                DashboardErrorView(message: message, viewModel: viewModel)
            case .empty:
                EmptyStateView("No data", systemImage: "square.grid.2x2")
            }
        }
        .task { await viewModel.load() }
        .toolbar {
            ToolbarItemGroup {
                Button {
                    Task { await viewModel.refresh() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .help("Refresh dashboard")
            }
        }
    }
}

// MARK: - Error View

struct DashboardErrorView: View {
    let message: String
    let viewModel: DashboardViewModel

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundColor(.orange)

            Text("Container Services Not Running")
                .font(.title2).bold()

            Text("The container platform services need to be started to use this app.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .frame(maxWidth: 360)

            if !message.isEmpty {
                Text(message)
                    .font(.caption.monospaced())
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }

            Button {
                Task { await viewModel.startServices() }
            } label: {
                if viewModel.isStarting {
                    ProgressView().scaleEffect(0.8)
                }
                Label("Start Services", systemImage: "play.fill")
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isStarting)

            Button {
                Task { await viewModel.load() }
            } label: {
                Text("Retry")
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.isStarting)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Dashboard Content

struct DashboardContentView: View {
    let info: SystemInfo
    let viewModel: DashboardViewModel
    let onNavigate: ((NavigationCategory) -> Void)?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Container Platform")
                            .font(.largeTitle).bold()
                        Text("Overview")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    StatusBadge(
                        info.statusRaw.contains("running") ? "Running" : "Stopped",
                        color: info.statusRaw.contains("running") ? .green : .red
                    )
                }

                // Service Control
                serviceControlSection

                Divider()

                // Summary cards
                summarySection

                Divider()

                // Disk usage
                diskUsageSection

                Divider()

                // Quick actions
                quickActionsSection

                Divider()

                // System info
                systemInfoSection
            }
            .padding()
        }
        .frame(minWidth: 500)
    }

    // MARK: - Service Control

    private var serviceControlSection: some View {
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

                if viewModel.isStarting || viewModel.isStopping {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .padding(.vertical, 4)

            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }
        }
    }

    // MARK: - Summary Cards

    private var summarySection: some View {
        LazyVGrid(columns: [.init(.adaptive(minimum: 180))], spacing: 16) {
            DashboardCard(
                title: "Containers",
                primaryValue: "\(info.running)",
                primaryLabel: "running",
                secondaryValue: "\(info.containers)",
                secondaryLabel: "total",
                icon: "cube.box.fill",
                color: .indigo
            )
            .onTapGesture { onNavigate?(.containers) }

            DashboardCard(
                title: "Images",
                primaryValue: "\(viewModel.actualImageCount)",
                primaryLabel: "available",
                secondaryValue: info.imageSize > 0 ? formatBytes(info.imageSize) : "—",
                secondaryLabel: "disk used",
                icon: "square.stack.3d.up",
                color: .purple
            )
            .onTapGesture { onNavigate?(.images) }

            DashboardCard(
                title: "Volumes",
                primaryValue: "\(info.volumes)",
                primaryLabel: "total",
                secondaryValue: info.volumeSize > 0 ? formatBytes(info.volumeSize) : "—",
                secondaryLabel: "disk used",
                icon: "externaldrive",
                color: .cyan
            )
            .onTapGesture { onNavigate?(.volumes) }

            DashboardCard(
                title: "Networks",
                primaryValue: "\(info.networks)",
                primaryLabel: "total",
                secondaryValue: "—",
                secondaryLabel: "",
                icon: "network",
                color: .mint
            )
            .onTapGesture { onNavigate?(.networks) }

            if info.cpus > 0 || info.totalMemory > 0 {
                DashboardCard(
                    title: "Host",
                    primaryValue: "\(info.cpus) CPUs",
                    primaryLabel: info.architecture,
                    secondaryValue: formatBytes(info.totalMemory),
                    secondaryLabel: "memory",
                    icon: "desktopcomputer",
                    color: .blue
                )
                .onTapGesture { onNavigate?(.machine) }
            }
        }
    }

    // MARK: - Disk Usage

    private var diskUsageSection: some View {
        GroupBox("Disk Usage") {
            VStack(spacing: 12) {
                DiskUsageMiniRow(
                    title: "Containers",
                    icon: "cube.box",
                    color: .indigo,
                    total: info.containers,
                    active: info.containerActive,
                    size: info.containerSize
                )
                DiskUsageMiniRow(
                    title: "Images",
                    icon: "square.stack.3d.up",
                    color: .purple,
                    total: info.images,
                    active: info.imageActive,
                    size: info.imageSize
                )
                DiskUsageMiniRow(
                    title: "Volumes",
                    icon: "externaldrive",
                    color: .cyan,
                    total: info.volumes,
                    active: info.volumeActive,
                    size: info.volumeSize
                )
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Quick Actions

    private var quickActionsSection: some View {
        GroupBox("Quick Actions") {
            LazyVGrid(columns: [.init(.adaptive(minimum: 160))], spacing: 8) {
                QuickActionButton(title: "Containers", icon: "cube.box", color: .indigo) {
                    onNavigate?(.containers)
                }
                QuickActionButton(title: "Images", icon: "square.stack.3d.up", color: .purple) {
                    onNavigate?(.images)
                }
                QuickActionButton(title: "Volumes", icon: "externaldrive", color: .cyan) {
                    onNavigate?(.volumes)
                }
                QuickActionButton(title: "Networks", icon: "network", color: .mint) {
                    onNavigate?(.networks)
                }
                QuickActionButton(title: "Machine", icon: "desktopcomputer", color: .blue) {
                    onNavigate?(.machine)
                }
                QuickActionButton(title: "System", icon: "gearshape", color: .gray) {
                    onNavigate?(.system)
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - System Info

    private var systemInfoSection: some View {
        GroupBox("System") {
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                if !info.apiServerVersion.isEmpty {
                    GridRow { Text("API Server").foregroundColor(.secondary); Text(info.apiServerVersion).font(.caption.monospaced()) }
                }
                GridRow { Text("Server Version").foregroundColor(.secondary); Text(info.serverVersion).font(.caption.monospaced()) }
                GridRow { Text("OS / Arch").foregroundColor(.secondary); Text("\(info.osType) / \(info.architecture)") }
                GridRow { Text("CPUs").foregroundColor(.secondary); Text("\(info.cpus)") }
                GridRow { Text("Memory").foregroundColor(.secondary); Text(formatBytes(info.totalMemory)) }
            }
            .padding(.vertical, 4)
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Dashboard Card

struct DashboardCard: View {
    let title: String
    let primaryValue: String
    let primaryLabel: String
    let secondaryValue: String
    let secondaryLabel: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                Spacer()
            }

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(primaryValue)
                    .font(.title).bold()
                Text(primaryLabel)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if !secondaryValue.isEmpty && !secondaryLabel.isEmpty {
                HStack(spacing: 2) {
                    Text(secondaryValue)
                        .font(.subheadline).bold()
                    Text(secondaryLabel)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.06))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.15), lineWidth: 1)
        )
        .contentShape(Rectangle())
    }
}

// MARK: - Quick Action Button

struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.subheadline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(color.opacity(0.08))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Disk Usage Mini Row

struct DiskUsageMiniRow: View {
    let title: String
    let icon: String
    let color: Color
    let total: Int
    let active: Int
    let size: Int64

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: icon).foregroundColor(color)
                Text(title).font(.subheadline).bold()
                Spacer()
                if total > 0 {
                    Text("\(active) / \(total)")
                        .font(.caption.monospaced())
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
                            .frame(height: 6)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(color)
                            .frame(width: max(CGFloat(active) / CGFloat(total) * geo.size.width, 2), height: 6)
                    }
                }
                .frame(height: 6)
            }
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: bytes)
    }
}
