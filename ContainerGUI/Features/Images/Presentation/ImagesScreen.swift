import SwiftUI
import UniformTypeIdentifiers

@MainActor
@Observable
final class ImageViewModel {
    var state: ViewState<[ContainerImage]> = .loading
    var errorMessage: String?
    var isStarting = false

    // Pull state
    var isPulling = false
    var pullReference = ""
    var pullLog: [String] = []
    var pullError: String?
    private var pullTask: Task<Void, Never>?

    // Build state
    var isBuilding = false
    var buildLog: [String] = []
    var buildError: String?
    private var buildTask: Task<Void, Never>?

    // Inspect state
    var inspectInfo: ImageInspectInfo?
    var inspectError: String?
    var isLoadingInspect = false

    private let repository: ImageRepositoryProtocol
    private let systemRepository: SystemRepositoryProtocol

    init(repository: ImageRepositoryProtocol, systemRepository: SystemRepositoryProtocol) {
        self.repository = repository
        self.systemRepository = systemRepository
    }

    func load() async {
        state = .loading
        await refresh()
    }

    func refresh() async {
        do {
            let images = try await repository.listImages()
            state = images.isEmpty ? .empty("No images found") : .loaded(images)
        } catch {
            state = .error(error.localizedDescription)
            errorMessage = error.localizedDescription
        }
    }

