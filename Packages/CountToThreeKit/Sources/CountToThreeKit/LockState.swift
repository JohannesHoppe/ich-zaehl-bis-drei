import Foundation

/// Der Steuerbefehl der Eltern-Seite. Unabhängig vom Zustellweg.
public struct LockState: Codable, Equatable, Sendable {
    /// 1 = gesperrt, 0 = frei.
    public var locked: Int
    /// Eindeutig je Befehl; das iPad quittiert sie im `Heartbeat`.
    public var commandId: String
    public var issuedAt: Date

    public init(locked: Bool, commandId: String = UUID().uuidString, issuedAt: Date = Date()) {
        self.locked = locked ? 1 : 0
        self.commandId = commandId
        self.issuedAt = issuedAt
    }

    public var isLocked: Bool { locked != 0 }
}
