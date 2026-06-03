import Foundation
import XCTest
@testable import SandCore

final class EphemeralRunRecordStoreTests: XCTestCase {
    func testEphemeralSpecDefaultsNamePrefix() throws {
        let spec = try EphemeralSpec.parseYAML("""
        schemaVersion: 1
        workload:
          command: echo
          workdir: /workspace
        """)

        XCTAssertEqual(spec.namePrefix, "ephemeral")
    }

    func testAllocateIdentityUsesPrefixTimestampAndShortSuffix() throws {
        let root = temporaryDirectory()
        let store = FileEphemeralRunRecordStore(
            root: root,
            timestampProvider: { "20260602-224500" },
            suffixGenerator: { "a1b2c3" }
        )

        let identity = try store.allocateIdentity(namePrefix: "agent")

        XCTAssertEqual(identity.runID, "20260602-224500-a1b2c3")
        XCTAssertEqual(identity.sandboxName.rawValue, "agent-20260602-224500-a1b2c3")
        XCTAssertEqual(identity.recordPath, root.appendingPathComponent("20260602-224500-a1b2c3", isDirectory: true).path)
    }

    func testAllocateIdentityValidatesGeneratedSandboxName() throws {
        let store = FileEphemeralRunRecordStore(
            root: temporaryDirectory(),
            timestampProvider: { "20260602-224500" },
            suffixGenerator: { "not valid" }
        )

        XCTAssertThrowsError(try store.allocateIdentity(namePrefix: "ephemeral")) { error in
            XCTAssertTrue(String(describing: error).contains("invalidCharacters"), "got \(error)")
        }
    }

    func testAllocateIdentityProducesUniqueHumanReadableNamesAndPathsAcrossCalls() throws {
        let root = temporaryDirectory()
        var suffixes = ["a1b2c3", "d4e5f6"]
        let store = FileEphemeralRunRecordStore(
            root: root,
            timestampProvider: { "20260602-224500" },
            suffixGenerator: { suffixes.removeFirst() }
        )

        let first = try store.allocateIdentity(namePrefix: "ephemeral")
        let second = try store.allocateIdentity(namePrefix: "ephemeral")

        XCTAssertEqual(first.sandboxName.rawValue, "ephemeral-20260602-224500-a1b2c3")
        XCTAssertEqual(second.sandboxName.rawValue, "ephemeral-20260602-224500-d4e5f6")
        XCTAssertNotEqual(first.runID, second.runID)
        XCTAssertNotEqual(first.recordPath, second.recordPath)
    }

    func testCreateAttemptWritesAllocatedIdentityBeforeLaterRunArtifacts() throws {
        let root = temporaryDirectory()
        let store = FileEphemeralRunRecordStore(
            root: root,
            timestampProvider: { "20260602-224500" },
            suffixGenerator: { "a1b2c3" }
        )
        let identity = try store.allocateIdentity(namePrefix: "ephemeral")

        try store.createAttempt(
            identity: identity,
            sourceSpecText: "schemaVersion: 1\n",
            sourcePath: "/tmp/ephemeral.yaml"
        )

        let identityJSON = try String(contentsOf: URL(fileURLWithPath: identity.recordPath).appendingPathComponent("identity.json"), encoding: .utf8)
        XCTAssertTrue(identityJSON.contains("\"runID\": \"20260602-224500-a1b2c3\""))
        XCTAssertTrue(identityJSON.contains("\"sandboxName\": \"ephemeral-20260602-224500-a1b2c3\""))
        XCTAssertTrue(identityJSON.contains("\"recordPath\": \"") )
        XCTAssertFalse(FileManager.default.fileExists(atPath: URL(fileURLWithPath: identity.recordPath).appendingPathComponent("generated-sandbox-spec.yaml").path))
    }

    private func temporaryDirectory() -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("sand-tests-\(UUID().uuidString)", isDirectory: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: url)
        }
        return url
    }
}
