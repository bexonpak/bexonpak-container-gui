import Foundation

/// Represents the loading state of a view.
@MainActor
enum ViewState<T> {
    case loading
    case loaded(T)
    case error(String)
    case empty(String)

    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }

    var value: T? {
        if case .loaded(let v) = self { return v }
        return nil
    }

    var errorMessage: String? {
        if case .error(let msg) = self { return msg }
        return nil
    }

    var isEmpty: Bool {
        if case .empty = self { return true }
        return false
    }
}
