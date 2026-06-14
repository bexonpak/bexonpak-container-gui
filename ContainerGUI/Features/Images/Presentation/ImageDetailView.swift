import SwiftUI

struct ImageDetailView: View {
    let image: ContainerImage
    let viewModel: ImageViewModel
    @Binding var selectedImage: ContainerImage?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection
                Divider()
                infoSection
                Divider()
                inspectSection
                Divider()
                actionsSection
            }
            .padding()
        }
        .frame(minWidth: 300)
        .task { await viewModel.loadInspect(reference: image.reference) }
        .onChange(of: image.id) { _, _ in
            Task { await viewModel.loadInspect(reference: image.reference) }
        }
    }

    private var headerSection: some View {
        HStack {
            Image(systemName: "square.stack.3d.up")
                .font(.title)
                .foregroundColor(.purple)

            VStack(alignment: .leading, spacing: 4) {
                Text(image.repository)
                    .font(.largeTitle).bold()
                Text(image.tag)
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
                    Text(image.id)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                        .lineLimit(nil)
                }
                GridRow {
                    Text("Repository").foregroundColor(.secondary)
                    Text(image.repository)
                        .textSelection(.enabled)
                        .lineLimit(nil)
                }
                GridRow {
                    Text("Tag").foregroundColor(.secondary)
                    Text(image.tag)
                        .textSelection(.enabled)
                        .lineLimit(nil)
                }
                GridRow {
                    Text("Size").foregroundColor(.secondary)
                    if let info = viewModel.inspectInfo, info.size > 0 {
                        Text(formatBytes(info.size))
                            .textSelection(.enabled)
                            .lineLimit(nil)
                    } else {
                        Text(image.displaySize)
                            .textSelection(.enabled)
                            .lineLimit(nil)
                    }
                }
                GridRow {
                    Text("Full Reference").foregroundColor(.secondary)
                    Text(image.reference)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                        .lineLimit(nil)
                }
                if let url = image.registryURL {
                    GridRow {
                        Text("Registry URL").foregroundColor(.secondary)
                        Link(destination: url) {
                            Label("View on Docker Hub", systemImage: "arrow.up.forward.app")
                                .font(.caption)
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private var inspectSection: some View {
        if viewModel.isLoadingInspect {
            loadingSection
        } else if let error = viewModel.inspectError {
            errorSection(error)
        } else if let info = viewModel.inspectInfo {
            GroupBox("Inspect") {
                VStack(alignment: .leading, spacing: 12) {
                    // Digest
                    detailRow(label: "Digest", value: info.digest, mono: true)

                    // Platform
                    detailRow(label: "Platform", value: "\(info.architecture) / \(info.os)")

                    // Created
                    if let created = info.created {
                        detailRow(label: "Created", value: created.formatted(date: .long, time: .shortened))
                    }

                    // Layers
                    detailRow(label: "Layers", value: "\(info.layers)")

                    // Size
                    if info.size > 0 {
                        detailRow(label: "Size", value: formatBytes(info.size))
                    }

                    // Stop Signal
                    if let signal = info.stopSignal {
                        detailRow(label: "Stop Signal", value: signal)
                    }

                    // Entrypoint
                    if !info.entrypoint.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Entrypoint").font(.caption).foregroundColor(.secondary)
                            Text(info.entrypoint.joined(separator: " "))
                                .font(.caption.monospaced())
                                .textSelection(.enabled)
                        }
                    }

                    // Command
                    if !info.cmd.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Command").font(.caption).foregroundColor(.secondary)
                            Text(info.cmd.joined(separator: " "))
                                .font(.caption.monospaced())
                                .textSelection(.enabled)
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
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var loadingSection: some View {
        GroupBox("Inspect") {
            HStack(spacing: 8) {
                ProgressView()
                    .scaleEffect(0.8)
                Text("Loading image details...")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .padding(.vertical, 4)
        }
    }

    private func errorSection(_ error: String) -> some View {
        GroupBox("Inspect") {
            Text(error)
                .foregroundColor(.red)
                .font(.caption)
                .padding(.vertical, 4)
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: bytes)
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

    private var actionsSection: some View {
        GroupBox("Actions") {
            HStack(spacing: 12) {
                Button(role: .destructive) {
                    Task { await viewModel.removeImage(image, selectedImage: $selectedImage) }
                } label: {
                    Label("Remove", systemImage: "trash")
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }
            .padding(.vertical, 4)
        }
    }
}
