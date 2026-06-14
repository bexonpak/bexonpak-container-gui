import Foundation

/// Holds all repository dependencies for injection.
struct AppDIContainer {
    let containerRepository: ContainerRepositoryProtocol
    let imageRepository: ImageRepositoryProtocol
    let volumeRepository: VolumeRepositoryProtocol
    let machineRepository: MachineRepositoryProtocol
    let networkRepository: NetworkRepositoryProtocol
    let systemRepository: SystemRepositoryProtocol

    static func makeDefault() -> AppDIContainer {
        let cli = CLIExecutor()
        return AppDIContainer(
            containerRepository: ContainerRepository(cli: cli),
            imageRepository: ImageRepository(cli: cli),
            volumeRepository: VolumeRepository(cli: cli),
            machineRepository: MachineRepository(cli: cli),
            networkRepository: NetworkRepository(cli: cli),
            systemRepository: SystemRepository(cli: cli)
        )
    }
}