    func removeImage(_ id: String) async {
        do {
            try await repository.removeImage(id: id, force: false)
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func removeImage(_ image: ContainerImage, selectedImage: Binding<ContainerImage?>) async {
        if selectedImage.wrappedValue?.id == image.id {
            selectedImage.wrappedValue = nil
        }
        await removeImage(image.reference)
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

    func pullImage() async {
        guard !pullReference.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isPulling = true
        pullLog = []
        pullError = nil
        pullTask = Task { [weak self] in
            guard let self else { return }
            do {
                let stream = try await repository.pullImage(reference: pullReference, platform: nil)
                for try await log in stream {
                    if Task.isCancelled { break }
                    pullLog.append(log.message.trimmingCharacters(in: .newlines))
                }
                if !Task.isCancelled {
                    pullReference = ""
                    await refresh()
                }
            } catch {
                if !Task.isCancelled {
                    pullError = error.localizedDescription
                    pullLog.append("Error: \(error.localizedDescription)")
                }
            }
            isPulling = false
            pullTask = nil
        }
    }

    func cancelPull() {
        pullTask?.cancel()
        pullTask = nil
        isPulling = false
        pullLog.removeAll()
        pullError = nil
    }

    // MARK: - Build

    func buildImage(options: ImageBuildOptions) async {
        isBuilding = true
        buildLog = []
        buildError = nil
        buildTask = Task { [weak self] in
            guard let self else { return }
            do {
                let stream = try await repository.buildImage(options: options)
                for try await log in stream {
                    if Task.isCancelled { break }
                    buildLog.append(log.message.trimmingCharacters(in: .newlines))
                }
                if !Task.isCancelled {
                    await refresh()
                }
            } catch {
                if !Task.isCancelled {
                    buildError = error.localizedDescription
                    buildLog.append("Error: \(error.localizedDescription)")
                }
            }
            isBuilding = false
            buildTask = nil
        }
    }

    func cancelBuild() {
        buildTask?.cancel()
        buildTask = nil
        isBuilding = false
        buildLog.removeAll()
        buildError = nil
    }

    // MARK: - Inspect

    func loadInspect(reference: String) async {
        isLoadingInspect = true
        inspectInfo = nil
        inspectError = nil
        do {
            inspectInfo = try await repository.inspectImage(reference: reference)
        } catch {
            inspectError = error.localizedDescription
        }
        isLoadingInspect = false
    }
}

// MARK: - Images Screen (content column)

struct ImagesScreen: View {
    @State private var viewModel: ImageViewModel
    @Binding var selectedImage: ContainerImage?
    @State private var showPullSheet = false
    @State private var showBuildSheet = false

    init(repository: ImageRepositoryProtocol, systemRepository: SystemRepositoryProtocol, selectedImage: Binding<ContainerImage?>, viewModel: ImageViewModel? = nil) {
        self._viewModel = State(wrappedValue: viewModel ?? ImageViewModel(repository: repository, systemRepository: systemRepository))
        self._selectedImage = selectedImage
    }

    var body: some View {
        Group {
            switch viewModel.state {
            case .loading:
                LoadingView("Loading images...")
            case .loaded(let images):
                ImageListView(images: images, selectedImage: $selectedImage, viewModel: viewModel)
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
                EmptyStateView(message, systemImage: "square.stack.3d.up")
            }
        }
        .task { await viewModel.load() }
        .sheet(isPresented: $showPullSheet) {
            PullImageView(viewModel: viewModel)
                .onDisappear {
                    viewModel.cancelPull()
                }
        }
        .sheet(isPresented: $showBuildSheet) {
            BuildImageView(viewModel: viewModel)
                .onDisappear {
                    viewModel.cancelBuild()
                }
        }
        .toolbar {
            ToolbarItemGroup {
                Button {
                    showBuildSheet = true
                } label: {
                    Label("Build Image", systemImage: "hammer.fill")
                }
                .help("Build an image from a Dockerfile")

                Button {
                    showPullSheet = true
                } label: {
                    Label("Pull Image", systemImage: "arrow.down.to.line.compact")
                }
                .help("Pull an image from a registry")

                Button {
                    Task { await viewModel.refresh() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .help("Refresh image list")
            }
        }
    }
}

// MARK: - Pull Image Sheet

struct PullImageView: View {
    @Bindable var viewModel: ImageViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Text("Pull Image")
                .font(.title2).bold()

            HStack {
                TextField("e.g. nginx:latest", text: $viewModel.pullReference)
                    .textFieldStyle(.roundedBorder)
                    .frame(minWidth: 300)
                    .disabled(viewModel.isPulling)

                Button("Pull") {
                    Task { await viewModel.pullImage() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isPulling || viewModel.pullReference.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            if viewModel.isPulling || !viewModel.pullLog.isEmpty {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(viewModel.pullLog.enumerated()), id: \.offset) { index, line in
                                Text(line)
                                    .font(.caption2.monospaced())
                                    .foregroundColor(viewModel.pullError != nil ? .red : .secondary)
                                    .id(index)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 200)
                    .background(Color(nsColor: .textBackgroundColor))
                    .cornerRadius(8)
                    .onChange(of: viewModel.pullLog.count) { _, _ in
                        withAnimation {
                            proxy.scrollTo(viewModel.pullLog.count - 1, anchor: .bottom)
                        }
                    }
                }
            }

            if let error = viewModel.pullError {
                Text(error)
                    .foregroundColor(.red)
                    .font(.callout)
            }

            HStack {
                if viewModel.isPulling {
                    Button(role: .destructive) {
                        viewModel.cancelPull()
                    } label: {
                        Label("Cancel", systemImage: "xmark.circle.fill")
                    }
                    .buttonStyle(.bordered)
                    Spacer()
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Pulling...")
                        .foregroundColor(.secondary)
                } else {
                    Spacer()
                    Button("Close") {
                        dismiss()
                    }
                    .keyboardShortcut(.escape)
                }
            }
        }
        .padding()
        .frame(width: 520)
    }
}

// MARK: - Build Image Sheet

struct BuildImageView: View {
    @Bindable var viewModel: ImageViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var contextDir = ""
    @State private var dockerfile = ""
    @State private var tagsString = ""
    @State private var noCache = false
    @State private var pullLatest = true
    @State private var target = ""
    @State private var showAdvanced = false
    @State private var showFolderPicker = false
    @State private var buildArgs: [KeyValuePair] = []
    @State private var labels: [KeyValuePair] = []
    @State private var platform = ""
    @State private var arch = ""
    @State private var os = ""
    @State private var cpus = ""
    @State private var memory = ""

    var body: some View {
        VStack(spacing: 16) {
            Text("Build Image")
                .font(.title2).bold()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    // MARK: Build Context
                    GroupBox("Build Context") {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                TextField("Context directory path", text: $contextDir)
                                    .textFieldStyle(.roundedBorder)
                                    .disabled(viewModel.isBuilding)

                                Button("Browse...") {
                                    showFolderPicker = true
                                }
                                .disabled(viewModel.isBuilding)
                                .fileImporter(
                                    isPresented: $showFolderPicker,
                                    allowedContentTypes: [.folder],
                                    allowsMultipleSelection: false
                                ) { result in
                                    if case .success(let urls) = result, let url = urls.first {
                                        contextDir = url.path
                                    }
                                }
                            }

                            HStack {
                                TextField("Dockerfile (optional)", text: $dockerfile)
                                    .textFieldStyle(.roundedBorder)
                                    .disabled(viewModel.isBuilding)

                                TextField("Tags (comma-separated)", text: $tagsString)
                                    .textFieldStyle(.roundedBorder)
                                    .disabled(viewModel.isBuilding)
                            }
                        }
                        .padding(8)
                    }

                    // MARK: Options
                    GroupBox("Options") {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Toggle("No Cache", isOn: $noCache)
                                    .disabled(viewModel.isBuilding)
                                Toggle("Pull", isOn: $pullLatest)
                                    .disabled(viewModel.isBuilding)
                                Spacer()
                            }

                            TextField("Target stage (optional)", text: $target)
                                .textFieldStyle(.roundedBorder)
                                .disabled(viewModel.isBuilding)
                        }
                        .padding(8)
                    }

                    // MARK: Advanced
                    DisclosureGroup("Advanced Options", isExpanded: $showAdvanced) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Build Arguments")
                                .font(.caption).foregroundColor(.secondary)
                            KeyValueEditor(items: $buildArgs,
                                           placeholderKey: "KEY",
                                           placeholderValue: "value",
                                           disabled: viewModel.isBuilding)

                            Text("Labels")
                                .font(.caption).foregroundColor(.secondary)
                            KeyValueEditor(items: $labels,
                                           placeholderKey: "KEY",
                                           placeholderValue: "value",
                                           disabled: viewModel.isBuilding)

                            HStack {
                                TextField("Platform (e.g. linux/amd64)", text: $platform)
                                    .textFieldStyle(.roundedBorder)
                                    .disabled(viewModel.isBuilding)
                                TextField("Arch (e.g. amd64)", text: $arch)
                                    .textFieldStyle(.roundedBorder)
                                    .disabled(viewModel.isBuilding)
                                TextField("OS (e.g. linux)", text: $os)
                                    .textFieldStyle(.roundedBorder)
                                    .disabled(viewModel.isBuilding)
                            }

                            HStack {
                                TextField("CPUs", text: $cpus)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(maxWidth: 120)
                                    .disabled(viewModel.isBuilding)
                                TextField("Memory (e.g. 2GB)", text: $memory)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(maxWidth: 200)
                                    .disabled(viewModel.isBuilding)
                                Spacer()
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
                .padding(.horizontal)
            }

            // Build log
            if viewModel.isBuilding || !viewModel.buildLog.isEmpty {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(viewModel.buildLog.enumerated()), id: \.offset) { index, line in
                                Text(line)
                                    .font(.caption2.monospaced())
                                    .foregroundColor(viewModel.buildError != nil ? .red : .secondary)
                                    .id(index)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 200)
                    .background(Color(nsColor: .textBackgroundColor))
                    .cornerRadius(8)
                    .onChange(of: viewModel.buildLog.count) { _, _ in
                        withAnimation {
                            proxy.scrollTo(viewModel.buildLog.count - 1, anchor: .bottom)
                        }
                    }
                }
            }

