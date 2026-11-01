import Foundation
import XCTest
@testable import CountToThreeKit

final class ModelTests: XCTestCase {
    private func heartbeat(ack: String?, shield: Bool, auth: AuthStatus = .approved) -> Heartbeat {
        Heartbeat(
            ackCommandId: ack,
            shieldActive: shield,
            authStatus: auth,
            bootTime: nil,
            lowPowerMode: false,
            protectedDataAvailable: true,
            sentAt: Date(timeIntervalSince1970: 0)
        )
    }

    func testLockStateStoresLockedAsInt() {
        XCTAssertEqual(LockState(locked: true).locked, 1)
        XCTAssertEqual(LockState(locked: false).locked, 0)
        XCTAssertTrue(LockState(locked: true).isLocked)
        XCTAssertFalse(LockState(locked: false).isLocked)
    }

    func testLockStateSurvivesCoding() throws {
        let state = LockState(locked: true, commandId: "abc", issuedAt: Date(timeIntervalSince1970: 100))
        let decoded = try JSONDecoder().decode(LockState.self, from: JSONEncoder().encode(state))
        XCTAssertEqual(decoded, state)
    }

    func testAcknowledgementNeedsMatchingCommandAndActiveShield() {
        XCTAssertTrue(heartbeat(ack: "abc", shield: true).confirmsLock(commandId: "abc"))
        XCTAssertFalse(heartbeat(ack: "abc", shield: false).confirmsLock(commandId: "abc"))
        XCTAssertFalse(heartbeat(ack: "alt", shield: true).confirmsLock(commandId: "abc"))
        XCTAssertFalse(heartbeat(ack: nil, shield: true).confirmsLock(commandId: "abc"))
    }

    func testEveryStatusExceptApprovedIndicatesBypass() {
        XCTAssertFalse(heartbeat(ack: nil, shield: true, auth: .approved).indicatesBypass)
        for status in [AuthStatus.notDetermined, .denied, .unknown] {
            XCTAssertTrue(heartbeat(ack: nil, shield: true, auth: status).indicatesBypass)
        }
    }

    func testBootTimeLiesInThePast() throws {
        let bootTime = try XCTUnwrap(SystemBootTime.read())
        XCTAssertLessThan(bootTime, Date())
    }
}
