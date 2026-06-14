# ContainerGUI

A native **macOS** GUI for [Apple's `container` CLI](https://github.com/apple/container) — manage containers, images, volumes, networks, and VMs with a clean SwiftUI interface.

![macOS](https://img.shields.io/badge/macOS-26.0+-brightgreen)
![Swift](https://img.shields.io/badge/Swift-6-orange)
![License](https://img.shields.io/badge/license-MIT-blue)

---

## Features

### 📦 Containers
- List, start, stop, restart, kill, and delete containers
- Detailed inspect view (image, platform, mounts, networks, env, labels)
- Create containers with full configuration (ports, volumes, env, resources, etc.)
- Recreate containers with modified settings
- Per-action loading states

### 🖼️ Images
- List pulled images with repository, tag, and size
- Inspect image details (digest, platform, layers, env, entrypoint, labels)
- Build images from a Dockerfile with full option support
- Pull images from registries
- Remove and prune images
- Builder management (start, stop, status)

### 💾 Volumes
- List, create, delete, and prune volumes
- Size display formatted to human-readable units
- Support for labels, driver options, and size specification

### 🌐 Networks
- List, create, and remove networks
- Inspect network configuration (subnet, gateway, plugin)
- Label and option support during creation

### 🖥️ Machine (VM)
- List, create, start, stop, and remove VMs
- Configure CPUs, memory, architecture, and platform
- Set default machine and modify settings (CPUs, memory, home mount)

### ⚙️ System
- Dashboard overview (version, uptime, resource usage)
- Start/stop container services
- View and search system logs
- Disk usage breakdown (containers, images, volumes)
- Prune unused resources

### 🔄 Updates
- Built-in update checker via GitHub Releases API
- About window with version info

---

## Requirements

- **macOS 26.0+**
- **Xcode 26+** (for building from source)
- **[Apple `container` CLI](https://github.com/apple/container)** — the tool this app wraps

### Installing `container` CLI

```bash
# Homebrew (recommended)
brew install container

# Or download from GitHub releases
# https://github.com/apple/container/releases
```

After installing, the app will detect the CLI automatically.

---

## Screenshots

| Dashboard | Containers |
|---|---|
| Overview with system info and quick actions | List, manage, inspect containers |

| Images | Volumes |
|---|---|
| Pulled images with inspect details | Volume CRUD with size display |

| Networks | Machine |
|---|---|
| Network management | VM lifecycle management |

---

## Architecture

The project follows **Clean Architecture** with **MVVM** in the presentation layer, organized as **feature-first vertical slices**.

```
ContainerGUI/
├── App/              # App entry, DI container, NavigationSplitView shell
├── Core/             # CLIExecutor, extensions
├── Common/           # Reusable UI (LoadingView, ErrorView, StatusBadge, etc.)
├── Domain/           # Entities, repository protocols (pure Swift)
├── Data/             # Repository implementations, CLI JSON models
└── Features/         # Feature modules (vertical slices)
    ├── Dashboard/
    ├── Containers/
    ├── Images/
    ├── Machine/
    ├── Network/
    ├── System/
    └── Volumes/
```

### Dependency Direction

```
App → Core, Common, Domain, Data, Features
Features → Domain, Data, Common
Data → Domain
Domain → (nothing)
```

### Tech Stack

- **SwiftUI** — declarative UI with `NavigationSplitView` (3-column layout)
- **Swift 6** — full concurrency safety with actors, Sendable, and strict checking
- **`@Observable`** — SwiftUI observation
- **Manual DI** — no third-party frameworks; `AppDIContainer` injects repositories
- **`Process`** — wraps the `container` CLI via `CLIExecutor` actor

---

## Build & Run

```bash
# Clone the repository
git clone https://github.com/bexonpak/container-gui.git
cd container-gui

# Open in Xcode
open ContainerGUI.xcodeproj

# Build and run (Cmd+R)
# Ensure the container CLI is installed first
```

> **Note:** The project has **zero warnings** with Swift 6 strict concurrency checking enabled.

---

## Versioning

The app uses `CFBundleShortVersionString` (e.g., `1.0`) for marketing version. The built-in update checker compares against GitHub Releases tags (`v1.1`, `1.2`, etc.) using semantic version comparison.

---

## License

MIT License — see [LICENSE](LICENSE) for details.

---

## Acknowledgments

- Built on [Apple's `container`](https://github.com/apple/container) open-source project
- Icons from [SF Symbols](https://developer.apple.com/sf-symbols/)