            if let error = viewModel.buildError {
                Text(error)
                    .foregroundColor(.red)
                    .font(.callout)
            }

            // Action buttons
            HStack {
                if viewModel.isBuilding {
                    Button(role: .destructive) {
                        viewModel.cancelBuild()
                    } label: {
                        Label("Cancel", systemImage: "xmark.circle.fill")
                    }
                    .buttonStyle(.bordered)
                    Spacer()
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Building...")
                        .foregroundColor(.secondary)
                } else {
                    Button("Build") {
                        performBuild()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(contextDir.trimmingCharacters(in: .whitespaces).isEmpty)

                    Spacer()

                    Button("Close") {
                        dismiss()
                    }
                    .keyboardShortcut(.escape)
                }
            }
        }
        .padding()
        .frame(width: 640)
    }

    private func performBuild() {
        let tagList = tagsString.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        let buildArgDict = Dictionary(uniqueKeysWithValues: buildArgs
            .filter { !$0.key.trimmingCharacters(in: .whitespaces).isEmpty }
            .map { ($0.key.trimmingCharacters(in: .whitespaces), $0.value) })
        let labelDict = Dictionary(uniqueKeysWithValues: labels
            .filter { !$0.key.trimmingCharacters(in: .whitespaces).isEmpty }
            .map { ($0.key.trimmingCharacters(in: .whitespaces), $0.value) })

        let options = ImageBuildOptions(
            contextDir: contextDir,
            dockerfile: dockerfile.trimmingCharacters(in: .whitespaces).isEmpty ? nil : dockerfile,
            tags: tagList,
            buildArgs: buildArgDict,
            labels: labelDict,
            noCache: noCache,
            pull: pullLatest,
            target: target.trimmingCharacters(in: .whitespaces).isEmpty ? nil : target,
            platform: platform.trimmingCharacters(in: .whitespaces).isEmpty ? nil : platform,
            arch: arch.trimmingCharacters(in: .whitespaces).isEmpty ? nil : arch,
            os: os.trimmingCharacters(in: .whitespaces).isEmpty ? nil : os,
            cpus: Int(cpus),
            memory: memory.trimmingCharacters(in: .whitespaces).isEmpty ? nil : memory
        )

        Task { await viewModel.buildImage(options: options) }
    }
}

