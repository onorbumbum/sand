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

    func testDuplicateSandboxNameErrorIsClearForCLIOutput() throws {
        let error = HostMetadataError.duplicateSandboxName("mybox")

        XCTAssertEqual(String(describing: error), "sandbox already exists: mybox")
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

    func testFileLifecycleMutationLockSerializesSeparateStoreInstancesSharingRoot() throws {
        let root = temporaryDirectory()
        let firstStore = UncheckedSendableBox(FileHostMetadataStore(root: root))
        let secondStore = UncheckedSendableBox(FileHostMetadataStore(root: root))
        let firstEntered = DispatchSemaphore(value: 0)
        let releaseFirst = DispatchSemaphore(value: 0)
        let secondFinished = DispatchSemaphore(value: 0)
        let events = LockedEvents()

        DispatchQueue.global().async {
            try? firstStore.value.withLifecycleMutationLock {
                events.append("first-enter")
                firstEntered.signal()
                _ = releaseFirst.wait(timeout: .now() + 2)
            }
        }
        XCTAssertEqual(firstEntered.wait(timeout: .now() + 1), .success)

        DispatchQueue.global().async {
            try? secondStore.value.withLifecycleMutationLock {
                events.append("second-enter")
            }
            secondFinished.signal()
        }

        XCTAssertEqual(secondFinished.wait(timeout: .now() + 0.2), .timedOut)
        releaseFirst.signal()
        XCTAssertEqual(secondFinished.wait(timeout: .now() + 1), .success)
        XCTAssertEqual(events.snapshot(), ["first-enter", "second-enter"])
    }

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    }
}

private final class UncheckedSendableBox<Value>: @unchecked Sendable {
    let value: Value

    init(_ value: Value) {
        self.value = value
    }
}

private final class LockedEvents: @unchecked Sendable {
    private let lock = NSLock()
    private var events: [String] = []

    func append(_ event: String) {
        lock.lock()
        events.append(event)
        lock.unlock()
    }

    func snapshot() -> [String] {
        lock.lock()
        let copy = events
        lock.unlock()
        return copy
    }
}
