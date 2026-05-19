import XCTest

final class PiWorkloadCredentialBoundaryValidationTests: XCTestCase {
    func testPiCredentialBoundaryValidationScriptDocumentsRealBackendUnauthenticatedChecks() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let validationDirectory = root.appendingPathComponent("docs/validation/pi-workload-credential-boundary")
        let script = try String(contentsOf: validationDirectory.appendingPathComponent("validate.sh"), encoding: .utf8)

        XCTAssertTrue(script.contains("swift build"))
        XCTAssertTrue(script.contains(".build/debug/sand create"))
        XCTAssertTrue(script.contains(".build/debug/sand \"$NAME\" run pi --version"), "Pi must be invoked as an ordinary Workload Command")
        XCTAssertTrue(script.contains(".build/debug/sand \"$NAME\" pi"), "validation must prove the Pi shortcut is absent")
        XCTAssertTrue(script.contains("PI_IDENTITY_MARKER"), "validation must prove Pi identity path is backed by persistent Guest State")
        XCTAssertTrue(script.contains("readlink \"$HOME/.pi\""))
        XCTAssertTrue(script.contains("test ! -e /Users"), "real guest command must prove host home paths are absent")
        XCTAssertTrue(script.contains("test ! -e /host"), "real guest command must prove generic host mount paths are absent")
        XCTAssertTrue(script.contains("test ! -S /run/host-services/ssh-auth.sock"), "real guest command must prove host secret-forwarding socket paths are absent")
        XCTAssertTrue(script.contains("test -z \"${SSH_AUTH_SOCK:-}\""), "real guest command must prove host SSH agent env is not forwarded")
        XCTAssertTrue(script.contains("container inspect \"$NAME\""), "validation must include backend inspection evidence")
        XCTAssertTrue(script.contains("assert_not_contains"), "inspection must fail if host credential paths are present")
        XCTAssertTrue(script.contains("UNAUTHENTICATED_PI_SMOKE"), "evidence must distinguish unauthenticated smoke checks from human-authenticated Pi setup")
        XCTAssertFalse(script.contains("Fake"))
    }
}
