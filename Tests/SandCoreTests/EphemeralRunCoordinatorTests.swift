import XCTest
@testable import SandCore

final class EphemeralRunCoordinatorTests: XCTestCase {
    func testMinimalEphemeralSpecRunsHappyPathAndCleansUpActiveMetadata() throws {
        let sandboxName = try SandboxName("ephemeral-20260602-abcd")
        var events: [String] = []
        let metadataStore = RecordingEphemeralMetadataStore(events: { events.append($0) })
        let backend = RecordingSandboxBackend(status: .missing, events: { events.append($0) })
        let runRecordStore = RecordingEphemeralRunRecordStore(
            identity: EphemeralRunIdentity(
                runID: "run-001",
                sandboxName: sandboxName,
                recordPath: "/tmp/sand-runs/run-001"
            ),
            events: { events.append($0) }
        )
        var output: [String] = []
        let coordinator = EphemeralRunCoordinator(
            metadataStore: metadataStore,
            backend: backend,
            runRecordStore: runRecordStore,
            writeOutput: { output.append($0) }
        )
        let specText = """
        schemaVersion: 1
        workload:
          command: echo
          args:
            - hello
          workdir: /workspace
        """

        let result = try coordinator.run(
            EphemeralRunRequest(
                authoredSpecText: specText,
                sourcePath: "/tmp/ephemeral-spec.yaml"
            )
        )

        XCTAssertEqual(result, .success)
        XCTAssertEqual(metadataStore.activeSpecNames, [])
        XCTAssertEqual(backend.calls, [
            .provision("ephemeral-20260602-abcd"),
            .start("ephemeral-20260602-abcd"),
            .run("ephemeral-20260602-abcd", ["echo", "hello"], "/workspace"),
            .stop("ephemeral-20260602-abcd"),
            .delete("ephemeral-20260602-abcd")
        ])
        XCTAssertEqual(events, [
            "record.allocateIdentity.ephemeral",
            "record.createAttempt",
            "record.writeGeneratedSpec",
            "metadata.createSpec.ephemeral-20260602-abcd",
            "backend.provision.ephemeral-20260602-abcd",
            "backend.start.ephemeral-20260602-abcd",
            "backend.run.ephemeral-20260602-abcd.echo hello./workspace",
            "backend.stop.ephemeral-20260602-abcd",
            "backend.delete.ephemeral-20260602-abcd",
            "metadata.deleteSpec.ephemeral-20260602-abcd",
            "record.writeResult.success"
        ])
        XCTAssertEqual(runRecordStore.resultStatus, "success")
        XCTAssertEqual(output, [
            "Ephemeral run status: success",
            "Run record: /tmp/sand-runs/run-001"
        ])
    }

    func testEphemeralSpecDefaultsRemainValidAndArePlannedBeforeSideEffects() throws {
        let sandboxName = try SandboxName("ephemeral-20260602-abcd")
        var events: [String] = []
        let metadataStore = RecordingEphemeralMetadataStore(events: { events.append($0) })
        let backend = RecordingSandboxBackend(status: .missing, events: { events.append($0) })
        let runRecordStore = RecordingEphemeralRunRecordStore(
            identity: EphemeralRunIdentity(
                runID: "run-001",
                sandboxName: sandboxName,
                recordPath: "/tmp/sand-runs/run-001"
            ),
            events: { events.append($0) }
        )
        let coordinator = EphemeralRunCoordinator(
            metadataStore: metadataStore,
            backend: backend,
            runRecordStore: runRecordStore,
            writeOutput: { _ in }
        )
        let specText = """
        schemaVersion: 1
        workload:
          command: echo
          workdir: /workspace
        """

        let result = try coordinator.run(
            EphemeralRunRequest(
                authoredSpecText: specText,
                sourcePath: "/tmp/ephemeral-spec.yaml"
            )
        )

        XCTAssertEqual(result, .success)
        XCTAssertEqual(runRecordStore.allocatedNamePrefixes, ["ephemeral"])
        XCTAssertEqual(backend.calls, [
            .provision("ephemeral-20260602-abcd"),
            .start("ephemeral-20260602-abcd"),
            .run("ephemeral-20260602-abcd", ["echo"], "/workspace"),
            .stop("ephemeral-20260602-abcd"),
            .delete("ephemeral-20260602-abcd")
        ])
        XCTAssertEqual(runRecordStore.generatedSpecs.map(\.image.reference), [SandboxImage.developerReadyDefault.reference])
        XCTAssertEqual(runRecordStore.generatedSpecs.map(\.resourceProfile), [ResourceProfile.default])
        XCTAssertEqual(events.prefix(3), [
            "record.allocateIdentity.ephemeral",
            "record.createAttempt",
            "record.writeGeneratedSpec"
        ])
    }

