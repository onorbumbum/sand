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
        var output: [String] = []
        let coordinator = LifecycleCoordinator(metadataStore: metadataStore, backend: backend, writeOutput: { output.append($0) })

        let result = try coordinator.create(CreateRequest(sandboxName: name))

        XCTAssertEqual(result, .success)
        XCTAssertEqual(try metadataStore.readSpec(named: name), SandboxSpec.generated(name: name))
        XCTAssertEqual(backend.calls, [.provision("mybox")])
        XCTAssertEqual(backend.runtimeStatus, .stopped)
        XCTAssertEqual(metadataStore.lockEvents, ["enter", "exit"])
        XCTAssertEqual(output, ["Creating Sandbox VM mybox...", "Created Sandbox VM mybox."])
    }

    func testListPrintsConciseStatusForStoredSandboxes() throws {
        var output: [String] = []
        let mybox = SandboxSpec.generated(name: try SandboxName("mybox"))
        let other = SandboxSpec(name: try SandboxName("other"), image: SandboxImage(reference: "custom:latest"))
        let metadataStore = MemoryMetadataStore(specs: [other, mybox])
        let backend = RecordingSandboxBackend(status: .stopped)
        let coordinator = LifecycleCoordinator(metadataStore: metadataStore, backend: backend, writeOutput: { output.append($0) })

        let result = try coordinator.list()

        XCTAssertEqual(result, .success)
        XCTAssertEqual(output, [
            "mybox\tstopped\tlinux\tsand/developer-ready:ubuntu-lts\t0 folders",
            "other\tstopped\tlinux\tcustom:latest\t0 folders"
        ])
        XCTAssertEqual(backend.calls, [.status("mybox"), .status("other")])
    }

    func testCreateRoutesGeneratedMacOSAndLinuxSpecsThroughResolver() throws {
        let linuxBackend = RecordingSandboxBackend(status: .missing)
        let macBackend = RecordingSandboxBackend(status: .missing)
        let resolver = RecordingBackendResolver(linuxBackend: linuxBackend, macOSBackend: macBackend)
        let metadataStore = MemoryMetadataStore()
        let coordinator = LifecycleCoordinator(metadataStore: metadataStore, backendResolver: resolver)

        XCTAssertEqual(try coordinator.create(CreateRequest(sandboxName: try SandboxName("linuxbox"))), .success)
        XCTAssertEqual(try coordinator.create(CreateRequest(sandboxName: try SandboxName("macbox"), image: SandboxImage(reference: "ghcr.io/example/macos:latest"), guestOS: .macOS, displayResolution: DisplayResolution(width: 1920, height: 1080, unit: .pixels))), .success)

        XCTAssertEqual(resolver.requestedGuestOS, [.linux, .macOS])
        XCTAssertEqual(linuxBackend.calls, [.provision("linuxbox")])
        XCTAssertEqual(macBackend.calls, [.provision("macbox")])
        let macSpec = try metadataStore.readSpec(named: try SandboxName("macbox"))
        XCTAssertEqual(macSpec.guestOS, .macOS)
        XCTAssertEqual(macSpec.resourceProfile, ResourceProfile(cpus: 4, memory: MemorySize(gigabytes: 16)))
        XCTAssertEqual(macSpec.displayResolution, DisplayResolution(width: 1920, height: 1080, unit: .pixels))
    }

    func testCreateFromIPSWRecordsSetupRequiredSpecAndGuidesUserToGuiThenBootstrap() throws {
        let linuxBackend = RecordingSandboxBackend(status: .missing)
        let macBackend = RecordingSandboxBackend(status: .missing)
        let resolver = RecordingBackendResolver(linuxBackend: linuxBackend, macOSBackend: macBackend)
        let metadataStore = MemoryMetadataStore()
        var output: [String] = []
        let coordinator = LifecycleCoordinator(metadataStore: metadataStore, backendResolver: resolver, writeOutput: { output.append($0) })

        let result = try coordinator.create(CreateRequest(sandboxName: try SandboxName("ipswbox"), image: SandboxImage(reference: "ipsw:latest"), guestOS: .macOS, ipswSource: "latest"))

        XCTAssertEqual(result, .success)
        XCTAssertEqual(macBackend.calls, [.provisionFromIPSW("ipswbox", "latest")])
        let spec = try metadataStore.readSpec(named: try SandboxName("ipswbox"))
        XCTAssertEqual(spec.guestOS, .macOS)
        XCTAssertEqual(spec.bootstrapState, .setupRequired)
        XCTAssertEqual(spec.image, SandboxImage(reference: "ipsw:latest"))
        XCTAssertEqual(output.first, "Creating setup-required macOS Sandbox VM ipswbox from IPSW...")
        let joined = output.joined(separator: "\n")
        XCTAssertTrue(joined.contains("sand gui ipswbox"))
        XCTAssertTrue(joined.contains("sand bootstrap ipswbox"))
    }

    func testBootstrapTransitionsSetupRequiredMacOSSandboxToReady() throws {
        let name = try SandboxName("ipswbox")
        let spec = SandboxSpec(name: name, image: SandboxImage(reference: "ipsw:latest"), guestOS: .macOS, bootstrapState: .setupRequired)
        let macBackend = RecordingSandboxBackend(status: .running)
        let resolver = RecordingBackendResolver(linuxBackend: RecordingSandboxBackend(), macOSBackend: macBackend)
        let store = MemoryMetadataStore(specs: [spec])
        let coordinator = LifecycleCoordinator(metadataStore: store, backendResolver: resolver, writeOutput: { _ in })

        XCTAssertEqual(try coordinator.bootstrap(NamedSandboxRequest(sandboxName: name)), .success)

        XCTAssertEqual(macBackend.calls, [.bootstrap("ipswbox")])
        XCTAssertEqual(try store.readSpec(named: name).bootstrapState, .ready)
    }

    func testBootstrapRejectsAlreadyReadySandboxWithoutCallingBackend() throws {
        let name = try SandboxName("macbox")
        let spec = SandboxSpec(name: name, image: SandboxImage(reference: "ghcr.io/example/macos:latest"), guestOS: .macOS)
        let macBackend = RecordingSandboxBackend(status: .stopped)
        let resolver = RecordingBackendResolver(linuxBackend: RecordingSandboxBackend(), macOSBackend: macBackend)
        let store = MemoryMetadataStore(specs: [spec])
        let coordinator = LifecycleCoordinator(metadataStore: store, backendResolver: resolver)

        XCTAssertThrowsError(try coordinator.bootstrap(NamedSandboxRequest(sandboxName: name))) { error in
            XCTAssertEqual(error as? SandboxBootstrapError, .alreadyBootstrapped("macbox"))
        }
        XCTAssertEqual(macBackend.calls, [])
    }

    func testBootstrapRejectsLinuxSandbox() throws {
        let name = try SandboxName("linuxbox")
        let store = MemoryMetadataStore(specs: [SandboxSpec(name: name)])
        let resolver = RecordingBackendResolver(linuxBackend: RecordingSandboxBackend(), macOSBackend: RecordingSandboxBackend())
        let coordinator = LifecycleCoordinator(metadataStore: store, backendResolver: resolver)

        XCTAssertThrowsError(try coordinator.bootstrap(NamedSandboxRequest(sandboxName: name))) { error in
            XCTAssertEqual(error as? SandboxBootstrapError, .unsupportedGuestOS("linux"))
        }
    }

    func testShellAndRunRejectSetupRequiredSandboxBeforeTouchingBackend() throws {
        let name = try SandboxName("ipswbox")
        let spec = SandboxSpec(name: name, image: SandboxImage(reference: "ipsw:latest"), guestOS: .macOS, bootstrapState: .setupRequired)
        let macBackend = RecordingSandboxBackend(status: .stopped)
        let resolver = RecordingBackendResolver(linuxBackend: RecordingSandboxBackend(), macOSBackend: macBackend)
        let store = MemoryMetadataStore(specs: [spec])
        let coordinator = LifecycleCoordinator(metadataStore: store, backendResolver: resolver, writeWarning: { _ in })

        XCTAssertThrowsError(try coordinator.shell(ShellRequest(sandboxName: name))) { error in
            XCTAssertEqual(error as? SandboxBootstrapError, .setupRequired("ipswbox"))
        }
        XCTAssertThrowsError(try coordinator.run(RunRequest(sandboxName: name, command: try WorkloadCommand(arguments: ["echo", "hi"])))) { error in
            XCTAssertEqual(error as? SandboxBootstrapError, .setupRequired("ipswbox"))
        }
        XCTAssertEqual(macBackend.calls, [])
    }

    func testCreateRollsBackHostMetadataWhenBackendProvisioningFails() throws {
        let name = try SandboxName("mybox")
        let metadataStore = MemoryMetadataStore()
        let backend = RecordingSandboxBackend(status: .missing, provisionError: BackendTestError.provisionFailed)
        let coordinator = LifecycleCoordinator(metadataStore: metadataStore, backend: backend)

        XCTAssertThrowsError(try coordinator.create(CreateRequest(sandboxName: name)))

        XCTAssertThrowsError(try metadataStore.readSpec(named: name)) { error in
            XCTAssertEqual(error as? HostMetadataError, .specNotFound("mybox"))
        }
        XCTAssertEqual(backend.calls, [.provision("mybox")])
        XCTAssertEqual(metadataStore.lockEvents, ["enter", "exit"])
    }

    func testApplyReconcilesStoredSpecThroughBackendUnderLifecycleLock() throws {
        let spec = SandboxSpec.generated(name: try SandboxName("mybox"))
        let metadataStore = MemoryMetadataStore(specs: [spec])
        let backend = RecordingSandboxBackend(status: .stopped)
        let coordinator = LifecycleCoordinator(metadataStore: metadataStore, backend: backend)

        let result = try coordinator.apply(NamedSandboxRequest(sandboxName: spec.name))

        XCTAssertEqual(result, .success)
        XCTAssertEqual(backend.calls, [.status("mybox"), .apply("mybox")])
        XCTAssertEqual(metadataStore.lockEvents, ["enter", "exit"])
    }

    func testApplyOnRunningSandboxPromptsBeforeInterruptingActiveSessions() throws {
        let spec = SandboxSpec.generated(name: try SandboxName("mybox"))
        let metadataStore = MemoryMetadataStore(specs: [spec])
        let backend = RecordingSandboxBackend(status: .running)
        let prompt = RecordingPromptConfirmation(decisions: [.cancel])
        let coordinator = LifecycleCoordinator(metadataStore: metadataStore, backend: backend, prompt: prompt)

        let result = try coordinator.apply(NamedSandboxRequest(sandboxName: spec.name))

        XCTAssertEqual(result, .failure(exitCode: 1))
        XCTAssertEqual(prompt.requests, [ConfirmationRequest(message: "Apply changes to running Sandbox VM mybox?", destructive: false)])
        XCTAssertEqual(backend.calls, [.status("mybox")])
        XCTAssertEqual(metadataStore.lockEvents, ["enter", "exit"])
    }

    func testApplyRejectsManualImageEditsAgainstCreatedSpecBeforeTouchingBackend() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let metadataStore = FileHostMetadataStore(root: root)
        let name = try SandboxName("mybox")
        let created = SandboxSpec.generated(name: name)
        try metadataStore.createSpec(created)
        let manuallyEdited = SandboxSpec(name: name, image: SandboxImage(reference: "custom:latest"))
        try manuallyEdited.renderedYAML().write(to: root.appendingPathComponent("specs/mybox.yaml"), atomically: true, encoding: .utf8)
        let backend = RecordingSandboxBackend(status: .stopped)
        let coordinator = LifecycleCoordinator(metadataStore: metadataStore, backend: backend)

        XCTAssertThrowsError(try coordinator.apply(NamedSandboxRequest(sandboxName: name))) { error in
            XCTAssertEqual(error as? SandboxSpecError, .imageImmutable)
        }
        XCTAssertEqual(backend.calls, [])
    }

    func testApplyRejectsManualOSEditsAgainstCreatedSpecBeforeTouchingBackend() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let metadataStore = FileHostMetadataStore(root: root)
        let name = try SandboxName("mybox")
        let created = SandboxSpec.generated(name: name)
        try metadataStore.createSpec(created)
        let manuallyEdited = SandboxSpec(name: name, guestOS: .macOS)
        try manuallyEdited.renderedYAML().write(to: root.appendingPathComponent("specs/mybox.yaml"), atomically: true, encoding: .utf8)
        let backend = RecordingSandboxBackend(status: .stopped)
        let coordinator = LifecycleCoordinator(metadataStore: metadataStore, backend: backend)

        XCTAssertThrowsError(try coordinator.apply(NamedSandboxRequest(sandboxName: name))) { error in
            XCTAssertEqual(error as? SandboxSpecError, .guestOSImmutable)
        }
        XCTAssertEqual(backend.calls, [])
    }

    func testApplyRejectsManualCpuEditsAgainstCreatedSpecBeforeTouchingBackend() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let metadataStore = FileHostMetadataStore(root: root)
        let name = try SandboxName("mybox")
        let created = SandboxSpec.generated(name: name)
        try metadataStore.createSpec(created)
        let manuallyEdited = SandboxSpec(name: name, resourceProfile: ResourceProfile(cpus: 8, memory: MemorySize(gigabytes: 8)))
        try manuallyEdited.renderedYAML().write(to: root.appendingPathComponent("specs/mybox.yaml"), atomically: true, encoding: .utf8)
        let backend = RecordingSandboxBackend(status: .stopped)
        let coordinator = LifecycleCoordinator(metadataStore: metadataStore, backend: backend)

        XCTAssertThrowsError(try coordinator.apply(NamedSandboxRequest(sandboxName: name))) { error in
            XCTAssertEqual(error as? SandboxSpecError, .resourceProfileImmutable(field: "cpus"))
        }
        XCTAssertEqual(backend.calls, [])
    }

    func testApplyRejectsManualMemoryEditsAgainstCreatedSpecBeforeTouchingBackend() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let metadataStore = FileHostMetadataStore(root: root)
        let name = try SandboxName("mybox")
        let created = SandboxSpec.generated(name: name)
        try metadataStore.createSpec(created)
        let manuallyEdited = SandboxSpec(name: name, resourceProfile: ResourceProfile(cpus: 4, memory: MemorySize(gigabytes: 16)))
        try manuallyEdited.renderedYAML().write(to: root.appendingPathComponent("specs/mybox.yaml"), atomically: true, encoding: .utf8)
        let backend = RecordingSandboxBackend(status: .stopped)
        let coordinator = LifecycleCoordinator(metadataStore: metadataStore, backend: backend)

        XCTAssertThrowsError(try coordinator.apply(NamedSandboxRequest(sandboxName: name))) { error in
            XCTAssertEqual(error as? SandboxSpecError, .resourceProfileImmutable(field: "memory"))
        }
        XCTAssertEqual(backend.calls, [])
    }

    func testFolderMutationRejectsExistingManualResourceEditsBeforeWritingOrApplying() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let metadataStore = FileHostMetadataStore(root: root)
        let name = try SandboxName("mybox")
        try metadataStore.createSpec(.generated(name: name))
        let manuallyEdited = SandboxSpec(name: name, resourceProfile: ResourceProfile(cpus: 8, memory: MemorySize(gigabytes: 8)))
        try manuallyEdited.renderedYAML().write(to: root.appendingPathComponent("specs/mybox.yaml"), atomically: true, encoding: .utf8)
        let backend = RecordingSandboxBackend(status: .stopped)
        let policy = FolderPolicy(resolvePath: { $0 })
        let coordinator = LifecycleCoordinator(metadataStore: metadataStore, backend: backend, folderPolicy: policy)

        XCTAssertThrowsError(try coordinator.addFolder(AddFolderRequest(sandboxName: name, displayHostPath: "/Users/onur/Projects/sand", accessMode: "rw"))) { error in
            XCTAssertEqual(error as? SandboxSpecError, .resourceProfileImmutable(field: "cpus"))
        }
        XCTAssertEqual(try metadataStore.readSpec(named: name), manuallyEdited)
        XCTAssertEqual(backend.calls, [])
    }

    func testSpecPrintsActiveSandboxSpec() throws {
        var output: [String] = []
        let spec = SandboxSpec.generated(name: try SandboxName("mybox"))
        let metadataStore = MemoryMetadataStore(specs: [spec])
        let backend = RecordingSandboxBackend(status: .stopped)
        let coordinator = LifecycleCoordinator(metadataStore: metadataStore, backend: backend, writeOutput: { output.append($0) })

        let result = try coordinator.spec(NamedSandboxRequest(sandboxName: spec.name))

        XCTAssertEqual(result, .success)
        XCTAssertEqual(output, [spec.renderedYAML().trimmingCharacters(in: .newlines)])
        XCTAssertEqual(backend.calls, [])
    }

    func testLogsPrintBackendRuntimeLogsWithoutDroppingUsefulLines() throws {
        var output: [String] = []
        let spec = SandboxSpec.generated(name: try SandboxName("mybox"))
        let backend = RecordingSandboxBackend(status: .running, logsText: "booted\nagent ready\n")
        let coordinator = LifecycleCoordinator(
            metadataStore: MemoryMetadataStore(specs: [spec]),
            backend: backend,
            writeOutput: { output.append($0) }
        )

        let result = try coordinator.logs(NamedSandboxRequest(sandboxName: spec.name))

        XCTAssertEqual(result, .success)
        XCTAssertEqual(output, ["booted", "agent ready"])
        XCTAssertEqual(backend.calls, [.logs("mybox")])
    }

    func testCreateClonesExistingStoppedMacOSSandboxAndRejectsShrink() throws {
        let source = SandboxSpec(name: try SandboxName("cleanbox"), image: SandboxImage(reference: "ghcr.io/example/macos:latest"), guestOS: .macOS, diskSize: DiskSize(gigabytes: 150))
        let metadataStore = MemoryMetadataStore(specs: [source])
        let backend = RecordingSandboxBackend(status: .stopped)
        let coordinator = LifecycleCoordinator(metadataStore: metadataStore, backend: backend)

        let result = try coordinator.create(CreateRequest(sandboxName: try SandboxName("workbox"), diskSize: DiskSize(gigabytes: 200), displayResolution: DisplayResolution(width: 1920, height: 1080, unit: .pixels), sourceReference: "cleanbox"))

        XCTAssertEqual(result, .success)
        let clone = try metadataStore.readSpec(named: try SandboxName("workbox"))
        XCTAssertEqual(clone.image, SandboxImage(reference: "cleanbox"))
        XCTAssertEqual(clone.guestOS, .macOS)
        XCTAssertEqual(clone.resourceProfile, ResourceProfile(cpus: 4, memory: MemorySize(gigabytes: 16)))
        XCTAssertEqual(clone.diskSize, DiskSize(gigabytes: 200))
        XCTAssertEqual(clone.displayResolution, DisplayResolution(width: 1920, height: 1080, unit: .pixels))
        XCTAssertEqual(backend.calls, [.status("cleanbox"), .provision("workbox")])

        XCTAssertThrowsError(try coordinator.create(CreateRequest(sandboxName: try SandboxName("tinybox"), guestOS: .macOS, diskSize: DiskSize(gigabytes: 100), sourceReference: "cleanbox"))) { error in
            XCTAssertEqual(error as? SandboxSpecError, .cloneDiskTooSmall(source: DiskSize(gigabytes: 150), requested: DiskSize(gigabytes: 100)))
        }
    }

    func testCreateRejectsRunningLocalMacOSCloneSourceBeforeProvisioning() throws {
        let source = SandboxSpec(name: try SandboxName("cleanbox"), guestOS: .macOS)
        let backend = RecordingSandboxBackend(status: .running)
        let coordinator = LifecycleCoordinator(metadataStore: MemoryMetadataStore(specs: [source]), backend: backend)

        XCTAssertThrowsError(try coordinator.create(CreateRequest(sandboxName: try SandboxName("workbox"), guestOS: .macOS, sourceReference: "cleanbox"))) { error in
            XCTAssertEqual(error as? SandboxCreateError, .localCloneSourceNotStopped("cleanbox"))
        }
        XCTAssertEqual(backend.calls, [.status("cleanbox")])
    }

    func testStatusPrintsUsefulConfigAndRuntimeStateWithoutRawBackendDump() throws {
        var output: [String] = []
        let spec = SandboxSpec(
            name: try SandboxName("mybox"),
            image: SandboxImage(reference: "custom:latest"),
            resourceProfile: ResourceProfile(cpus: 6, memory: MemorySize(gigabytes: 12))
        )
        let metadataStore = MemoryMetadataStore(specs: [spec])
        let backend = RecordingSandboxBackend(status: .running)
        let coordinator = LifecycleCoordinator(metadataStore: metadataStore, backend: backend, writeOutput: { output.append($0) })

        let result = try coordinator.status(NamedSandboxRequest(sandboxName: spec.name))

        XCTAssertEqual(result, .success)
        XCTAssertEqual(output, [
            "name: mybox",
            "state: running",
            "os: linux",
            "image: custom:latest",
            "resources: 6 CPUs, 12GB memory",
            "sharedFolders: 0"
        ])
        XCTAssertEqual(backend.calls, [.status("mybox")])
    }

    func testMacOSStatusIncludesDiskSizeAndDisplayResolution() throws {
        var output: [String] = []
        let spec = SandboxSpec(name: try SandboxName("macbox"), guestOS: .macOS, diskSize: DiskSize(gigabytes: 150), displayResolution: DisplayResolution(width: 1920, height: 1080, unit: .pixels))
        let coordinator = LifecycleCoordinator(metadataStore: MemoryMetadataStore(specs: [spec]), backend: RecordingSandboxBackend(status: .stopped), writeOutput: { output.append($0) })

        XCTAssertEqual(try coordinator.status(NamedSandboxRequest(sandboxName: spec.name)), .success)
        XCTAssertTrue(output.contains("disk: 150GB"))
        XCTAssertTrue(output.contains("display: 1920x1080px"))
    }

    func testRunAutoStartsStoppedSandboxAndDelegatesOpaqueCommandToBackend() throws {
        let name = try SandboxName("mybox")
        let spec = SandboxSpec(
            name: name,
            sharedFolders: [
                SharedFolder(
                    displayHostPath: "~/Projects/sand",
                    resolvedHostPath: "/Users/onur/Projects/sand",
                    guestPath: try GuestPath("/workspace/sand"),
                    accessMode: .readWrite
                )
            ]
        )
        let metadataStore = MemoryMetadataStore(specs: [spec], currentHostDirectory: "/Users/onur/Projects/sand/Sources")
        let backend = RecordingSandboxBackend(status: .stopped)
        var output: [String] = []
        let coordinator = LifecycleCoordinator(metadataStore: metadataStore, backend: backend, writeOutput: { output.append($0) })

        let result = try coordinator.run(
            RunRequest(
                sandboxName: name,
                command: try WorkloadCommand(arguments: ["pi", "--model", "gpt-5"])
            )
        )

        XCTAssertEqual(result, .success)
        XCTAssertEqual(backend.calls, [.status("mybox"), .start("mybox"), .run("mybox", ["pi", "--model", "gpt-5"], "/workspace/sand/Sources")])
        XCTAssertEqual(output, ["Starting Sandbox VM mybox..."])
        XCTAssertEqual(metadataStore.lockEvents, [])
    }

    func testShellAutoStartsStoppedSandboxAndUsesMappedWorkingDirectory() throws {
        let spec = try specWithSharedFolder()
        let metadataStore = MemoryMetadataStore(specs: [spec], currentHostDirectory: "/Users/onur/Projects/sand")
        let backend = RecordingSandboxBackend(status: .stopped)
        let coordinator = LifecycleCoordinator(metadataStore: metadataStore, backend: backend)

        let result = try coordinator.shell(ShellRequest(sandboxName: spec.name))

        XCTAssertEqual(result, .success)
        XCTAssertEqual(backend.calls, [.status("mybox"), .start("mybox"), .shell("mybox", "/workspace/sand")])
        XCTAssertEqual(metadataStore.lockEvents, [])
    }

    func testRunOutsideSharedFoldersWarnsAndUsesFallbackWorkingDirectory() throws {
        var warnings: [String] = []
        let spec = try specWithSharedFolder()
        let metadataStore = MemoryMetadataStore(specs: [spec], currentHostDirectory: "/Users/onur/Downloads")
        let backend = RecordingSandboxBackend(status: .running)
        let coordinator = LifecycleCoordinator(metadataStore: metadataStore, backend: backend, writeWarning: { warnings.append($0) })

        let result = try coordinator.run(RunRequest(sandboxName: spec.name, command: try WorkloadCommand(arguments: ["pwd"])))

        XCTAssertEqual(result, .success)
        XCTAssertEqual(warnings, ["Current directory is not inside an Shared Folder; starting in /workspace."])
        XCTAssertEqual(backend.calls, [.status("mybox"), .run("mybox", ["pwd"], "/workspace")])
    }

    func testMacOSRunOutsideSharedFoldersUsesExistingSandboxUserHomeFallback() throws {
        var warnings: [String] = []
        let spec = SandboxSpec(name: try SandboxName("macbox"), guestOS: .macOS)
        let metadataStore = MemoryMetadataStore(specs: [spec], currentHostDirectory: "/Users/onur/Downloads")
        let backend = RecordingSandboxBackend(status: .running)
        let coordinator = LifecycleCoordinator(metadataStore: metadataStore, backend: backend, writeWarning: { warnings.append($0) })

        let result = try coordinator.run(RunRequest(sandboxName: spec.name, command: try WorkloadCommand(arguments: ["pwd"])))

        XCTAssertEqual(result, .success)
        XCTAssertEqual(warnings, ["Current directory is not inside an Shared Folder; starting in /Users/admin."])
        XCTAssertEqual(backend.calls, [.status("macbox"), .run("macbox", ["pwd"], "/Users/admin")])
    }

    func testShellOutsideSharedFoldersWarnsAndUsesFallbackWorkingDirectory() throws {
        var warnings: [String] = []
        let spec = try specWithSharedFolder()
        let metadataStore = MemoryMetadataStore(specs: [spec], currentHostDirectory: "/Users/onur/Downloads")
        let backend = RecordingSandboxBackend(status: .running)
        let coordinator = LifecycleCoordinator(metadataStore: metadataStore, backend: backend, writeWarning: { warnings.append($0) })

        let result = try coordinator.shell(ShellRequest(sandboxName: spec.name))

        XCTAssertEqual(result, .success)
        XCTAssertEqual(warnings, ["Current directory is not inside an Shared Folder; starting in /workspace."])
        XCTAssertEqual(backend.calls, [.status("mybox"), .shell("mybox", "/workspace")])
    }

    func testGUIRejectsLinuxSandboxWithMacOSOnlyMessage() throws {
        let spec = SandboxSpec.generated(name: try SandboxName("linuxbox"))
        let backend = RecordingSandboxBackend(status: .stopped)
        let coordinator = LifecycleCoordinator(metadataStore: MemoryMetadataStore(specs: [spec]), backend: backend)

        XCTAssertThrowsError(try coordinator.gui(GUIRequest(sandboxName: spec.name))) { error in
            XCTAssertEqual(String(describing: error), "gui is macOS-only; Sandbox VM uses linux.")
        }
        XCTAssertEqual(backend.calls, [])
    }

    func testGUIDelegatesMacOSSandboxThroughResolvedBackend() throws {
        let spec = SandboxSpec(name: try SandboxName("macbox"), guestOS: .macOS)
        let linuxBackend = RecordingSandboxBackend(status: .running)
        let macOSBackend = RecordingSandboxBackend(status: .stopped)
        let resolver = RecordingBackendResolver(linuxBackend: linuxBackend, macOSBackend: macOSBackend)
        let coordinator = LifecycleCoordinator(metadataStore: MemoryMetadataStore(specs: [spec]), backendResolver: resolver)

        XCTAssertEqual(try coordinator.gui(GUIRequest(sandboxName: spec.name)), .success)

        XCTAssertEqual(resolver.requestedGuestOS, [.macOS])
        XCTAssertEqual(linuxBackend.calls, [])
        XCTAssertEqual(macOSBackend.calls, [.gui("macbox")])
    }

    func testSigningCredentialsRejectLinuxSandboxWithoutReadingHostKeychain() throws {
        let spec = SandboxSpec.generated(name: try SandboxName("linuxbox"))
        let backend = RecordingSandboxBackend(status: .stopped)
        let coordinator = LifecycleCoordinator(metadataStore: MemoryMetadataStore(specs: [spec]), backend: backend)
        let request = SigningCredentialsRequest(sandboxName: spec.name, certificateP12: Data("CERT".utf8), certificatePassword: "cert-pass", provisioningProfile: Data("PROFILE".utf8), keychainPassword: "kc-pass")

        XCTAssertThrowsError(try coordinator.installSigningCredentials(request)) { error in
            XCTAssertEqual(String(describing: error), "signing credentials are macOS-only; Sandbox VM uses linux.")
        }
        XCTAssertEqual(backend.calls, [])
    }

    func testSigningCredentialsAutoStartsStoppedMacOSSandboxAndDelegatesGuestSecretInjection() throws {
        let spec = SandboxSpec(name: try SandboxName("macbox"), guestOS: .macOS)
        let linuxBackend = RecordingSandboxBackend(status: .running)
        let macOSBackend = RecordingSandboxBackend(status: .stopped)
        let resolver = RecordingBackendResolver(linuxBackend: linuxBackend, macOSBackend: macOSBackend)
        let metadataStore = MemoryMetadataStore(specs: [spec])
        let coordinator = LifecycleCoordinator(metadataStore: metadataStore, backendResolver: resolver)
        let request = SigningCredentialsRequest(sandboxName: spec.name, certificateP12: Data("CERT".utf8), certificatePassword: "cert-pass", provisioningProfile: Data("PROFILE".utf8), keychainName: "ci-signing", keychainPassword: "kc-pass")

        XCTAssertEqual(try coordinator.installSigningCredentials(request), .success)

        XCTAssertEqual(resolver.requestedGuestOS, [.macOS])
        XCTAssertEqual(linuxBackend.calls, [])
        XCTAssertEqual(macOSBackend.calls, [.status("macbox"), .start("macbox"), .installSigningCredentials("macbox", "CERT", "cert-pass", "PROFILE", "ci-signing", "kc-pass")])
        XCTAssertEqual(metadataStore.lockEvents, ["enter", "exit"])
    }

    func testStartReportsAlreadyRunningSandboxWithoutStartingAgain() throws {
        let spec = SandboxSpec.generated(name: try SandboxName("mybox"))
        let metadataStore = MemoryMetadataStore(specs: [spec])
        let backend = RecordingSandboxBackend(status: .running)
        var output: [String] = []
        let coordinator = LifecycleCoordinator(metadataStore: metadataStore, backend: backend, writeOutput: { output.append($0) })

        XCTAssertEqual(try coordinator.start(NamedSandboxRequest(sandboxName: spec.name)), .success)

        XCTAssertEqual(backend.calls, [.status("mybox")])
        XCTAssertEqual(output, ["Sandbox VM mybox is already running."])
        XCTAssertEqual(metadataStore.lockEvents, ["enter", "exit"])
    }

    func testStartStopAndDeleteAreLifecycleMutationsAndUpdateBackendState() throws {
        let spec = SandboxSpec.generated(name: try SandboxName("mybox"))
        let metadataStore = MemoryMetadataStore(specs: [spec])
        let backend = RecordingSandboxBackend(status: .stopped)
        let prompt = RecordingPromptConfirmation(decisions: [.proceed])
        var output: [String] = []
        let coordinator = LifecycleCoordinator(metadataStore: metadataStore, backend: backend, prompt: prompt, writeOutput: { output.append($0) })

        XCTAssertEqual(try coordinator.start(NamedSandboxRequest(sandboxName: spec.name)), .success)
        XCTAssertEqual(try coordinator.stop(NamedSandboxRequest(sandboxName: spec.name)), .success)
        XCTAssertEqual(try coordinator.delete(DeleteRequest(sandboxName: spec.name)), .success)

        XCTAssertEqual(backend.calls, [.status("mybox"), .start("mybox"), .stop("mybox"), .delete("mybox")])
        XCTAssertEqual(output, ["Starting Sandbox VM mybox...", "Started Sandbox VM mybox."])
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
        XCTAssertEqual(try metadataStore.readSpec(named: spec.name).sharedFolders.count, 1)
        XCTAssertEqual(backend.calls, [.status("mybox"), .apply("mybox")])
    }

    func testFoldersListPrintsHostGuestAndAccessModeForAudit() throws {
        var output: [String] = []
        let spec = SandboxSpec(
            name: try SandboxName("mybox"),
            sharedFolders: [
                SharedFolder(displayHostPath: "~/Projects/sand", resolvedHostPath: "/Users/onur/Projects/sand", guestPath: try GuestPath("/workspace/sand"), accessMode: .readWrite),
                SharedFolder(displayHostPath: "/Users/onur/Downloads", resolvedHostPath: "/Users/onur/Downloads", guestPath: try GuestPath("/reference"), accessMode: .readOnly)
            ]
        )
        let coordinator = LifecycleCoordinator(
            metadataStore: MemoryMetadataStore(specs: [spec]),
            backend: RecordingSandboxBackend(status: .stopped),
            writeOutput: { output.append($0) }
        )

        let result = try coordinator.listFolders(NamedSandboxRequest(sandboxName: spec.name))

        XCTAssertEqual(result, .success)
        XCTAssertEqual(output, [
            "Host Path\tGuest Path\tAccess Mode",
            "~/Projects/sand\t/workspace/sand\tread-write",
            "/Users/onur/Downloads\t/reference\tread-only"
        ])
    }

    func testFolderRemoveMutatesSpecAndAutoAppliesThroughFakeBackend() throws {
        let spec = SandboxSpec(
            name: try SandboxName("mybox"),
            sharedFolders: [SharedFolder(displayHostPath: "~/Projects/sand", resolvedHostPath: "/Users/onur/Projects/sand", guestPath: try GuestPath("/workspace/sand"), accessMode: .readWrite)]
        )
        let metadataStore = MemoryMetadataStore(specs: [spec])
        let backend = RecordingSandboxBackend(status: .stopped)
        let policy = FolderPolicy(resolvePath: { $0 == "~/Projects/sand" ? "/Users/onur/Projects/sand" : $0 })
        let coordinator = LifecycleCoordinator(metadataStore: metadataStore, backend: backend, folderPolicy: policy)

        let result = try coordinator.removeFolder(RemoveFolderRequest(sandboxName: spec.name, displayHostPath: "~/Projects/sand"))

        XCTAssertEqual(result, .success)
        XCTAssertEqual(try metadataStore.readSpec(named: spec.name).sharedFolders, [])
        XCTAssertEqual(backend.calls, [.status("mybox"), .apply("mybox")])
    }

    func testRunningConfigChangePromptsBeforeApplyingAndLeavesSpecUntouchedWhenCancelled() throws {
        let spec = SandboxSpec.generated(name: try SandboxName("mybox"))
        let metadataStore = MemoryMetadataStore(specs: [spec])
        let backend = RecordingSandboxBackend(status: .running)
        let prompt = RecordingPromptConfirmation(decisions: [.cancel])
        let policy = FolderPolicy(resolvePath: { $0 })
        let coordinator = LifecycleCoordinator(metadataStore: metadataStore, backend: backend, folderPolicy: policy, prompt: prompt)

        let result = try coordinator.addFolder(AddFolderRequest(sandboxName: spec.name, displayHostPath: "/Users/onur/Projects/sand", accessMode: "rw"))

        XCTAssertEqual(result, .failure(exitCode: 1))
        XCTAssertEqual(prompt.requests, [ConfirmationRequest(message: "Apply changes to running Sandbox VM mybox?", destructive: false)])
        XCTAssertEqual(try metadataStore.readSpec(named: spec.name), spec)
        XCTAssertEqual(backend.calls, [.status("mybox")])
    }

    func testRunningConfigChangeAppliesAfterPromptApproval() throws {
        let spec = SandboxSpec.generated(name: try SandboxName("mybox"))
        let metadataStore = MemoryMetadataStore(specs: [spec])
        let backend = RecordingSandboxBackend(status: .running)
        let prompt = RecordingPromptConfirmation(decisions: [.proceed])
        let policy = FolderPolicy(resolvePath: { $0 })
        let coordinator = LifecycleCoordinator(metadataStore: metadataStore, backend: backend, folderPolicy: policy, prompt: prompt)

        let result = try coordinator.addFolder(AddFolderRequest(sandboxName: spec.name, displayHostPath: "/Users/onur/Projects/sand", accessMode: "rw"))

        XCTAssertEqual(result, .success)
        XCTAssertEqual(prompt.requests, [ConfirmationRequest(message: "Apply changes to running Sandbox VM mybox?", destructive: false)])
        XCTAssertEqual(try metadataStore.readSpec(named: spec.name).sharedFolders.count, 1)
        XCTAssertEqual(backend.calls, [.status("mybox"), .apply("mybox")])
    }

    func testNormalRunAndShellAreNotSerializedBehindLifecycleMutationLocks() throws {
        let spec = try specWithSharedFolder()
        let metadataStore = MemoryMetadataStore(specs: [spec], currentHostDirectory: "/Users/onur/Projects/sand")
        let backend = RecordingSandboxBackend(status: .running)
        let coordinator = LifecycleCoordinator(metadataStore: metadataStore, backend: backend)

        _ = try coordinator.run(RunRequest(sandboxName: spec.name, command: try WorkloadCommand(arguments: ["echo", "ok"])))
        _ = try coordinator.shell(ShellRequest(sandboxName: spec.name))

        XCTAssertEqual(metadataStore.lockEvents, [])
        XCTAssertEqual(backend.calls, [.status("mybox"), .run("mybox", ["echo", "ok"], "/workspace/sand"), .status("mybox"), .shell("mybox", "/workspace/sand")])
    }

    private func specWithSharedFolder() throws -> SandboxSpec {
        SandboxSpec(
            name: try SandboxName("mybox"),
            sharedFolders: [SharedFolder(displayHostPath: "~/Projects/sand", resolvedHostPath: "/Users/onur/Projects/sand", guestPath: try GuestPath("/workspace/sand"), accessMode: .readWrite)]
        )
    }
}

private struct FixedDoctorPlatform: DoctorPlatform {
    var isSupported: Bool
}
