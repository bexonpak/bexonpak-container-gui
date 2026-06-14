import SwiftUI

struct ContainersScreen: View {
    @State private var viewModel: ContainerViewModel
    @Binding var selectedContainer: Container?

    init(
        selectedContainer: Binding<Container?>,
        repository: ContainerRepositoryProtocol,
        systemRepository: SystemRepositoryProtocol,
        imageRepository: ImageRepositoryProtocol? = nil,
        volumeRepository: VolumeRepositoryProtocol? = nil,
        networkRepository: NetworkRepositoryProtocol? = nil,
        machineRepository: MachineRepositoryProtocol? = nil,
        viewModel: ContainerViewModel? = nil
    ) {
        self._viewModel = State(wrappedValue: viewModel ?? ContainerViewModel(
            repository: repository,
            systemRepository: systemRepository,
            imageRepository: imageRepository,
            volumeRepository: volumeRepository,
            networkRepository: networkRepository,
            machineRepository: machineRepository
        ))
        self._selectedContainer = selectedContainer
    }

    var body: some View {
        Group {
            switch viewModel.state {
            case .loading:
                LoadingView("Loading containers...")
            case .loaded(let containers):
                ContainerListView(
                    containers: containers,
                    selectedContainer: $selectedContainer,
                    viewModel: viewModel
                )
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
                EmptyStateView(message, systemImage: "cube.box")
            }
        }
        .task { await viewModel.load() }
        .onChange(of: selectedContainer) { _, _ in }
        .sheet(isPresented: $viewModel.showCreateSheet) {
            CreateContainerView(viewModel: viewModel)
                .onDisappear {
                    Task { await viewModel.refresh() }
                }
        }
        .toolbar {
            ToolbarItemGroup {
                Button {
                    viewModel.openCreateSheet()
                } label: {
                    Label("Create Container", systemImage: "plus")
                }
                .help("Create a new container")
            }
        }
    }
}
