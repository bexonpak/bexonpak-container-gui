import SwiftUI

/// Shown when container services are not running — offers to start them.
struct ServiceUnavailableView: View {
    let errorMessage: String
    let isStarting: Bool
    let onStart: () async -> Void
    let onRetry: () async -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 36))
                .foregroundColor(.orange)

            Text("Container Services Not Running")
                .font(.title2).bold()

            Text("Start the container platform services to use this feature.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.caption.monospaced())
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 12) {
                Button {
                    Task { await onStart() }
                } label: {
                    Label("Start Services", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(isStarting)
                .overlay {
                    if isStarting { ProgressView().scaleEffect(0.6) }
                }

                Button {
                    Task { await onRetry() }
                } label: {
                    Text("Retry")
                }
                .buttonStyle(.bordered)
                .disabled(isStarting)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Helper to detect service-related errors from CLI output.
enum ServiceErrorDetector {
    /// Returns true if the error message indicates container services are not running.
    static func isServiceNotRunning(_ message: String) -> Bool {
        let msg = message.lowercased()
        return msg.contains("container system start")
            || msg.contains("xpc connection error")
            || msg.contains("connection invalid")
            || (msg.contains("exit 1") && !msg.contains("unknown option"))
    }
}
