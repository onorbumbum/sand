import XCTest
@testable import SandCore

final class LifecycleCoordinatorTests: XCTestCase {
    func testRunAutoStartsStoppedSandboxAndDelegatesOpaqueCommandToBackend() throws {
        let name = try SandboxName("mybox")
        let spec = SandboxSpec(
            name: name,
            allowedFolders: [
                AllowedFolder(
                    displayHostPath: "~/Projects/sand",
                    resolvedHostPath: "/Users/onur/Projects/sand",
                    guestPath: try GuestPath("/workspace/sand"),
                    accessMode: .readWrite
                )
            ]
        )
        let metadataStore = MemoryMetadataStore(specs: [spec], currentHostDirectory: "/Users/onur/Projects/sand/Sources")
        let backend = RecordingSandboxBackend(status: .stopped)
        let coordinator = LifecycleCoordinator(metadataStore: metadataStore, backend: backend)

        let result = try coordinator.run(
            RunRequest(
                sandboxName: name,
                command: try WorkloadCommand(arguments: ["pi", "--model", "gpt-5"])
            )
        )

        XCTAssertEqual(result, .success)
        XCTAssertEqual(backend.calls, [.status("mybox"), .start("mybox"), .run("mybox", ["pi", "--model", "gpt-5"], "/workspace/sand/Sources")])
    }
}
