import Foundation

/// Defines the top-level navigation categories in the sidebar.
enum NavigationCategory: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case containers = "Containers"
    case images = "Images"
    case volumes = "Volumes"
    case machine = "Machine"
    case networks = "Networks"
    case system = "System"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .dashboard: return "square.grid.2x2"
        case .containers: return "cube.box"
        case .images: return "square.stack.3d.up"
        case .volumes: return "externaldrive"
        case .machine: return "desktopcomputer"
        case .networks: return "network"
        case .system: return "gearshape"
        }
    }

    var subtitle: String {
        switch self {
        case .dashboard: return "Overview"
        case .containers: return "Manage running containers"
        case .images: return "Container images"
        case .volumes: return "Persistent storage"
        case .machine: return "VM management"
        case .networks: return "Network configuration"
        case .system: return "System information"
        }
    }
}
