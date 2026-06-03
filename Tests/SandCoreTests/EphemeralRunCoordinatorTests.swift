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

    func testEphemeralAllowedFoldersResolveIntoGeneratedConcreteSandboxSpec() throws {
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
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let sourcePath = "\(home)/ephemeral-project/specs/ephemeral.yaml"
        let expectedRelative = URL(fileURLWithPath: home)
            .appendingPathComponent("ephemeral-project/specs/work")
            .resolvingSymlinksInPath()
            .standardizedFileURL
            .path
        let expectedHome = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library")
            .resolvingSymlinksInPath()
            .standardizedFileURL
            .path
        let specText = """
        schemaVersion: 1
        image: registry.example/sand:dev
        resources:
          cpus: 6
          memory: 12GB
        allowedFolders:
          - hostPath: ./work
            accessMode: rw
          - hostPath: /opt/reference
            guestPath: /reference
            accessMode: ro
          - hostPath: ~/Library
            accessMode: read-only
        workload:
          command: echo
          workdir: /workspace/work
        """

        let result = try coordinator.run(
            EphemeralRunRequest(
                authoredSpecText: specText,
                sourcePath: sourcePath
            )
        )

        XCTAssertEqual(result, .success)
        XCTAssertEqual(runRecordStore.sourceSpecTexts, [specText])
        XCTAssertFalse(runRecordStore.sourceSpecTexts[0].contains("resolvedHostPath"))
        XCTAssertEqual(runRecordStore.generatedSpecs, [
            SandboxSpec(
                name: sandboxName,
                image: SandboxImage(reference: "registry.example/sand:dev"),
                resourceProfile: ResourceProfile(cpus: 6, memory: MemorySize(gigabytes: 12)),
                allowedFolders: [
                    AllowedFolder(
                        displayHostPath: "./work",
                        resolvedHostPath: expectedRelative,
                        guestPath: try GuestPath("/workspace/work"),
                        accessMode: .readWrite
                    ),
                    AllowedFolder(
                        displayHostPath: "/opt/reference",
                        resolvedHostPath: "/opt/reference",
                        guestPath: try GuestPath("/reference"),
                        accessMode: .readOnly
                    ),
                    AllowedFolder(
                        displayHostPath: "~/Library",
                        resolvedHostPath: expectedHome,
                        guestPath: try GuestPath("/workspace/Library"),
                        accessMode: .readOnly
                    )
                ]
            )
        ])
        XCTAssertEqual(backend.calls, [
            .provision("ephemeral-20260602-abcd"),
            .start("ephemeral-20260602-abcd"),
            .run("ephemeral-20260602-abcd", ["echo"], "/workspace/work"),
            .stop("ephemeral-20260602-abcd"),
            .delete("ephemeral-20260602-abcd")
        ])
    }

    func testEphemeralRunPlanUsesCLIWorkloadOverrideAndPreservesYAMLWorkdir() throws {
        let spec = try EphemeralSpec.parseYAML("""
        schemaVersion: 1
        allowedFolders:
          - hostPath: ./work
            accessMode: read-write
        workload:
          command: echo
          args:
            - from-yaml
          workdir: /workspace/custom
        """)

        let plan = try EphemeralRunPlan.build(
            from: spec,
            workloadOverride: try WorkloadCommand(arguments: ["bash", "-lc", "pwd && env"])
        )

        XCTAssertEqual(plan.workload.command.arguments, ["bash", "-lc", "pwd && env"])
        XCTAssertEqual(plan.workload.workdir.rawValue, "/workspace/custom")
    }

    func testEphemeralRunPlanAllowsCLIWorkloadOverrideWhenYAMLHasNoWorkload() throws {
        let spec = try EphemeralSpec.parseYAML("""
        schemaVersion: 1
        allowedFolders:
          - hostPath: ./work
            accessMode: read-write
        """)

        let plan = try EphemeralRunPlan.build(
            from: spec,
            workloadOverride: try WorkloadCommand(arguments: ["echo", "from-cli"])
        )

        XCTAssertEqual(plan.workload.command.arguments, ["echo", "from-cli"])
        XCTAssertEqual(plan.workload.workdir.rawValue, "/workspace/work")
    }

    func testWorkloadWorkdirDefaultsToFirstReadWriteAllowedFolderGuestPath() throws {
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
        allowedFolders:
          - hostPath: ./reference
            accessMode: read-only
          - hostPath: ./work
            accessMode: read-write
          - hostPath: ./other-work
            guestPath: /other-workspace
            accessMode: read-write
        workload:
          command: pwd
        """

        let result = try coordinator.run(
            EphemeralRunRequest(
                authoredSpecText: specText,
                sourcePath: "/Users/onur/ephemeral/spec.yaml"
            )
        )

        XCTAssertEqual(result, .success)
        XCTAssertEqual(backend.calls, [
            .provision("ephemeral-20260602-abcd"),
            .start("ephemeral-20260602-abcd"),
            .run("ephemeral-20260602-abcd", ["pwd"], "/workspace/work"),
            .stop("ephemeral-20260602-abcd"),
            .delete("ephemeral-20260602-abcd")
        ])
        XCTAssertEqual(runRecordStore.generatedSpecs.first?.allowedFolders.map(\.guestPath.rawValue), [
            "/workspace/reference",
            "/workspace/work",
            "/other-workspace"
        ])
    }

    func testImplicitWorkdirFailsBeforeProvisioningWhenOnlyReadOnlyFoldersExist() throws {
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
        allowedFolders:
          - hostPath: ./reference
            accessMode: read-only
        workload:
          command: pwd
        """

        XCTAssertThrowsError(
            try coordinator.run(
                EphemeralRunRequest(
                    authoredSpecText: specText,
                    sourcePath: "/Users/onur/ephemeral/spec.yaml"
                )
            )
        ) { error in
            XCTAssertTrue(
                String(describing: error).contains("no read-write allowed folder is available for default workload workdir"),
                "got \(error)"
            )
        }
        XCTAssertEqual(events, [])
        XCTAssertEqual(metadataStore.activeSpecNames, [])
        XCTAssertEqual(backend.calls, [])
    }

    func testImplicitWorkdirFailsBeforeProvisioningWhenNoAllowedFoldersExist() throws {
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
          command: pwd
        """

        XCTAssertThrowsError(
            try coordinator.run(
                EphemeralRunRequest(
                    authoredSpecText: specText,
                    sourcePath: "/Users/onur/ephemeral/spec.yaml"
                )
            )
        ) { error in
            XCTAssertTrue(
                String(describing: error).contains("no read-write allowed folder is available for default workload workdir"),
                "got \(error)"
            )
        }
        XCTAssertEqual(events, [])
        XCTAssertEqual(metadataStore.activeSpecNames, [])
        XCTAssertEqual(backend.calls, [])
    }

    func testEphemeralAllowedFoldersReuseFolderPolicyDuplicateGuestPathRejection() throws {
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
        allowedFolders:
          - hostPath: ./work-a
            guestPath: /workspace/work
            accessMode: read-write
          - hostPath: ./work-b
            guestPath: /workspace/work
            accessMode: read-only
        workload:
          command: echo
          workdir: /workspace/work
        """

        XCTAssertThrowsError(
            try coordinator.run(
                EphemeralRunRequest(
                    authoredSpecText: specText,
                    sourcePath: "/Users/onur/ephemeral/spec.yaml"
                )
            )
        ) { error in
            XCTAssertEqual(error as? FolderPolicyError, .duplicateGuestPath("/workspace/work"))
        }
        XCTAssertEqual(runRecordStore.generatedSpecs, [])
        XCTAssertEqual(metadataStore.activeSpecNames, [])
        XCTAssertEqual(backend.calls, [])
        XCTAssertEqual(events, [
            "record.allocateIdentity.ephemeral",
            "record.createAttempt"
        ])
    }

    func testEphemeralAllowedFoldersReuseFolderPolicyOverlapRejectionAfterResolution() throws {
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
        let sourcePath = "/Users/onur/ephemeral/spec.yaml"
        let specText = """
        schemaVersion: 1
        allowedFolders:
          - hostPath: ./work
            accessMode: rw
          - hostPath: ./work/nested
            accessMode: ro
        workload:
          command: echo
          workdir: /workspace/work
        """

        XCTAssertThrowsError(
            try coordinator.run(
                EphemeralRunRequest(
                    authoredSpecText: specText,
                    sourcePath: sourcePath
                )
            )
        ) { error in
            XCTAssertEqual(error as? FolderPolicyError, .overlappingHostFolders("/Users/onur/ephemeral/work", "/Users/onur/ephemeral/work/nested"))
        }
        XCTAssertEqual(runRecordStore.generatedSpecs, [])
        XCTAssertEqual(metadataStore.activeSpecNames, [])
        XCTAssertEqual(backend.calls, [])
    }

    func testBeforeProvisionHooksAreOptionalAndUseStructuredCommandShape() throws {
        let omitted = try EphemeralSpec.parseYAML("""
        schemaVersion: 1
        workload:
          command: echo
          workdir: /workspace
        """)
        XCTAssertEqual(omitted.beforeProvisionHooks, [])

        let empty = try EphemeralSpec.parseYAML("""
        schemaVersion: 1
        beforeProvision: []
        workload:
          command: echo
          workdir: /workspace
        """)
        XCTAssertEqual(empty.beforeProvisionHooks, [])

        let spec = try EphemeralSpec.parseYAML("""
        schemaVersion: 1
        beforeProvision:
          - command: mkdir
            args:
              - -p
              - work
          - command: printf
        workload:
          command: echo
          workdir: /workspace
        """)
        XCTAssertEqual(spec.beforeProvisionHooks.map(\.command.arguments), [
            ["mkdir", "-p", "work"],
            ["printf"]
        ])

        XCTAssertThrowsError(
            try EphemeralSpec.parseYAML("""
            schemaVersion: 1
            beforeProvision:
              - command:
            workload:
              command: echo
              workdir: /workspace
            """)
        ) { error in
            XCTAssertTrue(String(describing: error).contains("ephemeral beforeProvision hook command cannot be empty"), "got \(error)")
        }
    }

    func testBeforeProvisionHooksRunBeforeFolderResolutionAndProvisioningWithCapturedOutputEvents() throws {
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
        let hostRunner = RecordingHostCommandRunner(
            results: [HostCommandResult(commandResult: .success, stdout: "made folder\n", stderr: "warning\n")],
            events: { events.append($0) }
        )
        let coordinator = EphemeralRunCoordinator(
            metadataStore: metadataStore,
            backend: backend,
            runRecordStore: runRecordStore,
            hostCommandRunner: hostRunner,
            processEnvironment: { ["PATH": "/custom/bin", "SAND_TEST_SENTINEL": "inherited"] },
            writeOutput: { _ in }
        )
        let sourcePath = "/tmp/ephemeral-project/specs/ephemeral.yaml"
        let specText = """
        schemaVersion: 1
        beforeProvision:
          - command: mkdir
            args:
              - -p
              - created
        allowedFolders:
          - hostPath: ./created
            accessMode: read-write
        workload:
          command: pwd
        """

        let result = try coordinator.run(
            EphemeralRunRequest(authoredSpecText: specText, sourcePath: sourcePath)
        )

        XCTAssertEqual(result, .success)
        XCTAssertEqual(hostRunner.invocations.map(\.commandArguments), [["mkdir", "-p", "created"]])
        XCTAssertEqual(hostRunner.invocations.map(\.workingDirectory), ["/tmp/ephemeral-project/specs"])
        XCTAssertEqual(hostRunner.invocations.first?.environment["PATH"], "/custom/bin")
        XCTAssertEqual(hostRunner.invocations.first?.environment["SAND_TEST_SENTINEL"], "inherited")
        XCTAssertEqual(runRecordStore.hookOutputs.map(\.stdout), ["made folder\n"])
        XCTAssertEqual(runRecordStore.hookOutputs.map(\.stderr), ["warning\n"])
        XCTAssertEqual(runRecordStore.hookEvents.map(\.phase), ["beforeProvision"])
        XCTAssertEqual(runRecordStore.hookEvents.map(\.status), ["success"])
        XCTAssertEqual(runRecordStore.hookEvents.map(\.stdoutPath), ["/tmp/sand-runs/run-001/beforeProvision-0.stdout"])
        XCTAssertEqual(runRecordStore.generatedSpecs.first?.allowedFolders.map(\.resolvedHostPath), ["/tmp/ephemeral-project/specs/created"])
        XCTAssertEqual(events, [
            "record.allocateIdentity.ephemeral",
            "record.createAttempt",
            "host.run.mkdir -p created./tmp/ephemeral-project/specs",
            "record.writeHookOutput.beforeProvision.0",
            "record.appendEvent.beforeProvision.success",
            "record.writeGeneratedSpec",
            "metadata.createSpec.ephemeral-20260602-abcd",
            "backend.provision.ephemeral-20260602-abcd",
            "backend.start.ephemeral-20260602-abcd",
            "backend.run.ephemeral-20260602-abcd.pwd./workspace/created",
            "backend.stop.ephemeral-20260602-abcd",
            "backend.delete.ephemeral-20260602-abcd",
            "metadata.deleteSpec.ephemeral-20260602-abcd",
            "record.writeResult.success"
        ])
    }

    func testBeforeProvisionHookFailureAbortsBeforeProvisioningAndRecordsFailure() throws {
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
        let hostRunner = RecordingHostCommandRunner(
            results: [HostCommandResult(commandResult: .failure(exitCode: 42), stdout: "setup out\n", stderr: "setup failed\n")],
            events: { events.append($0) }
        )
        let coordinator = EphemeralRunCoordinator(
            metadataStore: metadataStore,
            backend: backend,
            runRecordStore: runRecordStore,
            hostCommandRunner: hostRunner,
            processEnvironment: { ["PATH": "/custom/bin"] },
            writeOutput: { _ in }
        )
        let specText = """
        schemaVersion: 1
        beforeProvision:
          - command: false
        allowedFolders:
          - hostPath: ./created
            accessMode: read-write
        workload:
          command: pwd
        """

        let result = try coordinator.run(
            EphemeralRunRequest(authoredSpecText: specText, sourcePath: "/tmp/ephemeral-project/specs/ephemeral.yaml")
        )

        XCTAssertEqual(result, .failure(exitCode: 42))
        XCTAssertEqual(hostRunner.invocations.map(\.commandArguments), [["false"]])
        XCTAssertEqual(runRecordStore.hookEvents.map(\.status), ["failure"])
        XCTAssertEqual(runRecordStore.resultStatus, "failure")
        XCTAssertEqual(runRecordStore.resultExitCode, 42)
        XCTAssertEqual(runRecordStore.generatedSpecs, [])
        XCTAssertEqual(metadataStore.activeSpecNames, [])
        XCTAssertEqual(backend.calls, [])
        XCTAssertEqual(events, [
            "record.allocateIdentity.ephemeral",
            "record.createAttempt",
            "host.run.false./tmp/ephemeral-project/specs",
            "record.writeHookOutput.beforeProvision.0",
            "record.appendEvent.beforeProvision.failure",
            "record.writeResult.failure"
        ])
    }

    func testAfterStopHooksAreOptionalAndUseStructuredCommandShape() throws {
        let omitted = try EphemeralSpec.parseYAML("""
        schemaVersion: 1
        workload:
          command: echo
          workdir: /workspace
        """)
        XCTAssertEqual(omitted.afterStopHooks, [])

        let empty = try EphemeralSpec.parseYAML("""
        schemaVersion: 1
        afterStop: []
        workload:
          command: echo
          workdir: /workspace
        """)
        XCTAssertEqual(empty.afterStopHooks, [])

        let spec = try EphemeralSpec.parseYAML("""
        schemaVersion: 1
        afterStop:
          - command: cp
            args:
              - output.txt
              - archive/output.txt
          - command: git
            args:
              - status
        workload:
          command: echo
          workdir: /workspace
        """)
        XCTAssertEqual(spec.afterStopHooks.map(\.command.arguments), [
            ["cp", "output.txt", "archive/output.txt"],
            ["git", "status"]
        ])

        XCTAssertThrowsError(
            try EphemeralSpec.parseYAML("""
            schemaVersion: 1
            afterStop:
              - command:
            workload:
              command: echo
              workdir: /workspace
            """)
        ) { error in
            XCTAssertTrue(String(describing: error).contains("ephemeral afterStop hook command cannot be empty"), "got \(error)")
        }
    }

    func testAfterStopHooksRunAfterWorkloadExitAndStopAttemptWithCapturedOutputEvents() throws {
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
        let hostRunner = RecordingHostCommandRunner(
            results: [HostCommandResult(commandResult: .success, stdout: "archived\n", stderr: "note\n")],
            events: { events.append($0) }
        )
        let coordinator = EphemeralRunCoordinator(
            metadataStore: metadataStore,
            backend: backend,
            runRecordStore: runRecordStore,
            hostCommandRunner: hostRunner,
            processEnvironment: { ["PATH": "/custom/bin", "SAND_TEST_SENTINEL": "inherited"] },
            writeOutput: { _ in }
        )
        let specText = """
        schemaVersion: 1
        afterStop:
          - command: archive-output
            args:
              - output.txt
        workload:
          command: echo
          workdir: /workspace
        """

        let result = try coordinator.run(
            EphemeralRunRequest(authoredSpecText: specText, sourcePath: "/tmp/ephemeral-project/specs/ephemeral.yaml")
        )

        XCTAssertEqual(result, .success)
        XCTAssertEqual(hostRunner.invocations.map(\.commandArguments), [["archive-output", "output.txt"]])
        XCTAssertEqual(hostRunner.invocations.map(\.workingDirectory), ["/tmp/ephemeral-project/specs"])
        XCTAssertEqual(hostRunner.invocations.first?.environment["PATH"], "/custom/bin")
        XCTAssertEqual(hostRunner.invocations.first?.environment["SAND_TEST_SENTINEL"], "inherited")
        XCTAssertEqual(runRecordStore.hookOutputs.map(\.phase), ["afterStop"])
        XCTAssertEqual(runRecordStore.hookOutputs.map(\.stdout), ["archived\n"])
        XCTAssertEqual(runRecordStore.hookOutputs.map(\.stderr), ["note\n"])
        XCTAssertEqual(runRecordStore.hookEvents.map(\.phase), ["afterStop"])
        XCTAssertEqual(runRecordStore.hookEvents.map(\.status), ["success"])
        XCTAssertEqual(runRecordStore.hookEvents.map(\.stdoutPath), ["/tmp/sand-runs/run-001/afterStop-0.stdout"])
        XCTAssertEqual(events, [
            "record.allocateIdentity.ephemeral",
            "record.createAttempt",
            "record.writeGeneratedSpec",
            "metadata.createSpec.ephemeral-20260602-abcd",
            "backend.provision.ephemeral-20260602-abcd",
            "backend.start.ephemeral-20260602-abcd",
            "backend.run.ephemeral-20260602-abcd.echo./workspace",
            "backend.stop.ephemeral-20260602-abcd",
            "host.run.archive-output output.txt./tmp/ephemeral-project/specs",
            "record.writeHookOutput.afterStop.0",
            "record.appendEvent.afterStop.success",
            "backend.delete.ephemeral-20260602-abcd",
            "metadata.deleteSpec.ephemeral-20260602-abcd",
            "record.writeResult.success"
        ])
    }

    func testAfterStopHooksRunAfterNonzeroWorkloadAndFailedStopThenDeleteStillRuns() throws {
        let sandboxName = try SandboxName("ephemeral-20260602-abcd")
        var events: [String] = []
        let metadataStore = RecordingEphemeralMetadataStore(events: { events.append($0) })
        let backend = RecordingSandboxBackend(
            status: .missing,
            stopError: BackendTestError.stopFailed,
            runResult: .failure(exitCode: 7),
            events: { events.append($0) }
        )
        let runRecordStore = RecordingEphemeralRunRecordStore(
            identity: EphemeralRunIdentity(runID: "run-001", sandboxName: sandboxName, recordPath: "/tmp/sand-runs/run-001"),
            events: { events.append($0) }
        )
        let hostRunner = RecordingHostCommandRunner(
            results: [HostCommandResult(commandResult: .success, stdout: "copied partial\n", stderr: "")],
            events: { events.append($0) }
        )
        let coordinator = EphemeralRunCoordinator(
            metadataStore: metadataStore,
            backend: backend,
            runRecordStore: runRecordStore,
            hostCommandRunner: hostRunner,
            writeOutput: { _ in }
        )
        let specText = """
        schemaVersion: 1
        afterStop:
          - command: copy-partial
        workload:
          command: failing-workload
          workdir: /workspace
        """

        let result = try coordinator.run(EphemeralRunRequest(authoredSpecText: specText, sourcePath: "/tmp/spec.yaml"))

        XCTAssertEqual(result, .failure(exitCode: 1))
        XCTAssertEqual(hostRunner.invocations.map(\.commandArguments), [["copy-partial"]])
        XCTAssertEqual(backend.calls, [
            .provision("ephemeral-20260602-abcd"),
            .start("ephemeral-20260602-abcd"),
            .run("ephemeral-20260602-abcd", ["failing-workload"], "/workspace"),
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
            "backend.run.ephemeral-20260602-abcd.failing-workload./workspace",
            "backend.stop.ephemeral-20260602-abcd",
            "host.run.copy-partial./tmp",
            "record.writeHookOutput.afterStop.0",
            "record.appendEvent.afterStop.success",
            "backend.delete.ephemeral-20260602-abcd",
            "metadata.deleteSpec.ephemeral-20260602-abcd",
            "record.writeResult.failure"
        ])
    }

    func testAfterStopHookFailureStopsRemainingHooksButStillDeletes() throws {
        let sandboxName = try SandboxName("ephemeral-20260602-abcd")
        var events: [String] = []
        let metadataStore = RecordingEphemeralMetadataStore(events: { events.append($0) })
        let backend = RecordingSandboxBackend(status: .missing, events: { events.append($0) })
        let runRecordStore = RecordingEphemeralRunRecordStore(
            identity: EphemeralRunIdentity(runID: "run-001", sandboxName: sandboxName, recordPath: "/tmp/sand-runs/run-001"),
            events: { events.append($0) }
        )
        let hostRunner = RecordingHostCommandRunner(
            results: [
                HostCommandResult(commandResult: .failure(exitCode: 23), stdout: "", stderr: "archive failed\n"),
                HostCommandResult(commandResult: .success, stdout: "should not run\n", stderr: "")
            ],
            events: { events.append($0) }
        )
        let coordinator = EphemeralRunCoordinator(
            metadataStore: metadataStore,
            backend: backend,
            runRecordStore: runRecordStore,
            hostCommandRunner: hostRunner,
            writeOutput: { _ in }
        )
        let specText = """
        schemaVersion: 1
        afterStop:
          - command: archive-output
          - command: upload-output
        workload:
          command: echo
          workdir: /workspace
        """

        let result = try coordinator.run(EphemeralRunRequest(authoredSpecText: specText, sourcePath: "/tmp/spec.yaml"))

        XCTAssertEqual(result, .failure(exitCode: 23))
        XCTAssertEqual(hostRunner.invocations.map(\.commandArguments), [["archive-output"]])
        XCTAssertEqual(runRecordStore.hookEvents.map(\.status), ["failure"])
        XCTAssertEqual(backend.calls, [
            .provision("ephemeral-20260602-abcd"),
            .start("ephemeral-20260602-abcd"),
            .run("ephemeral-20260602-abcd", ["echo"], "/workspace"),
            .stop("ephemeral-20260602-abcd"),
            .delete("ephemeral-20260602-abcd")
        ])
    }

    func testAfterStopHooksDoNotRunWhenBeforeProvisionProvisionOrStartFailsBeforeWorkloadStarts() throws {
        let beforeFailure = try runAfterStopSkipScenario(
            specText: """
            schemaVersion: 1
            beforeProvision:
              - command: prepare
            afterStop:
              - command: archive-output
            workload:
              command: echo
              workdir: /workspace
            """,
            beforeProvisionResults: [HostCommandResult(commandResult: .failure(exitCode: 31), stdout: "", stderr: "failed\n")]
        )
        XCTAssertEqual(beforeFailure.hostInvocations, [["prepare"]])
        XCTAssertEqual(beforeFailure.backendCalls, [])
        XCTAssertEqual(beforeFailure.result, .failure(exitCode: 31))

        let provisionFailure = try runAfterStopSkipScenario(
            specText: """
            schemaVersion: 1
            afterStop:
              - command: archive-output
            workload:
              command: echo
              workdir: /workspace
            """,
            provisionError: BackendTestError.provisionFailed
        )
        XCTAssertEqual(provisionFailure.hostInvocations, [])
        XCTAssertEqual(provisionFailure.backendCalls, [
            .provision("ephemeral-20260602-abcd"),
            .delete("ephemeral-20260602-abcd")
        ])
        XCTAssertEqual(provisionFailure.result, .failure(exitCode: 1))
        XCTAssertNil(provisionFailure.thrownError)

        let startFailure = try runAfterStopSkipScenario(
            specText: """
            schemaVersion: 1
            afterStop:
              - command: archive-output
            workload:
              command: echo
              workdir: /workspace
            """,
            startError: BackendTestError.startFailed
        )
        XCTAssertEqual(startFailure.hostInvocations, [])
        XCTAssertEqual(startFailure.backendCalls, [
            .provision("ephemeral-20260602-abcd"),
            .start("ephemeral-20260602-abcd"),
            .delete("ephemeral-20260602-abcd")
        ])
        XCTAssertEqual(startFailure.result, .failure(exitCode: 1))
        XCTAssertNil(startFailure.thrownError)
    }

    func testWorkloadNonzeroTriggersStopAfterStopDeleteAndFailureOutput() throws {
        let sandboxName = try SandboxName("ephemeral-20260602-abcd")
        var events: [String] = []
        var output: [String] = []
        let metadataStore = RecordingEphemeralMetadataStore(events: { events.append($0) })
        let backend = RecordingSandboxBackend(status: .missing, runResult: .failure(exitCode: 7), events: { events.append($0) })
        let runRecordStore = RecordingEphemeralRunRecordStore(
            identity: EphemeralRunIdentity(runID: "run-001", sandboxName: sandboxName, recordPath: "/tmp/sand-runs/run-001"),
            events: { events.append($0) }
        )
        let hostRunner = RecordingHostCommandRunner(
            results: [HostCommandResult(commandResult: .success, stdout: "processed partial\n", stderr: "")],
            events: { events.append($0) }
        )
        let coordinator = EphemeralRunCoordinator(
            metadataStore: metadataStore,
            backend: backend,
            runRecordStore: runRecordStore,
            hostCommandRunner: hostRunner,
            writeOutput: { output.append($0) }
        )
        let specText = """
        schemaVersion: 1
        afterStop:
          - command: process-partial
        workload:
          command: failing-workload
          workdir: /workspace
        """

        let result = try coordinator.run(EphemeralRunRequest(authoredSpecText: specText, sourcePath: "/tmp/spec.yaml"))

        XCTAssertEqual(result, .failure(exitCode: 7))
        XCTAssertEqual(hostRunner.invocations.map(\.commandArguments), [["process-partial"]])
        XCTAssertEqual(backend.calls, [
            .provision("ephemeral-20260602-abcd"),
            .start("ephemeral-20260602-abcd"),
            .run("ephemeral-20260602-abcd", ["failing-workload"], "/workspace"),
            .stop("ephemeral-20260602-abcd"),
            .delete("ephemeral-20260602-abcd")
        ])
        XCTAssertEqual(metadataStore.activeSpecNames, [])
        XCTAssertEqual(runRecordStore.resultStatus, "failure")
        XCTAssertEqual(runRecordStore.resultExitCode, 7)
        XCTAssertEqual(runRecordStore.resultFailedPhase, "workload")
        XCTAssertEqual(output, [
            "Ephemeral run status: failure",
            "Run record: /tmp/sand-runs/run-001",
            "Failed phase: workload",
            "Exit code: 7"
        ])
    }

    func testProvisionAndStartFailuresSkipAfterStopHooksButDeletePartialResourcesAndRecordFailurePhase() throws {
        let provisionFailure = try runAfterStopSkipScenario(
            specText: """
            schemaVersion: 1
            afterStop:
              - command: archive-output
            workload:
              command: echo
              workdir: /workspace
            """,
            provisionError: BackendTestError.provisionFailed
        )
        XCTAssertEqual(provisionFailure.hostInvocations, [])
        XCTAssertEqual(provisionFailure.backendCalls, [
            .provision("ephemeral-20260602-abcd"),
            .delete("ephemeral-20260602-abcd")
        ])
        XCTAssertEqual(provisionFailure.result, .failure(exitCode: 1))
        XCTAssertEqual(provisionFailure.resultFailedPhase, "provision")
        XCTAssertEqual(provisionFailure.activeSpecNames, [])

        let startFailure = try runAfterStopSkipScenario(
            specText: """
            schemaVersion: 1
            afterStop:
              - command: archive-output
            workload:
              command: echo
              workdir: /workspace
            """,
            startError: BackendTestError.startFailed
        )
        XCTAssertEqual(startFailure.hostInvocations, [])
        XCTAssertEqual(startFailure.backendCalls, [
            .provision("ephemeral-20260602-abcd"),
            .start("ephemeral-20260602-abcd"),
            .delete("ephemeral-20260602-abcd")
        ])
        XCTAssertEqual(startFailure.result, .failure(exitCode: 1))
        XCTAssertEqual(startFailure.resultFailedPhase, "start")
        XCTAssertEqual(startFailure.activeSpecNames, [])
    }

    func testDeleteFailureRecordsManualCleanupGuidanceAndOverridesEarlierWorkloadFailure() throws {
        let sandboxName = try SandboxName("ephemeral-20260602-abcd")
        var output: [String] = []
        let metadataStore = RecordingEphemeralMetadataStore(events: { _ in })
        let backend = RecordingSandboxBackend(
            status: .missing,
            deleteError: BackendTestError.deleteFailed,
            runResult: .failure(exitCode: 7)
        )
        let runRecordStore = RecordingEphemeralRunRecordStore(
            identity: EphemeralRunIdentity(runID: "run-001", sandboxName: sandboxName, recordPath: "/tmp/sand-runs/run-001"),
            events: { _ in }
        )
        let coordinator = EphemeralRunCoordinator(
            metadataStore: metadataStore,
            backend: backend,
            runRecordStore: runRecordStore,
            writeOutput: { output.append($0) }
        )
        let specText = """
        schemaVersion: 1
        workload:
          command: failing-workload
          workdir: /workspace
        """

        let result = try coordinator.run(EphemeralRunRequest(authoredSpecText: specText, sourcePath: "/tmp/spec.yaml"))

        XCTAssertEqual(result, .failure(exitCode: 1))
        XCTAssertEqual(runRecordStore.resultFailedPhase, "delete")
        XCTAssertEqual(runRecordStore.manualCleanupGuidance, "Delete Sandbox VM ephemeral-20260602-abcd manually with: sand delete ephemeral-20260602-abcd --force")
        XCTAssertEqual(metadataStore.activeSpecNames, ["ephemeral-20260602-abcd"])
        XCTAssertEqual(output, [
            "Ephemeral run status: failure",
            "Run record: /tmp/sand-runs/run-001",
            "Failed phase: delete",
            "Exit code: 1",
            "Manual cleanup: sand delete ephemeral-20260602-abcd --force"
        ])
    }

    func testResultPrecedenceUsesCleanupFailuresOverEarlierFailures() throws {
        let sandboxName = try SandboxName("ephemeral-20260602-abcd")
        let metadataStore = RecordingEphemeralMetadataStore(events: { _ in })
        let backend = RecordingSandboxBackend(status: .missing, runResult: .failure(exitCode: 7))
        let runRecordStore = RecordingEphemeralRunRecordStore(
            identity: EphemeralRunIdentity(runID: "run-001", sandboxName: sandboxName, recordPath: "/tmp/sand-runs/run-001"),
            events: { _ in }
        )
        let hostRunner = RecordingHostCommandRunner(
            results: [HostCommandResult(commandResult: .failure(exitCode: 23), stdout: "", stderr: "archive failed\n")],
            events: { _ in }
        )
        let coordinator = EphemeralRunCoordinator(
            metadataStore: metadataStore,
            backend: backend,
            runRecordStore: runRecordStore,
            hostCommandRunner: hostRunner,
            writeOutput: { _ in }
        )
        let specText = """
        schemaVersion: 1
        afterStop:
          - command: archive-output
        workload:
          command: failing-workload
          workdir: /workspace
        """

        let result = try coordinator.run(EphemeralRunRequest(authoredSpecText: specText, sourcePath: "/tmp/spec.yaml"))

        XCTAssertEqual(result, .failure(exitCode: 23))
        XCTAssertEqual(runRecordStore.resultFailedPhase, "afterStop")
    }

    func testProcessHostCommandRunnerUsesPathWorkingDirectoryEnvironmentAndCapturedNonInteractiveIO() throws {
        let fileManager = FileManager.default
        let root = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("sand-host-hook-\(UUID().uuidString)", isDirectory: true)
        let bin = root.appendingPathComponent("bin", isDirectory: true)
        let work = root.appendingPathComponent("work", isDirectory: true)
        try fileManager.createDirectory(at: bin, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: work, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: root) }
        let script = bin.appendingPathComponent("host-hook")
        try """
        #!/bin/sh
        printf 'cwd=%s\n' "$PWD"
        printf 'sentinel=%s\n' "$SAND_TEST_SENTINEL"
        if read line; then printf 'stdin=%s\n' "$line"; else printf 'stdin=closed\n'; fi
        printf 'err=%s\n' "$1" >&2
        """.write(to: script, atomically: true, encoding: .utf8)
        try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: script.path)

        let runner = ProcessHostCommandRunner()
        let result = try runner.run(
            HostCommandRequest(
                command: try WorkloadCommand(arguments: ["host-hook", "arg-one"]),
                workingDirectory: work.path,
                environment: ["PATH": bin.path, "SAND_TEST_SENTINEL": "inherited"]
            )
        )

        XCTAssertEqual(result.commandResult, .success)
        XCTAssertTrue(result.stdout.contains("cwd="), "got \(result.stdout)")
        XCTAssertTrue(result.stdout.contains("/work\n"), "got \(result.stdout)")
        XCTAssertTrue(result.stdout.contains("sentinel=inherited\n"), "got \(result.stdout)")
        XCTAssertTrue(result.stdout.contains("stdin=closed\n"), "got \(result.stdout)")
        XCTAssertEqual(result.stderr, "err=arg-one\n")
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
                unsupportedField: true
                workload:
                  command: echo
                  workdir: /workspace
                """,
                "unsupported v1 ephemeral spec field: unsupportedField"
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

    private func runAfterStopSkipScenario(
        specText: String,
        beforeProvisionResults: [HostCommandResult] = [],
        provisionError: (any Error)? = nil,
        startError: (any Error)? = nil
    ) throws -> AfterStopSkipScenarioResult {
        let sandboxName = try SandboxName("ephemeral-20260602-abcd")
        var events: [String] = []
        let metadataStore = RecordingEphemeralMetadataStore(events: { events.append($0) })
        let backend = RecordingSandboxBackend(
            status: .missing,
            provisionError: provisionError,
            startError: startError,
            events: { events.append($0) }
        )
        let runRecordStore = RecordingEphemeralRunRecordStore(
            identity: EphemeralRunIdentity(runID: "run-001", sandboxName: sandboxName, recordPath: "/tmp/sand-runs/run-001"),
            events: { events.append($0) }
        )
        let hostRunner = RecordingHostCommandRunner(results: beforeProvisionResults, events: { events.append($0) })
        let coordinator = EphemeralRunCoordinator(
            metadataStore: metadataStore,
            backend: backend,
            runRecordStore: runRecordStore,
            hostCommandRunner: hostRunner,
            writeOutput: { _ in }
        )

        do {
            let result = try coordinator.run(EphemeralRunRequest(authoredSpecText: specText, sourcePath: "/tmp/spec.yaml"))
            return AfterStopSkipScenarioResult(
                result: result,
                thrownError: nil,
                hostInvocations: hostRunner.invocations.map(\.commandArguments),
                backendCalls: backend.calls,
                resultFailedPhase: runRecordStore.resultFailedPhase,
                activeSpecNames: metadataStore.activeSpecNames
            )
        } catch {
            return AfterStopSkipScenarioResult(
                result: nil,
                thrownError: error,
                hostInvocations: hostRunner.invocations.map(\.commandArguments),
                backendCalls: backend.calls,
                resultFailedPhase: runRecordStore.resultFailedPhase,
                activeSpecNames: metadataStore.activeSpecNames
            )
        }
    }
}

private struct AfterStopSkipScenarioResult {
    var result: CommandResult?
    var thrownError: (any Error)?
    var hostInvocations: [[String]]
    var backendCalls: [BackendCall]
    var resultFailedPhase: String?
    var activeSpecNames: [String]
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

private struct RecordedHostCommandInvocation {
    var commandArguments: [String]
    var workingDirectory: String
    var environment: [String: String]
}

private final class RecordingHostCommandRunner: HostCommandRunner {
    private var results: [HostCommandResult]
    private let recordEvent: (String) -> Void
    private(set) var invocations: [RecordedHostCommandInvocation] = []

    init(results: [HostCommandResult], events: @escaping (String) -> Void) {
        self.results = results
        self.recordEvent = events
    }

    func run(_ request: HostCommandRequest) throws -> HostCommandResult {
        invocations.append(
            RecordedHostCommandInvocation(
                commandArguments: request.command.arguments,
                workingDirectory: request.workingDirectory,
                environment: request.environment
            )
        )
        recordEvent("host.run.\(request.command.arguments.joined(separator: " ")).\(request.workingDirectory)")
        return results.isEmpty ? HostCommandResult(commandResult: .success, stdout: "", stderr: "") : results.removeFirst()
    }
}

private final class RecordingEphemeralRunRecordStore: EphemeralRunRecordStore {
    let identity: EphemeralRunIdentity
    private let recordEvent: (String) -> Void
    private(set) var resultStatus: String?
    private(set) var resultExitCode: Int?
    private(set) var resultFailedPhase: String?
    private(set) var manualCleanupGuidance: String?
    private(set) var allocatedNamePrefixes: [String] = []
    private(set) var generatedSpecs: [SandboxSpec] = []
    private(set) var sourceSpecTexts: [String] = []
    private(set) var hookOutputs: [(phase: String, index: Int, stdout: String, stderr: String)] = []
    private(set) var hookEvents: [EphemeralRunEvent] = []

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
        sourceSpecTexts.append(sourceSpecText)
        recordEvent("record.createAttempt")
    }

    func writeGeneratedSpec(_ spec: SandboxSpec, identity: EphemeralRunIdentity) throws {
        generatedSpecs.append(spec)
        recordEvent("record.writeGeneratedSpec")
    }

    func writeHookOutput(phase: String, index: Int, stdout: String, stderr: String, identity: EphemeralRunIdentity) throws -> HookOutputReference {
        hookOutputs.append((phase: phase, index: index, stdout: stdout, stderr: stderr))
        recordEvent("record.writeHookOutput.\(phase).\(index)")
        return HookOutputReference(
            stdoutPath: "\(identity.recordPath)/\(phase)-\(index).stdout",
            stderrPath: "\(identity.recordPath)/\(phase)-\(index).stderr"
        )
    }

    func appendEvent(_ event: EphemeralRunEvent, identity: EphemeralRunIdentity) throws {
        hookEvents.append(event)
        recordEvent("record.appendEvent.\(event.phase).\(event.status)")
    }

    func writeResult(_ result: EphemeralRunResult, identity: EphemeralRunIdentity) throws {
        resultStatus = result.status
        resultExitCode = result.exitCode
        resultFailedPhase = result.failedPhase
        manualCleanupGuidance = result.manualCleanupGuidance
        recordEvent("record.writeResult.\(result.status)")
    }
}
