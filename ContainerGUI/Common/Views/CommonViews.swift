import SwiftUI

struct LoadingView: View {
    let message: String

    init(_ message: String = "Loading...") {
        self.message = message
    }

    var body: some View {
        ProgressView(message)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ErrorView: View {
    let message: String
    let retryAction: (() -> Void)?

    init(_ message: String, retryAction: (() -> Void)? = nil) {
        self.message = message
      print(message)
        self.retryAction = retryAction
    }

    var body: some View {
        ContentUnavailableView(
            "Error",
            systemImage: "exclamationmark.triangle.fill",
            description: Text(message)
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .bottom) {
            if let retryAction {
                Button("Retry", action: retryAction)
                    .buttonStyle(.borderedProminent)
                    .padding()
            }
        }
    }
}

struct EmptyStateView: View {
    let title: String
    let systemImage: String
    let description: String

    init(_ title: String, systemImage: String = "tray", description: String = "") {
        self.title = title
        self.systemImage = systemImage
        self.description = description
    }

    var body: some View {
        ContentUnavailableView(
            title,
            systemImage: systemImage,
            description: description.isEmpty ? nil : Text(description)
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
