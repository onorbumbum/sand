import XCTest
@testable import SandCore

final class LifecycleCoordinatorTests: XCTestCase {
    func testDoctorPrintsConciseSuccessOutputForDailyUse() throws {
        var output: [String] = []
        let coordinator = LifecycleCoordinator(
            metadataStore: MemoryMetadataStore(),
            backend: RecordingSandboxBackend(status: .running),
            doctorPlatform: FixedDoctorPlatform(isSupported: true),
            writeOutput: { output.append($0) }
        )

        let result = try coordinator.doctor()

        XCTAssertEqual(result, .success)
        XCTAssertEqual(output, ["sand doctor: all Sandbox VM prerequisites OK"])
    }

    func testDoctorRunsFullPrerequisiteChecksIncludingHostMetadata() throws {
        let metadataStore = MemoryMetadataStore(writable: false)
        let backend = RecordingSandboxBackend(status: .running)
        let coordinator = LifecycleCoordinator(
            metadataStore: metadataStore,
            backend: backend,
            doctorPlatform: FixedDoctorPlatform(isSupported: true),
            writeOutput: { _ in }
        )

        let result = try coordinator.doctor()

        XCTAssertEqual(result, .failure(exitCode: 1))
        XCTAssertEqual(backend.calls, [.checkReadiness])
    }

    func testCreateWritesSpecAndProvisionsBackendLeavingSandboxStopped() throws {
        let name = try SandboxName("mybox")
        let metadataStore = MemoryMetadataStore()
        let backend = RecordingSandboxBackend(status: .missing)
        let coordinator = LifecycleCoordinator(metadataStore: metadataStore, backend: backend)

        let result = try coordinator.create(CreateRequest(sandboxName: name))

        XCTAssertEqual(result, .success)
        XCTAssertEqual(try metadataStore.readSpec(named: name), SandboxSpec.generated(name: name))
        XCTAssertEqual(backend.calls, [.provision("mybox")])
        XCTAssertEqual(backend.runtimeStatus, .stopped)
        XCTAssertEqual(metadataStore.lockEvents, ["enter", "exit"])
    }

