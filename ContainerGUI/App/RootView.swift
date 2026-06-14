import SwiftUI

struct RootView: View {
    @State private var selectedCategory: NavigationCategory? = .dashboard
    @State private var selectedContainer: Container?
    @State private var selectedImage: ContainerImage?
    @State private var selectedVolume: Volume?
    @State private var selectedNetwork: ContainerNetwork?
    @State private var selectedMachine: Machine?
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var imageViewModel: ImageViewModel
    @State private var containerViewModel: ContainerViewModel
    @State private var cliInstalled: Bool = true

    let dependencies: AppDIContainer

    init(dependencies: AppDIContainer) {
        self.dependencies = dependencies
        self._imageViewModel = State(initialValue: ImageViewModel(
            repository: dependencies.imageRepository,
            systemRepository: dependencies.systemRepository
        ))
        self._containerViewModel = State(initialValue: ContainerViewModel(
            repository: dependencies.containerRepository,
            systemRepository: dependencies.systemRepository,
            imageRepository: dependencies.imageRepository,
            volumeRepository: dependencies.volumeRepository,
            networkRepository: dependencies.networkRepository,
            machineRepository: dependencies.machineRepository
        ))
    }

    var body: some View {
        Group {
            if cliInstalled {
                mainContent
            } else {
                CLIInstallGuideView()
            }
        }
        .task {
            // Check asynchronously so the UI remains responsive.
            cliInstalled = await Task.detached { CLIExecutor.isCLIInstalled() }.value
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        if selectedCategory == .dashboard {
            // 2-column: sidebar + dashboard, no detail column.
            NavigationSplitView {
                sidebar
            } detail: {
                DashboardScreen(
                    systemRepository: dependencies.systemRepository,
                    imageRepository: dependencies.imageRepository
                ) { category in
                    selectedCategory = category
                }
            }
            .navigationTitle("Dashboard")
            .frame(minWidth: 800, minHeight: 500)
        } else {
            NavigationSplitView(columnVisibility: $columnVisibility) {
                sidebar
            } content: {
                contentView
            } detail: {
                detailView
            }
            .navigationTitle(selectedCategory?.rawValue ?? "ContainerGUI")
            .navigationSubtitle(selectedCategory?.subtitle ?? "")
            .frame(minWidth: 800, minHeight: 500)
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List(NavigationCategory.allCases, selection: $selectedCategory) { category in
            Label(category.rawValue, systemImage: category.systemImage)
                .tag(category)
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 280)
    }

    // MARK: - Content (List)

    @ViewBuilder
    private var contentView: some View {
        switch selectedCategory {
        case .dashboard:
            DashboardScreen(
                systemRepository: dependencies.systemRepository,
                imageRepository: dependencies.imageRepository
            ) { category in
                selectedCategory = category
            }
        case .containers:
            ContainersScreen(
                selectedContainer: $selectedContainer,
                repository: dependencies.containerRepository,
                systemRepository: dependencies.systemRepository,
                imageRepository: dependencies.imageRepository,
                volumeRepository: dependencies.volumeRepository,
                networkRepository: dependencies.networkRepository,
                machineRepository: dependencies.machineRepository,
                viewModel: containerViewModel
            )
            .navigationSplitViewColumnWidth(min: 300, ideal: 340)
        case .images:
            ImagesScreen(
                repository: dependencies.imageRepository,
                systemRepository: dependencies.systemRepository,
                selectedImage: $selectedImage,
                viewModel: imageViewModel
            )
            .navigationSplitViewColumnWidth(min: 300, ideal: 340)
        case .volumes:
            VolumesScreen(
                repository: dependencies.volumeRepository,
                systemRepository: dependencies.systemRepository,
                selectedVolume: $selectedVolume
            )
            .navigationSplitViewColumnWidth(min: 300, ideal: 340)
        case .machine:
            MachineScreen(
                repository: dependencies.machineRepository,
                systemRepository: dependencies.systemRepository,
                imageRepository: dependencies.imageRepository,
                selectedMachine: $selectedMachine
            )
            .navigationSplitViewColumnWidth(min: 300, ideal: 340)
        case .networks:
            NetworksScreen(
                repository: dependencies.networkRepository,
                systemRepository: dependencies.systemRepository,
                selectedNetwork: $selectedNetwork
            )
            .navigationSplitViewColumnWidth(min: 300, ideal: 340)
        case .system:
            SystemScreen(repository: dependencies.systemRepository)
            .navigationSplitViewColumnWidth(min: 300, ideal: 340)
        case nil:
            EmptyStateView("Select a category", systemImage: "sidebar.left")
        }
    }

    // MARK: - Detail

    @ViewBuilder
    private var detailView: some View {
        switch selectedCategory {
        case .dashboard:
            Color.clear
                .frame(maxWidth: 0)
                .navigationSplitViewColumnWidth(min: 0, ideal: 0)
        case .containers:
            containerDetail
        case .images:
            imageDetail
        case .volumes:
            volumeDetail
        case .networks:
            networkDetail
        case .machine:
            machineDetail
        default:
            EmptyStateView("Select an item", systemImage: "square.dashed")
        }
    }

    @ViewBuilder
    private var containerDetail: some View {
        if let container = selectedContainer {
            ContainerDetailView(
                containerId: container.id,
                viewModel: containerViewModel,
                onDelete: {
                    selectedContainer = nil
                    Task { await containerViewModel.refresh() }
                }
            )
        } else {
            EmptyStateView("Select a container", systemImage: "cube.box", description: "Choose a container from the list")
        }
    }

    @ViewBuilder
    private var volumeDetail: some View {
        if let volume = selectedVolume {
            VolumeDetailView(
                volume: volume,
                viewModel: VolumeViewModel(
                    repository: dependencies.volumeRepository,
                    systemRepository: dependencies.systemRepository
                ),
                onDelete: { selectedVolume = nil }
            )
        } else {
            EmptyStateView("Select a volume", systemImage: "externaldrive", description: "Choose a volume from the list")
        }
    }

    @ViewBuilder
    private var machineDetail: some View {
        if let machine = selectedMachine {
            MachineDetailView(
                machine: machine,
                viewModel: MachineViewModel(
                    repository: dependencies.machineRepository,
                    systemRepository: dependencies.systemRepository,
                    imageRepository: dependencies.imageRepository
                ),
                onDelete: { selectedMachine = nil }
            )
        } else {
            EmptyStateView("Select a machine", systemImage: "desktopcomputer", description: "Choose a machine from the list")
        }
    }

    @ViewBuilder
    private var networkDetail: some View {
        if let network = selectedNetwork {
            NetworkDetailView(
                network: network,
                viewModel: NetworkViewModel(
                    repository: dependencies.networkRepository,
                    systemRepository: dependencies.systemRepository
                ),
                onDelete: { selectedNetwork = nil }
            )
        } else {
            EmptyStateView("Select a network", systemImage: "network", description: "Choose a network from the list")
        }
    }

    @ViewBuilder
    private var imageDetail: some View {
        if let image = selectedImage {
            ImageDetailView(
                image: image,
                viewModel: imageViewModel,
                selectedImage: $selectedImage
            )
        } else {
            EmptyStateView("Select an image", systemImage: "square.stack.3d.up", description: "Choose an image from the list")
        }
    }
}

#Preview {
    RootView(dependencies: .makeDefault())
}
