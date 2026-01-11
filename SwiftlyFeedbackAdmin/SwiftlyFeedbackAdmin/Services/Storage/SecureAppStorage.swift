import SwiftUI

/// Property wrapper that provides @AppStorage-like functionality backed by SecureStorageManager.
///
/// Usage:
/// ```swift
/// @SecureAppStorage(.feedbackViewMode) private var viewMode: String = "list"
/// ```
@propertyWrapper
struct SecureAppStorage<Value>: DynamicProperty {
    @State private var value: Value
    private let key: StorageKey

    var wrappedValue: Value {
        get { value }
        nonmutating set {
            value = newValue
            SecureStorageManager.shared.set(newValue, for: key)
        }
    }

    var projectedValue: Binding<Value> {
        Binding(
            get: { wrappedValue },
            set: { wrappedValue = $0 }
        )
    }

    init(wrappedValue defaultValue: Value, _ key: StorageKey) {
        self.key = key
        let storedValue: Value? = SecureStorageManager.shared.get(key)
        self._value = State(initialValue: storedValue ?? defaultValue)
    }
}
