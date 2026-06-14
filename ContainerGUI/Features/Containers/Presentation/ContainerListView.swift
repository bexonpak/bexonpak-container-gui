import SwiftUI

struct ContainerListView: View {
    let containers: [Container]
    @Binding var selectedContainer: Container?
    let viewModel: ContainerViewModel

    var body: some View {
        List(containers, selection: $selectedContainer) { container in
            ContainerRow(container: container)
                .tag(container)
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
        .toolbar {
            ToolbarItemGroup {
                Toggle(isOn: .init(get: { viewModel.showAll }, set: { _ in viewModel.toggleShowAll() })) {
                    Label("Show All", systemImage: "line.3.horizontal.decrease")
                }
                .help("Toggle show all containers")

                Button {
                    Task { await viewModel.refresh() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .help("Refresh container list")
            }
        }
    }
}

struct ContainerRow: View {
    let container: Container

    var body: some View {
        HStack(spacing: 12) {
            StatusBadge(container.status.displayName)

            VStack(alignment: .leading, spacing: 2) {
                Text(container.name)
                    .font(.headline)
                    .lineLimit(1)
                Text(container.image)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(container.id.prefix(12))
                .font(.caption.monospaced())
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}
