#if os(iOS)
import FamilyControls
import ManagedSettings

/// Setzt und entfernt den Schild über einen benannten Store, den App und Extensions gemeinsam nutzen.
public struct ShieldManager {
    private let store = ManagedSettingsStore(named: ManagedSettingsStore.Name("de.haushoppe-its.countto3.lock"))

    public init() {}

    public func lock() {
        store.shield.applicationCategories = .all()
        store.shield.webDomainCategories = .all()
    }

    public func unlock() {
        store.clearAllSettings()
    }

    public var isShieldActive: Bool {
        store.shield.applicationCategories != nil
    }

    public func apply(_ state: LockState) {
        if state.isLocked {
            lock()
        } else {
            unlock()
        }
    }
}

public extension AuthStatus {
    init(_ status: AuthorizationStatus) {
        switch status {
        case .notDetermined: self = .notDetermined
        case .denied: self = .denied
        // Beide Fälle bedeuten: Die Sperre darf wirken. Ein anderer Status würde als Umgehung gemeldet.
        case .approved, .approvedWithDataAccess: self = .approved
        @unknown default: self = .unknown
        }
    }
}
#endif
