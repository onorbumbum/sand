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

    func testRunRecordDoesNotCreateForegroundWorkloadTranscriptArtifactsByDefault() throws {
        let root = temporaryDirectory()
        let store = FileEphemeralRunRecordStore(
            root: root,
            timestampProvider: { "20260602-224500" },
            suffixGenerator: { "a1b2c3" }
        )
        let identity = try store.allocateIdentity(namePrefix: "ephemeral")
        let recordDirectory = URL(fileURLWithPath: identity.recordPath, isDirectory: true)

        try store.createAttempt(
            identity: identity,
            sourceSpecText: "schemaVersion: 1\nworkload:\n  command: secret-chat\n  workdir: /workspace\n",
            sourcePath: "/tmp/ephemeral.yaml"
        )
        try store.writeGeneratedSpec(SandboxSpec.generated(name: identity.sandboxName), identity: identity)
        try store.writeResult(EphemeralRunResult(status: "success", exitCode: 0, recordPath: identity.recordPath), identity: identity)

        let artifactNames = try FileManager.default.contentsOfDirectory(atPath: recordDirectory.path)
        XCTAssertEqual(Set(artifactNames), [
            "identity.json",
            "source-ephemeral-spec.yaml",
            "source-path.txt",
            "generated-sandbox-spec.yaml",
            "result.json"
        ])
        XCTAssertFalse(artifactNames.contains { $0.localizedCaseInsensitiveContains("transcript") })
        XCTAssertFalse(artifactNames.contains { $0.localizedCaseInsensitiveContains("workload") && $0.hasSuffix(".stdout") })
        XCTAssertFalse(artifactNames.contains { $0.localizedCaseInsensitiveContains("workload") && $0.hasSuffix(".stderr") })
    }

    func testRunRecordArtifactsAreCompleteJsonLinesAndRetainedAfterResult() throws {
        let root = temporaryDirectory()
        let store = FileEphemeralRunRecordStore(
            root: root,
            timestampProvider: { "20260602-224500" },
            suffixGenerator: { "a1b2c3" }
        )
        let identity = try store.allocateIdentity(namePrefix: "agent")
        let recordDirectory = URL(fileURLWithPath: identity.recordPath, isDirectory: true)
        let sourceSpec = """
        schemaVersion: 1
        description: inspectable history
        workload:
          command: echo
          workdir: /workspace
        """
        let generatedSpec = SandboxSpec(
            name: identity.sandboxName,
            image: SandboxImage(reference: "registry.example/sand:test"),
            resourceProfile: ResourceProfile(cpus: 2, memory: MemorySize(gigabytes: 4)),
            allowedFolders: [
                AllowedFolder(
                    displayHostPath: "./work",
                    resolvedHostPath: "/tmp/project/work",
                    guestPath: try GuestPath("/workspace/work"),
                    accessMode: .readWrite
                )
            ]
        )

        try store.createAttempt(identity: identity, sourceSpecText: sourceSpec, sourcePath: "/tmp/project/ephemeral.yaml")
        try store.writeGeneratedSpec(generatedSpec, identity: identity)
        let firstOutput = try store.writeHookOutput(phase: "beforeProvision", index: 0, stdout: "created\n", stderr: "warn\n", identity: identity)
        try store.appendEvent(
            EphemeralRunEvent(
                phase: "beforeProvision",
                status: "success",
                command: ["mkdir", "-p", "work"],
                workingDirectory: "/tmp/project",
                exitCode: 0,
                stdoutPath: firstOutput.stdoutPath,
                stderrPath: firstOutput.stderrPath
            ),
            identity: identity
        )
        let secondOutput = try store.writeHookOutput(phase: "afterStop", index: 0, stdout: "archived\n", stderr: "", identity: identity)
        try store.appendEvent(
            EphemeralRunEvent(
                phase: "afterStop",
                status: "failure",
                command: ["archive-output"],
                workingDirectory: "/tmp/project",
                exitCode: 23,
                stdoutPath: secondOutput.stdoutPath,
                stderrPath: secondOutput.stderrPath
            ),
            identity: identity
        )
        try store.writeResult(
            EphemeralRunResult(
                status: "failure",
                exitCode: 23,
                recordPath: identity.recordPath,
                failedPhase: "afterStop",
                manualCleanupGuidance: "Delete Sandbox VM agent-20260602-224500-a1b2c3 manually with: sand delete agent-20260602-224500-a1b2c3 --force"
            ),
            identity: identity
        )

        XCTAssertEqual(try String(contentsOf: recordDirectory.appendingPathComponent("source-ephemeral-spec.yaml"), encoding: .utf8), sourceSpec)
        XCTAssertEqual(try String(contentsOf: recordDirectory.appendingPathComponent("source-path.txt"), encoding: .utf8), "/tmp/project/ephemeral.yaml\n")
        XCTAssertEqual(try String(contentsOf: recordDirectory.appendingPathComponent("generated-sandbox-spec.yaml"), encoding: .utf8), generatedSpec.renderedYAML())
        XCTAssertEqual(try String(contentsOf: URL(fileURLWithPath: firstOutput.stdoutPath), encoding: .utf8), "created\n")
        XCTAssertEqual(try String(contentsOf: URL(fileURLWithPath: firstOutput.stderrPath), encoding: .utf8), "warn\n")
        XCTAssertEqual(try String(contentsOf: URL(fileURLWithPath: secondOutput.stdoutPath), encoding: .utf8), "archived\n")
        XCTAssertEqual(try String(contentsOf: URL(fileURLWithPath: secondOutput.stderrPath), encoding: .utf8), "")

        let eventLines = try String(contentsOf: recordDirectory.appendingPathComponent("events.jsonl"), encoding: .utf8)
            .split(separator: "\n")
            .map(String.init)
        XCTAssertEqual(eventLines.count, 2)
        XCTAssertTrue(eventLines[0].contains("\"phase\":\"beforeProvision\""), eventLines[0])
        XCTAssertTrue(eventLines[0].contains("\"stdoutPath\":\"") && eventLines[0].contains("beforeProvision-0.stdout"), eventLines[0])
        XCTAssertTrue(eventLines[1].contains("\"phase\":\"afterStop\""), eventLines[1])
        XCTAssertTrue(eventLines[1].contains("\"exitCode\":23"), eventLines[1])

        let resultJSON = try String(contentsOf: recordDirectory.appendingPathComponent("result.json"), encoding: .utf8)
        XCTAssertTrue(resultJSON.contains("\"status\": \"failure\""), resultJSON)
        XCTAssertTrue(resultJSON.contains("\"failedPhase\": \"afterStop\""), resultJSON)
        XCTAssertTrue(resultJSON.contains("\"exitCode\": 23"), resultJSON)
        XCTAssertTrue(resultJSON.contains("\"sandboxName\": \"agent-20260602-224500-a1b2c3\""), resultJSON)
        XCTAssertTrue(resultJSON.contains("\"manualCleanupGuidance\":"), resultJSON)
        XCTAssertTrue(FileManager.default.fileExists(atPath: identity.recordPath), "run record should be retained indefinitely by default")
    }

    private func temporaryDirectory() -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("sand-tests-\(UUID().uuidString)", isDirectory: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: url)
        }
        return url
    }
}