// MARK: - Key-Value Editor

struct KeyValuePair: Identifiable {
    let id = UUID()
    var key: String
    var value: String
}

struct KeyValueEditor: View {
    @Binding var items: [KeyValuePair]
    let placeholderKey: String
    let placeholderValue: String
    var disabled: Bool = false

    var body: some View {
        VStack(spacing: 4) {
            ForEach($items) { $item in
                HStack(spacing: 4) {
                    TextField(placeholderKey, text: $item.key)
                        .textFieldStyle(.roundedBorder)
                        .disabled(disabled)
                        .frame(maxWidth: 150)
                        .font(.caption)

                    TextField(placeholderValue, text: $item.value)
                        .textFieldStyle(.roundedBorder)
                        .disabled(disabled)
                        .font(.caption)

                    Button {
                        items.removeAll { $0.id == item.id }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                    .disabled(disabled)
                    .help("Remove")
                }
            }

            Button {
                items.append(KeyValuePair(key: "", value: ""))
            } label: {
                Label("Add", systemImage: "plus")
                    .font(.caption)
            }
            .disabled(disabled)
        }
    }
}

// MARK: - Image List

struct ImageListView: View {
    let images: [ContainerImage]
    @Binding var selectedImage: ContainerImage?
    let viewModel: ImageViewModel

    var body: some View {
        List(images, selection: $selectedImage) { image in
            ImageRow(image: image, viewModel: viewModel, selectedImage: $selectedImage)
                .tag(image)
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
    }
}

struct ImageRow: View {
    let image: ContainerImage
    let viewModel: ImageViewModel
    @Binding var selectedImage: ContainerImage?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "square.stack.3d.up")
                .font(.title2)
                .foregroundColor(.purple)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(image.repository)
                        .font(.headline)
                        .lineLimit(1)
                    Text(image.tag)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Text("ID: \(image.id.prefix(12))")
                    .font(.caption.monospaced())
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text(image.displaySize)
                .font(.caption)
                .foregroundColor(.secondary)

            Button {
                Task { await viewModel.removeImage(image, selectedImage: $selectedImage) }
            } label: {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
            .help("Remove image")
        }
        .padding(.vertical, 4)
    }
}
