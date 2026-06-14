import SwiftUI

struct StatusBadge: View {
    let status: String
    let color: Color

    init(_ status: String, color: Color? = nil) {
        self.status = status
        self.color = color ?? Self.defaultColor(for: status)
    }

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(status)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
    }

    private static func defaultColor(for status: String) -> Color {
        switch status.lowercased() {
        case "running", "up": return .green
        case "paused": return .orange
        case "stopped", "exited": return .red
        case "starting": return .yellow
        case "stopping": return .gray
        default: return .secondary
        }
    }
}

#Preview {
    HStack {
        StatusBadge("Running")
        StatusBadge("Stopped")
        StatusBadge("Paused")
    }
    .padding()
}
