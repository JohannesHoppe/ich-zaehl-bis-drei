import Foundation

/// Autorisierungsstatus von FamilyControls in übertragbarer Form.
public enum AuthStatus: String, Codable, Sendable {
    case notDetermined
    case denied
    case approved
    case unknown
}

/// Die Meldung des iPads an die Eltern-Seite: Quittung und Lebenszeichen.
public struct Heartbeat: Codable, Equatable, Sendable {
    public var ackCommandId: String?
    public var shieldActive: Bool
    public var authStatus: AuthStatus
    /// Ob das Feld im Store bleiben darf, klärt Spike 4.
    public var bootTime: Date?
    public var lowPowerMode: Bool
    public var protectedDataAvailable: Bool
    public var sentAt: Date

    public init(
        ackCommandId: String?,
        shieldActive: Bool,
        authStatus: AuthStatus,
        bootTime: Date?,
        lowPowerMode: Bool,
        protectedDataAvailable: Bool,
        sentAt: Date
    ) {
        self.ackCommandId = ackCommandId
        self.shieldActive = shieldActive
        self.authStatus = authStatus
        self.bootTime = bootTime
        self.lowPowerMode = lowPowerMode
        self.protectedDataAvailable = protectedDataAvailable
        self.sentAt = sentAt
    }

    /// Erzeugt die Meldung aus dem Gerätezustand.
    /// `protectedDataAvailable` kommt vom Aufrufer, weil `UIApplication.shared` in Extensions nicht verfügbar ist.
    public static func current(
        ackCommandId: String?,
        shieldActive: Bool,
        authStatus: AuthStatus,
        protectedDataAvailable: Bool,
        now: Date = Date()
    ) -> Heartbeat {
        Heartbeat(
            ackCommandId: ackCommandId,
            shieldActive: shieldActive,
            authStatus: authStatus,
            bootTime: SystemBootTime.read(),
            lowPowerMode: ProcessInfo.processInfo.isLowPowerModeEnabled,
            protectedDataAvailable: protectedDataAvailable,
            sentAt: now
        )
    }

    /// Die Quittung gilt, wenn das iPad genau diesen Sperrbefehl umgesetzt hat.
    public func confirmsLock(commandId: String) -> Bool {
        ackCommandId == commandId && shieldActive
    }

    /// `notDetermined` bei einer eingerichteten App ist ein starkes Umgehungssignal.
    public var indicatesBypass: Bool {
        authStatus != .approved
    }
}

public enum SystemBootTime {
    /// Liest `kern.boottime`. Verhalten auf iPadOS klärt Spike 4.
    public static func read() -> Date? {
        var value = timeval()
        var size = MemoryLayout<timeval>.stride
        guard sysctlbyname("kern.boottime", &value, &size, nil, 0) == 0, value.tv_sec > 0 else {
            return nil
        }
        return Date(timeIntervalSince1970: TimeInterval(value.tv_sec))
    }
}
