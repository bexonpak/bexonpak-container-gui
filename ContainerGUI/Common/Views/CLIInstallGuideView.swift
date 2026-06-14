import SwiftUI

/// Shown when the `container` CLI is not installed — guides the user to download it.
struct CLIInstallGuideView: View {
    /// Opens the user's browser to the GitHub releases page.
    private static let releasesURL = URL(string: "https://github.com/apple/container/releases")!

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "cube.box")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)

            Text("Container CLI Not Found")
                .font(.largeTitle).bold()

            Text("This app requires the `container` command-line tool.\nInstall it from the official Apple repository to get started.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 12) {
                installStep(1, "Open the GitHub releases page", "https://github.com/apple/container/releases")
                installStep(2, "Download the latest `.pkg` installer for your Mac")
                installStep(3, "Run the installer and follow the instructions")
                installStep(4, "Launch ContainerGUI again after installation")
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)

            HStack(spacing: 16) {
                Button {
                    NSWorkspace.shared.open(Self.releasesURL)
                } label: {
                    Label("Download from GitHub", systemImage: "arrow.down.circle")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button {
                    NSWorkspace.shared.open(URL(string: "https://brew.sh")!)
                } label: {
                    Label("Install via Homebrew", systemImage: "cup.and.saucer")
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }

            Text("After installing, you may need to restart the app.")
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()
        }
        .padding(40)
        .frame(maxWidth: 500)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func installStep(_ number: Int, _ text: String, _ url: String? = nil) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(number)")
                .font(.caption.bold())
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background(Circle().fill(Color.accentColor))

            if let url {
                VStack(alignment: .leading, spacing: 2) {
                    Text(text)
                        .font(.body)
                    Text(url)
                        .font(.caption.monospaced())
                        .foregroundColor(.accentColor)
                }
            } else {
                Text(text)
                    .font(.body)
            }

            Spacer()
        }
    }
}

#Preview {
    CLIInstallGuideView()
}
