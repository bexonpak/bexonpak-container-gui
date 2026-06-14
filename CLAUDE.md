# ContainerGUI — Architecture Conventions

## Clean Architecture + Feature-First Structure

This project strictly follows **Clean Architecture** with **MVVM** in the Presentation layer, organized as **feature-first vertical slices**.

```
ContainerGUI/
├── App/                        # App entry, DI container, root navigation
├── Core/                       # Cross-cutting infrastructure (CLI executor)
├── Common/                     # Shared UI components (ViewState, StatusBadge, etc.)
├── Domain/                     # 🧠 Global business core
│   ├── Entities/               # Core entities (Container, Image, Volume, etc.)
│   ├── Interfaces/              # Repository protocol interfaces
│   └── UseCases/               # Cross-feature use cases
├── Data/                       # 🔧 Global data implementations
│   ├── Repositories/           # Implementations of Domain/Interfaces
│   └── Models/                 # Decodable types for CLI JSON output
└── Features/                   # 📱 Feature modules (vertical slices)
    ├── Dashboard/
    ├── Containers/
    ├── Images/
    ├── Machine/
    ├── Network/
    ├── System/
    └── Volumes/
```

### Layer Ownership

```
App/                             — app entry, DI assembly, NavigationSplitView shell
Core/                            — infrastructure (CLIExecutor), extensions
Common/                          — reusable UI (LoadingView, ErrorView, EmptyStateView, StatusBadge, ServiceUnavailableView, ViewState)
Domain/                          — pure Swift, no UI imports. Entities + repository protocols.
Data/                            — CLIExecutor + repository implementations + JSON model types
Features/*/Presentation/         — screen-specific Views + ViewModels per feature
```

### Dependency Direction

```
App → Core, Common, Domain, Data, Features
Features → Domain, Data, Common
Data → Domain
Domain → (nothing)
```

### Domain Layer
- **Pure Swift** — no imports from SwiftUI, Foundation only (or at most Foundation for basic types)
- **Entities**: Value types (structs) — `Container`, `ContainerImage`, `Volume`, `Machine`, `ContainerNetwork`, `SystemInfo`
- **Interfaces**: Repository protocols defined as Swift protocols — `ContainerRepositoryProtocol`, etc.
- **Use Cases** (optional): Thin classes that orchestrate repository calls for complex business logic

### Data Layer
- **Repository Implementations**: Concretions of Domain protocols (all `actor` types for thread safety)
- **CLI Executor**: `CLIExecutor` actor wrapping `Process` to shell out to the `container` CLI tool
- **Models**: `Decodable` + `Sendable` types for parsing CLI JSON output (mapped to Domain entities at the repository boundary)

### Presentation Layer (MVVM)
- **Views**: Pure SwiftUI, no business logic. Observe `@Observable` ViewModels via `@State`.
- **ViewModels**: `@MainActor @Observable` classes that hold state, call repositories, and expose data to views.
- **Navigation**: `NavigationSplitView` (3-column: Sidebar → List → Detail)
- **Common Views**: Shared components in `Common/Views/` — `StatusBadge`, `LoadingView`, `ErrorView`, `EmptyStateView`, `ServiceUnavailableView`

### File naming
- Entity: `Container.swift`, `Image.swift`
- Protocol: `ContainerRepositoryProtocol.swift`
- Implementation: `ContainerRepository.swift`
- ViewModel: `ContainerViewModel.swift`
- Screen view: `ContainerListView.swift`, `ContainerDetailView.swift`
- Feature screen: `ContainersScreen.swift` (content-column entry point)

### State handling in ViewModels
Every ViewModel exposes one `enum ViewState<T>`:
```swift
enum ViewState<T> {
    case loading
    case loaded(T)
    case error(String)
    case empty(String)
}
```

### Dependency Injection
- Use manual DI via initializers (no third-party DI framework)
- `AppDIContainer` struct holds all repository references, assembled in `ContainerGUIApp.swift`
- ViewModels receive repository dependencies via `init`
- CLI commands executed through `CLIExecutor` actor (shared across all repositories)

### Swift 6 Concurrency
- All repository implementations are `actor` types
- All Domain entities conform to `Sendable`
- All CLI output model types conform to `Decodable, Sendable` with `nonisolated init(from:)`
- ViewModels are `@MainActor @Observable`

#### `nonisolated` discipline
Methods/properties on `Sendable` types (structs/enums) that are called from **actor contexts** must be explicitly `nonisolated`:

```swift
public struct FooOptions: Sendable {
    public nonisolated func buildArguments() -> [String] { ... }     // called from actor
    public nonisolated var computedProp: String { ... }               // accessed from nonisolated context
    public nonisolated init(...) { ... }                              // init is always nonisolated
}
```

**Static methods** on `actor` types that don't touch actor state must also be `nonisolated`:

```swift
public actor FooRepository {
    private static nonisolated func parseJSON(_ raw: String) throws -> Foo { ... }
    private static nonisolated func parseDate(_ raw: String?) -> Date? { ... }
}
```

Rule of thumb: if the method is pure computation (no actor state access), mark it `nonisolated`.

#### SwiftUI `Text` concatenation
`Text("...") + Text("...")` is **deprecated on macOS 26**. Use `HStack(spacing: 0)` to compose differently-styled texts:

```swift
// ❌ Deprecated
Text("Name").font(.headline) + Text(" (optional)").foregroundColor(.secondary)

// ✅ Correct
HStack(spacing: 0) {
    Text("Name").font(.headline)
    Text(" (optional)").foregroundColor(.secondary)
}
```

#### Unnecessary `try`
If a called method does not throw, do not prefix it with `try` — even inside a `do { } catch { }` block that catches other throwing calls. The compiler warns about this with "No calls to throwing functions occur within 'try' expression".