    func testApplyReconcilesStoredSpecThroughBackendUnderLifecycleLock() throws {
        let spec = SandboxSpec.generated(name: try SandboxName("mybox"))
        let metadataStore = MemoryMetadataStore(specs: [spec])
        let backend = RecordingSandboxBackend(status: .stopped)
        let coordinator = LifecycleCoordinator(metadataStore: metadataStore, backend: backend)

        let result = try coordinator.apply(NamedSandboxRequest(sandboxName: spec.name))

        XCTAssertEqual(result, .success)
        XCTAssertEqual(backend.calls, [.apply("mybox")])
        XCTAssertEqual(metadataStore.lockEvents, ["enter", "exit"])
    }

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
        XCTAssertEqual(metadataStore.lockEvents, [])
    }

    func testShellAutoStartsStoppedSandboxAndUsesMappedWorkingDirectory() throws {
        let spec = try specWithAllowedFolder()
        let metadataStore = MemoryMetadataStore(specs: [spec], currentHostDirectory: "/Users/onur/Projects/sand")
        let backend = RecordingSandboxBackend(status: .stopped)
        let coordinator = LifecycleCoordinator(metadataStore: metadataStore, backend: backend)

        let result = try coordinator.shell(ShellRequest(sandboxName: spec.name))

        XCTAssertEqual(result, .success)
        XCTAssertEqual(backend.calls, [.status("mybox"), .start("mybox"), .shell("mybox", "/workspace/sand")])
        XCTAssertEqual(metadataStore.lockEvents, [])
    }

    func testStartStopAndDeleteAreLifecycleMutationsAndUpdateBackendState() throws {
        let spec = SandboxSpec.generated(name: try SandboxName("mybox"))
        let metadataStore = MemoryMetadataStore(specs: [spec])
        let backend = RecordingSandboxBackend(status: .stopped)
        let prompt = RecordingPromptConfirmation(decisions: [.proceed])
        let coordinator = LifecycleCoordinator(metadataStore: metadataStore, backend: backend, prompt: prompt)

        XCTAssertEqual(try coordinator.start(NamedSandboxRequest(sandboxName: spec.name)), .success)
        XCTAssertEqual(try coordinator.stop(NamedSandboxRequest(sandboxName: spec.name)), .success)
        XCTAssertEqual(try coordinator.delete(DeleteRequest(sandboxName: spec.name)), .success)

        XCTAssertEqual(backend.calls, [.start("mybox"), .stop("mybox"), .delete("mybox")])
        XCTAssertEqual(prompt.requests, [ConfirmationRequest(message: "Delete Sandbox VM mybox?", destructive: true)])
        XCTAssertEqual(metadataStore.lockEvents, ["enter", "exit", "enter", "exit", "enter", "exit"])
        XCTAssertThrowsError(try metadataStore.readSpec(named: spec.name))
    }

    func testDeleteCancelledByPromptDoesNotMutateBackendOrMetadata() throws {
        let spec = SandboxSpec.generated(name: try SandboxName("mybox"))
        let metadataStore = MemoryMetadataStore(specs: [spec])
        let backend = RecordingSandboxBackend(status: .stopped)
        let prompt = RecordingPromptConfirmation(decisions: [.cancel])
        let coordinator = LifecycleCoordinator(metadataStore: metadataStore, backend: backend, prompt: prompt)

        XCTAssertEqual(try coordinator.delete(DeleteRequest(sandboxName: spec.name)), .failure(exitCode: 1))

        XCTAssertEqual(backend.calls, [])
        XCTAssertEqual(try metadataStore.readSpec(named: spec.name), spec)
    }

    func testFolderAddMutatesSpecAndAutoAppliesThroughFakeBackend() throws {
        let spec = SandboxSpec.generated(name: try SandboxName("mybox"))
        let metadataStore = MemoryMetadataStore(specs: [spec])
        let backend = RecordingSandboxBackend(status: .stopped)
        let policy = FolderPolicy(resolvePath: { $0 })
        let coordinator = LifecycleCoordinator(metadataStore: metadataStore, backend: backend, folderPolicy: policy)

        let result = try coordinator.addFolder(AddFolderRequest(sandboxName: spec.name, displayHostPath: "/Users/onur/Projects/sand", accessMode: "rw"))

        XCTAssertEqual(result, .success)
        XCTAssertEqual(try metadataStore.readSpec(named: spec.name).allowedFolders.count, 1)
        XCTAssertEqual(backend.calls, [.status("mybox"), .apply("mybox")])
    }

    func testNormalRunAndShellAreNotSerializedBehindLifecycleMutationLocks() throws {
        let spec = try specWithAllowedFolder()
        let metadataStore = MemoryMetadataStore(specs: [spec], currentHostDirectory: "/Users/onur/Projects/sand")
        let backend = RecordingSandboxBackend(status: .running)
        let coordinator = LifecycleCoordinator(metadataStore: metadataStore, backend: backend)

        _ = try coordinator.run(RunRequest(sandboxName: spec.name, command: try WorkloadCommand(arguments: ["echo", "ok"])))
        _ = try coordinator.shell(ShellRequest(sandboxName: spec.name))

        XCTAssertEqual(metadataStore.lockEvents, [])
        XCTAssertEqual(backend.calls, [.status("mybox"), .run("mybox", ["echo", "ok"], "/workspace/sand"), .status("mybox"), .shell("mybox", "/workspace/sand")])
    }

    private func specWithAllowedFolder() throws -> SandboxSpec {
        SandboxSpec(
            name: try SandboxName("mybox"),
            allowedFolders: [AllowedFolder(displayHostPath: "~/Projects/sand", resolvedHostPath: "/Users/onur/Projects/sand", guestPath: try GuestPath("/workspace/sand"), accessMode: .readWrite)]
        )
    }
}

private struct FixedDoctorPlatform: DoctorPlatform {
    var isSupported: Bool
}
