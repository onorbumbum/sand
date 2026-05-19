import XCTest
@testable import SandCore

final class HostMetadataStoreTests: XCTestCase {
    func testFileStoreCreatesReadsUpdatesDeletesAndListsSpecsWithSchemaVersion() throws {
        let root = temporaryDirectory()
        let store = FileHostMetadataStore(root: root)
        let mybox = SandboxSpec.generated(name: try SandboxName("mybox"))
        let other = SandboxSpec.generated(name: try SandboxName("other"))

        XCTAssertEqual(try store.schemaVersion(), 1)
        try store.createSpec(mybox)
        try store.createSpec(other)

        XCTAssertEqual(try store.readSpec(named: try SandboxName("mybox")), mybox)
        XCTAssertEqual(try store.listSpecs().map(\.name.rawValue), ["mybox", "other"])

        let updated = SandboxSpec(
            name: try SandboxName("mybox"),
            allowedFolders: [AllowedFolder(displayHostPath: "~/Projects", resolvedHostPath: "/Users/onur/Projects", guestPath: try GuestPath("/workspace/Projects"), accessMode: .readWrite)]
        )
        try store.writeSpec(updated)
        XCTAssertEqual(try store.readSpec(named: try SandboxName("mybox")), updated)

        try store.deleteSpec(named: try SandboxName("mybox"))
        XCTAssertThrowsError(try store.readSpec(named: try SandboxName("mybox"))) { error in
            XCTAssertEqual(error as? HostMetadataError, .specNotFound("mybox"))
        }
    }

    func testGlobalSandboxNameUniquenessIsRejectedByMetadataStore() throws {
        let store = MemoryMetadataStore()
        let spec = SandboxSpec.generated(name: try SandboxName("mybox"))

        try store.createSpec(spec)

        XCTAssertThrowsError(try store.createSpec(spec)) { error in
            XCTAssertEqual(error as? HostMetadataError, .duplicateSandboxName("mybox"))
        }
    }

    func testUnsupportedHostMetadataSchemaVersionIsRejected() throws {
        let root = temporaryDirectory()
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try "99\n".write(to: root.appendingPathComponent("schema-version"), atomically: true, encoding: .utf8)
        let store = FileHostMetadataStore(root: root)

        XCTAssertThrowsError(try store.schemaVersion()) { error in
            XCTAssertEqual(error as? HostMetadataError, .unsupportedSchemaVersion(99))
        }
    }

    func testFileWritesAreAtomicFromPublicContractPerspective() throws {
        let root = temporaryDirectory()
        let store = FileHostMetadataStore(root: root)
        let name = try SandboxName("mybox")
        try store.createSpec(SandboxSpec.generated(name: name))
        let updated = SandboxSpec(name: name, image: SandboxImage(reference: "sand/updated:ubuntu-lts"))

        try store.writeSpec(updated)

        XCTAssertEqual(try store.readSpec(named: name), updated)
        let files = try FileManager.default.contentsOfDirectory(atPath: root.appendingPathComponent("specs").path)
        XCTAssertFalse(files.contains { $0.hasSuffix(".tmp") })
    }

    func testLifecycleMutationLockSerializesOperations() throws {
        let store = MemoryMetadataStore()

        try store.withLifecycleMutationLock {
            store.lockEvents.append("first")
        }
        try store.withLifecycleMutationLock {
            store.lockEvents.append("second")
        }

        XCTAssertEqual(store.lockEvents, ["enter", "first", "exit", "enter", "second", "exit"])
    }

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    }
}
