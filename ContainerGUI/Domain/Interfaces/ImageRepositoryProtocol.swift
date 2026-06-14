import Foundation

public protocol ImageRepositoryProtocol: Sendable {
    func listImages() async throws -> [ContainerImage]
    func pullImage(reference: String, platform: String?) async throws -> AsyncThrowingStream<ImageBuildLog, Error>
    func buildImage(options: ImageBuildOptions) async throws -> AsyncThrowingStream<ImageBuildLog, Error>
    func inspectImage(reference: String) async throws -> ImageInspectInfo
    func removeImage(id: String, force: Bool) async throws
    func pruneImages() async throws -> Int

    // Builder management
    func builderStart(cpus: Int?, memory: String?) async throws
    func builderStatus() async throws -> BuilderStatus?
    func builderStop() async throws
}