    func testMalformedEphemeralSpecsFailBeforeRunRecordMetadataAndBackendSideEffects() throws {
        let invalidSpecs: [(name: String, text: String, expectedErrorFragment: String)] = [
            (
                "unsupported schema version",
                """
                schemaVersion: 2
                workload:
                  command: echo
                  workdir: /workspace
                """,
                "unsupported ephemeral spec schema version: 2"
            ),
            (
                "missing effective workload",
                """
                schemaVersion: 1
                """,
                "missing ephemeral spec field: workload.command"
            ),
            (
                "empty command",
                """
                schemaVersion: 1
                workload:
                  command:
                  workdir: /workspace
                """,
                "ephemeral workload command cannot be empty"
            ),
            (
                "unsupported workload command-list shorthand",
                """
                schemaVersion: 1
                workload:
                  - echo
                """,
                "unsupported v1 ephemeral command-list shorthand"
            ),
            (
                "malformed command shape",
                """
                schemaVersion: 1
                workload:
                  command: [echo, hello]
                  workdir: /workspace
                """,
                "unsupported v1 ephemeral command-list shorthand"
            ),
            (
                "unsupported top-level field",
                """
                schemaVersion: 1
                beforeProvision:
                  command: echo
                workload:
                  command: echo
                  workdir: /workspace
                """,
                "unsupported v1 ephemeral spec field: beforeProvision"
            ),
            (
                "user-authored resolvedHostPath",
                """
                schemaVersion: 1
                workload:
                  command: echo
                  workdir: /workspace
                allowedFolders:
                  - hostPath: ./work
                    resolvedHostPath: /tmp/work
                    guestPath: /workspace/work
                    accessMode: read-write
                """,
                "unsupported v1 ephemeral spec field: allowedFolders.resolvedHostPath"
            ),
            (
                "invalid namePrefix",
                """
                schemaVersion: 1
                namePrefix: not valid!
                workload:
                  command: echo
                  workdir: /workspace
                """,
                "invalid ephemeral namePrefix"
            )
        ]

        for invalidSpec in invalidSpecs {
            let sandboxName = try SandboxName("ephemeral-20260602-abcd")
            var events: [String] = []
            let metadataStore = RecordingEphemeralMetadataStore(events: { events.append($0) })
            let backend = RecordingSandboxBackend(status: .missing, events: { events.append($0) })
            let runRecordStore = RecordingEphemeralRunRecordStore(
                identity: EphemeralRunIdentity(
                    runID: "run-001",
                    sandboxName: sandboxName,
                    recordPath: "/tmp/sand-runs/run-001"
                ),
                events: { events.append($0) }
            )
            let coordinator = EphemeralRunCoordinator(
                metadataStore: metadataStore,
                backend: backend,
                runRecordStore: runRecordStore,
                writeOutput: { _ in }
            )

            XCTAssertThrowsError(
                try coordinator.run(
                    EphemeralRunRequest(
                        authoredSpecText: invalidSpec.text,
                        sourcePath: "/tmp/ephemeral-spec.yaml"
                    )
                ),
                invalidSpec.name
            ) { error in
                XCTAssertTrue(
                    String(describing: error).contains(invalidSpec.expectedErrorFragment),
                    "\(invalidSpec.name) expected \(invalidSpec.expectedErrorFragment), got \(error)"
                )
            }
            XCTAssertEqual(events, [], invalidSpec.name)
            XCTAssertEqual(backend.calls, [], invalidSpec.name)
            XCTAssertEqual(metadataStore.activeSpecNames, [], invalidSpec.name)
        }
    }
}

private final class RecordingEphemeralMetadataStore: HostMetadataStore {
    private var specsByName: [String: SandboxSpec] = [:]
    private let recordEvent: (String) -> Void

    init(events: @escaping (String) -> Void) {
        self.recordEvent = events
    }

    var activeSpecNames: [String] {
        specsByName.keys.sorted()
    }

    func createSpec(_ spec: SandboxSpec) throws {
        recordEvent("metadata.createSpec.\(spec.name.rawValue)")
        if specsByName[spec.name.rawValue] != nil {
            throw HostMetadataError.duplicateSandboxName(spec.name.rawValue)
        }
        specsByName[spec.name.rawValue] = spec
    }

    func readSpec(named name: SandboxName) throws -> SandboxSpec {
        guard let spec = specsByName[name.rawValue] else {
            throw HostMetadataError.specNotFound(name.rawValue)
        }
        return spec
    }

    func readCreatedSpec(named name: SandboxName) throws -> SandboxSpec {
        try readSpec(named: name)
    }

    func writeSpec(_ spec: SandboxSpec) throws {
        specsByName[spec.name.rawValue] = spec
    }

    func deleteSpec(named name: SandboxName) throws {
        recordEvent("metadata.deleteSpec.\(name.rawValue)")
        specsByName.removeValue(forKey: name.rawValue)
    }

    func listSpecs() throws -> [SandboxSpec] {
        Array(specsByName.values)
    }

    func currentHostDirectory() -> String { "/workspace" }
    func schemaVersion() throws -> Int { SandboxSpec.supportedSchemaVersion }
    func checkWritability() throws {}

    func withLifecycleMutationLock<T>(_ operation: () throws -> T) throws -> T {
        try operation()
    }
}

private final class RecordingEphemeralRunRecordStore: EphemeralRunRecordStore {
    let identity: EphemeralRunIdentity
    private let recordEvent: (String) -> Void
    private(set) var resultStatus: String?
    private(set) var allocatedNamePrefixes: [String] = []
    private(set) var generatedSpecs: [SandboxSpec] = []

    init(identity: EphemeralRunIdentity, events: @escaping (String) -> Void) {
        self.identity = identity
        self.recordEvent = events
    }

    func allocateIdentity(namePrefix: String) throws -> EphemeralRunIdentity {
        allocatedNamePrefixes.append(namePrefix)
        recordEvent("record.allocateIdentity.\(namePrefix)")
        return identity
    }

    func createAttempt(identity: EphemeralRunIdentity, sourceSpecText: String, sourcePath: String) throws {
        recordEvent("record.createAttempt")
    }

    func writeGeneratedSpec(_ spec: SandboxSpec, identity: EphemeralRunIdentity) throws {
        generatedSpecs.append(spec)
        recordEvent("record.writeGeneratedSpec")
    }

    func writeResult(_ result: EphemeralRunResult, identity: EphemeralRunIdentity) throws {
        resultStatus = result.status
        recordEvent("record.writeResult.\(result.status)")
    }
}
