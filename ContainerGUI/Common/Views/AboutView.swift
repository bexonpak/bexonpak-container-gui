import SwiftUI

struct AboutView: View {
    @State private var updateState: UpdateState = .idle
    @Environment(\.dismiss) private var dismiss

    enum UpdateState {
        case idle
        case checking
        case available(UpdateChecker.ReleaseInfo)
        case upToDate
        case error(String)
    }

    var body: some View {
        VStack(spacing: 20) {
            // App icon
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 80, height: 80)

            // App name
            Text("ContainerGUI")
                .font(.largeTitle).bold()

            // Version
            Text("Version \(AppVersion.full)")
                .font(.body)
                .foregroundColor(.secondary)

            Divider()

            // Update section
            switch updateState {
            case .idle:
                checkForUpdatesButton

            case .checking:
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Checking for updates...")
                        .foregroundColor(.secondary)
                }

            case .available(let info):
                updateAvailableView(info)

            case .upToDate:
                VStack(spacing: 12) {
                    Label("ContainerGUI is up to date", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)

                    Button("Check Again") {
                        Task { await checkForUpdates() }
                    }
                    .buttonStyle(.bordered)
                }

            case .error(let msg):
                VStack(spacing: 8) {
                    Text("Update check failed")
                        .foregroundColor(.red)
                    Text(msg)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Button("Retry") {
                        Task { await checkForUpdates() }
                    }
                    .buttonStyle(.bordered)
                }
            }

            Spacer()

            // Footer
            VStack(spacing: 4) {
                Text("© 2026 Bexon Pak")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Button("Close") { dismiss() }
                    .keyboardShortcut(.escape)
                    .buttonStyle(.plain)
                    .font(.caption)
            }
        }
        .padding(24)
        .frame(width: 340, height: 420)
    }

    private var checkForUpdatesButton: some View {
        Button {
            Task { await checkForUpdates() }
        } label: {
            Label("Check for Updates", systemImage: "arrow.down.circle")
        }
        .buttonStyle(.borderedProminent)
    }

    @ViewBuilder
    private func updateAvailableView(_ info: UpdateChecker.ReleaseInfo) -> some View {
        VStack(spacing: 12) {
            Label("Update Available", systemImage: "arrow.down.circle.fill")
                .font(.headline)
                .foregroundColor(.blue)

            Text("Version \(info.version)")
                .font(.title3).bold()

            if !info.body.isEmpty {
                ScrollView {
                    Text(info.body)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 100)
            }

            HStack(spacing: 12) {
                Button {
                    NSWorkspace.shared.open(info.htmlURL)
                } label: {
                    Label("Download", systemImage: "arrow.down.circle")
                }
                .buttonStyle(.borderedProminent)

                Button("Later") {
                    dismiss()
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private func checkForUpdates() async {
        updateState = .checking
        if let info = await UpdateChecker.checkForUpdate() {
            updateState = .available(info)
        } else if await canReachGitHub() {
            updateState = .upToDate
        } else {
            updateState = .error("Could not reach GitHub")
        }
    }

    private func canReachGitHub() async -> Bool {
        guard let url = URL(string: "https://api.github.com") else { return false }
        return (try? await URLSession.shared.data(from: url)).map { !$0.0.isEmpty } ?? false
    }
}

#Preview {
    AboutView()
}
