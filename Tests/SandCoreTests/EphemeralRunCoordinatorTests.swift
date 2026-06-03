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
            "record.allocateIdentity",
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

    init(identity: EphemeralRunIdentity, events: @escaping (String) -> Void) {
        self.identity = identity
        self.recordEvent = events
    }

    func allocateIdentity(namePrefix: String) throws -> EphemeralRunIdentity {
        recordEvent("record.allocateIdentity")
        return identity
    }

    func createAttempt(identity: EphemeralRunIdentity, sourceSpecText: String, sourcePath: String) throws {
        recordEvent("record.createAttempt")
    }

    func writeGeneratedSpec(_ spec: SandboxSpec, identity: EphemeralRunIdentity) throws {
        recordEvent("record.writeGeneratedSpec")
    }

    func writeResult(_ result: EphemeralRunResult, identity: EphemeralRunIdentity) throws {
        resultStatus = result.status
        recordEvent("record.writeResult.\(result.status)")
    }
}
