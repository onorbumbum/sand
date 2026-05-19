import XCTest
@testable import SandCore

private let guestStateBootstrapCommand = [
    "/bin/bash",
    "-lc",
    "sudo -n mkdir -p /state/sandbox/.pi /state/sandbox/secrets && sudo -n chown -R sandbox:sandbox /state/sandbox && exec sleep infinity"
]

final class AppleContainerCLIBackendDoctorTests: XCTestCase {
    func testDeleteUsesBackendForceAndDeletesGuestStateVolumeSoDestructiveConfirmationLivesOnlyInSand() throws {
        let runner = ScriptedBackendCommandRunner(results: [
            ["inspect", "mybox"]: .success(BackendCommandOutput(stdout: "[{\"status\":\"stopped\"}]\n", stderr: "", exitCode: 0)),
            ["delete", "--force", "mybox"]: .success(BackendCommandOutput(stdout: "", stderr: "", exitCode: 0)),
            ["volume", "inspect", "sand-state-mybox"]: .success(BackendCommandOutput(stdout: "[{\"name\":\"sand-state-mybox\"}]\n", stderr: "", exitCode: 0)),
            ["volume", "delete", "sand-state-mybox"]: .success(BackendCommandOutput(stdout: "", stderr: "", exitCode: 0))
        ])
        let backend = AppleContainerCLIBackend(runner: runner)

        try backend.delete(try SandboxName("mybox"))

        XCTAssertEqual(runner.calls, [
            ["inspect", "mybox"],
            ["delete", "--force", "mybox"],
            ["volume", "inspect", "sand-state-mybox"],
            ["volume", "delete", "sand-state-mybox"]
        ])
    }

    func testDeleteStillRemovesGuestStateVolumeWhenDisposableRuntimeIsAlreadyMissing() throws {
        let runner = ScriptedBackendCommandRunner(results: [
            ["inspect", "mybox"]: .success(BackendCommandOutput(stdout: "[]\n", stderr: "", exitCode: 0)),
            ["volume", "inspect", "sand-state-mybox"]: .success(BackendCommandOutput(stdout: "[{\"name\":\"sand-state-mybox\"}]\n", stderr: "", exitCode: 0)),
            ["volume", "delete", "sand-state-mybox"]: .success(BackendCommandOutput(stdout: "", stderr: "", exitCode: 0))
        ])
        let backend = AppleContainerCLIBackend(runner: runner)

        try backend.delete(try SandboxName("mybox"))

        XCTAssertEqual(runner.calls, [
            ["inspect", "mybox"],
            ["volume", "inspect", "sand-state-mybox"],
            ["volume", "delete", "sand-state-mybox"]
        ])
    }

    func testDeleteTreatsMissingRuntimeAndMissingGuestStateVolumeAsAlreadyDeleted() throws {
        let runner = ScriptedBackendCommandRunner(results: [
            ["inspect", "mybox"]: .success(BackendCommandOutput(stdout: "[]\n", stderr: "", exitCode: 0)),
            ["volume", "inspect", "sand-state-mybox"]: .success(BackendCommandOutput(stdout: "", stderr: "Error: volume 'sand-state-mybox' not found\n", exitCode: 0))
        ])
        let backend = AppleContainerCLIBackend(runner: runner)

        try backend.delete(try SandboxName("mybox"))

        XCTAssertEqual(runner.calls, [
            ["inspect", "mybox"],
            ["volume", "inspect", "sand-state-mybox"]
        ])
    }

    func testRunAndShellPassSandboxUserAndWorkdirBeforeSandboxNameForAppleExecSyntaxAndUseInheritedTerminalIO() throws {
        let runner = ScriptedBackendCommandRunner(results: [
            ["exec", "--interactive", "--tty", "--user", "sandbox", "--workdir", "/workspace", "mybox", "echo", "hello"]: .success(BackendCommandOutput(stdout: "", stderr: "", exitCode: 0)),
            ["exec", "--interactive", "--tty", "--user", "sandbox", "--workdir", "/workspace", "mybox", "/bin/bash"]: .success(BackendCommandOutput(stdout: "", stderr: "", exitCode: 0))
        ])
        let backend = AppleContainerCLIBackend(runner: runner, terminal: FixedBackendTerminal(inputIsTerminal: true, outputIsTerminal: true))
        let name = try SandboxName("mybox")
        let workdir = try GuestPath("/workspace")

        XCTAssertEqual(try backend.run(BackendRunRequest(sandboxName: name, command: try WorkloadCommand(arguments: ["echo", "hello"]), workingDirectory: workdir)), .success)
        XCTAssertEqual(try backend.shell(BackendShellRequest(sandboxName: name, workingDirectory: workdir)), .success)

        XCTAssertEqual(runner.calls, [
            ["exec", "--interactive", "--tty", "--user", "sandbox", "--workdir", "/workspace", "mybox", "echo", "hello"],
            ["exec", "--interactive", "--tty", "--user", "sandbox", "--workdir", "/workspace", "mybox", "/bin/bash"]
        ])
        XCTAssertEqual(runner.ioModes, [.inherited, .inherited])
    }

    func testRunDoesNotAllocateTTYForRedirectedUsageButKeepsStandardInputOpen() throws {
        let runner = ScriptedBackendCommandRunner(results: [
            ["exec", "--interactive", "--user", "sandbox", "--workdir", "/workspace", "mybox", "grep", "needle"]: .success(BackendCommandOutput(stdout: "", stderr: "", exitCode: 0))
        ])
        let backend = AppleContainerCLIBackend(runner: runner, terminal: FixedBackendTerminal(inputIsTerminal: false, outputIsTerminal: false))

        let result = try backend.run(
            BackendRunRequest(
                sandboxName: try SandboxName("mybox"),
                command: try WorkloadCommand(arguments: ["grep", "needle"]),
                workingDirectory: try GuestPath("/workspace")
            )
        )

        XCTAssertEqual(result, .success)
        XCTAssertEqual(runner.calls, [["exec", "--interactive", "--user", "sandbox", "--workdir", "/workspace", "mybox", "grep", "needle"]])
        XCTAssertEqual(runner.ioModes, [.inherited])
    }

    func testMissingWorkloadCommandReturnsBackendExitCodeWithoutSwallowingContainerErrorOutput() throws {
        let runner = ScriptedBackendCommandRunner(results: [
            ["exec", "--interactive", "--user", "sandbox", "--workdir", "/workspace", "mybox", "not-installed-tool"]: .success(BackendCommandOutput(stdout: "", stderr: "command not found\n", exitCode: 127))
        ])
        let backend = AppleContainerCLIBackend(runner: runner, terminal: FixedBackendTerminal(inputIsTerminal: false, outputIsTerminal: false))

        let result = try backend.run(
            BackendRunRequest(
                sandboxName: try SandboxName("mybox"),
                command: try WorkloadCommand(arguments: ["not-installed-tool"]),
                workingDirectory: try GuestPath("/workspace")
            )
        )

        XCTAssertEqual(result, .failure(exitCode: 127))
        XCTAssertEqual(runner.ioModes, [.inherited])
    }

    func testProvisionCreatesNamedStoppedSandboxWithGuestStateVolumeAllowedFolderMountsResourceProfileAndImage() throws {
        let create = ["create", "--name", "mybox", "--cpus", "6", "--memory", "12288M", "--volume", "sand-state-mybox:/state", "--mount", "type=bind,source=/Users/onur/Projects/sand,target=/workspace/sand", "--mount", "type=bind,source=/Users/onur/Downloads,target=/reference,readonly", "custom:latest"] + guestStateBootstrapCommand
        let runner = ScriptedBackendCommandRunner(results: [
            ["volume", "inspect", "sand-state-mybox"]: .success(BackendCommandOutput(stdout: "", stderr: "not found\n", exitCode: 1)),
            ["volume", "create", "sand-state-mybox"]: .success(BackendCommandOutput(stdout: "sand-state-mybox\n", stderr: "", exitCode: 0)),
            create: .success(BackendCommandOutput(stdout: "mybox\n", stderr: "", exitCode: 0))
        ])
        let backend = AppleContainerCLIBackend(runner: runner)
        let spec = SandboxSpec(
            name: try SandboxName("mybox"),
            image: SandboxImage(reference: "custom:latest"),
            resourceProfile: ResourceProfile(cpus: 6, memory: MemorySize(gigabytes: 12)),
            allowedFolders: [
                AllowedFolder(displayHostPath: "~/Projects/sand", resolvedHostPath: "/Users/onur/Projects/sand", guestPath: try GuestPath("/workspace/sand"), accessMode: .readWrite),
                AllowedFolder(displayHostPath: "~/Downloads", resolvedHostPath: "/Users/onur/Downloads", guestPath: try GuestPath("/reference"), accessMode: .readOnly)
            ]
        )

        try backend.provision(spec)

        XCTAssertEqual(runner.calls, [
            ["volume", "inspect", "sand-state-mybox"],
            ["volume", "create", "sand-state-mybox"],
            create
        ])
    }

    func testProvisionWithoutAllowedFoldersDoesNotMountHostPiOrCredentialsByDefault() throws {
        let create = ["create", "--name", "mybox", "--cpus", "4", "--memory", "8192M", "--volume", "sand-state-mybox:/state", "sand/developer-ready:ubuntu-lts"] + guestStateBootstrapCommand
        let runner = ScriptedBackendCommandRunner(results: [
            ["volume", "inspect", "sand-state-mybox"]: .success(BackendCommandOutput(stdout: "", stderr: "not found\n", exitCode: 1)),
            ["volume", "create", "sand-state-mybox"]: .success(BackendCommandOutput(stdout: "sand-state-mybox\n", stderr: "", exitCode: 0)),
            create: .success(BackendCommandOutput(stdout: "mybox\n", stderr: "", exitCode: 0))
        ])
        let backend = AppleContainerCLIBackend(runner: runner)

        try backend.provision(.generated(name: try SandboxName("mybox")))

        let createArguments = try XCTUnwrap(runner.calls.last)
        XCTAssertEqual(createArguments, create)
        let commandText = createArguments.joined(separator: " ")
        for forbidden in ["--mount", "/Users/", ".aws", ".config/gcloud", "SSH_AUTH_SOCK", "/run/host-services"] {
            XCTAssertFalse(commandText.contains(forbidden), "default provisioning must not expose host credential surface: \(forbidden)")
        }
    }

    func testApplyRecreatesStoppedRuntimeWithCurrentAllowedFoldersWhilePreservingGuestStateVolume() throws {
        let create = ["create", "--name", "mybox", "--cpus", "4", "--memory", "8192M", "--volume", "sand-state-mybox:/state", "--mount", "type=bind,source=/Users/onur/Projects/sand,target=/workspace/sand", "sand/developer-ready:ubuntu-lts"] + guestStateBootstrapCommand
        let runner = ScriptedBackendCommandRunner(results: [
            ["inspect", "mybox"]: .success(BackendCommandOutput(stdout: "[{\"status\":\"stopped\"}]\n", stderr: "", exitCode: 0)),
            ["delete", "--force", "mybox"]: .success(BackendCommandOutput(stdout: "", stderr: "", exitCode: 0)),
            ["volume", "inspect", "sand-state-mybox"]: .success(BackendCommandOutput(stdout: "[{\"name\":\"sand-state-mybox\"}]\n", stderr: "", exitCode: 0)),
            create: .success(BackendCommandOutput(stdout: "mybox\n", stderr: "", exitCode: 0))
        ])
        let backend = AppleContainerCLIBackend(runner: runner)
        let spec = SandboxSpec(
            name: try SandboxName("mybox"),
            allowedFolders: [AllowedFolder(displayHostPath: "~/Projects/sand", resolvedHostPath: "/Users/onur/Projects/sand", guestPath: try GuestPath("/workspace/sand"), accessMode: .readWrite)]
        )

        try backend.apply(spec)

        XCTAssertEqual(runner.calls, [
            ["inspect", "mybox"],
            ["delete", "--force", "mybox"],
            ["volume", "inspect", "sand-state-mybox"],
            create
        ])
    }

    func testApplyRestartsRuntimeAfterRecreatingIfItWasRunning() throws {
        let create = ["create", "--name", "mybox", "--cpus", "4", "--memory", "8192M", "--volume", "sand-state-mybox:/state", "sand/developer-ready:ubuntu-lts"] + guestStateBootstrapCommand
        let runner = ScriptedBackendCommandRunner(results: [
            ["inspect", "mybox"]: .success(BackendCommandOutput(stdout: "[{\"status\":\"running\"}]\n", stderr: "", exitCode: 0)),
            ["stop", "mybox"]: .success(BackendCommandOutput(stdout: "", stderr: "", exitCode: 0)),
            ["delete", "--force", "mybox"]: .success(BackendCommandOutput(stdout: "", stderr: "", exitCode: 0)),
            ["volume", "inspect", "sand-state-mybox"]: .success(BackendCommandOutput(stdout: "[{\"name\":\"sand-state-mybox\"}]\n", stderr: "", exitCode: 0)),
            create: .success(BackendCommandOutput(stdout: "mybox\n", stderr: "", exitCode: 0)),
            ["start", "mybox"]: .success(BackendCommandOutput(stdout: "", stderr: "", exitCode: 0))
        ])
        let backend = AppleContainerCLIBackend(runner: runner)

        try backend.apply(.generated(name: try SandboxName("mybox")))

        XCTAssertEqual(runner.calls, [
            ["inspect", "mybox"],
            ["stop", "mybox"],
            ["delete", "--force", "mybox"],
            ["volume", "inspect", "sand-state-mybox"],
            create,
            ["start", "mybox"]
        ])
    }

    func testProvisionThrowsWhenBackendCreateCommandFails() throws {
        let create = ["create", "--name", "mybox", "--cpus", "4", "--memory", "8192M", "--volume", "sand-state-mybox:/state", "sand/developer-ready:ubuntu-lts"] + guestStateBootstrapCommand
        let runner = ScriptedBackendCommandRunner(results: [
            ["volume", "inspect", "sand-state-mybox"]: .success(BackendCommandOutput(stdout: "", stderr: "not found\n", exitCode: 1)),
            ["volume", "create", "sand-state-mybox"]: .success(BackendCommandOutput(stdout: "sand-state-mybox\n", stderr: "", exitCode: 0)),
            create: .success(BackendCommandOutput(stdout: "", stderr: "image not found\n", exitCode: 1))
        ])
        let backend = AppleContainerCLIBackend(runner: runner)

        XCTAssertThrowsError(try backend.provision(.generated(name: try SandboxName("mybox"))))
    }

    func testStatusTranslatesAppleInspectJsonToSandboxRuntimeStatus() throws {
        let runner = ScriptedBackendCommandRunner(results: [
            ["inspect", "missing"]: .success(BackendCommandOutput(stdout: "[]\n", stderr: "", exitCode: 0)),
            ["inspect", "stopped"]: .success(BackendCommandOutput(stdout: "[{\"status\":\"stopped\"}]\n", stderr: "", exitCode: 0)),
            ["inspect", "running"]: .success(BackendCommandOutput(stdout: "[{\"status\":\"running\"}]\n", stderr: "", exitCode: 0))
        ])
        let backend = AppleContainerCLIBackend(runner: runner)

        XCTAssertEqual(try backend.status(try SandboxName("missing")), .missing)
        XCTAssertEqual(try backend.status(try SandboxName("stopped")), .stopped)
        XCTAssertEqual(try backend.status(try SandboxName("running")), .running)
    }

    func testDoctorReportsBackendServiceFailureWithoutMisreportingImageWhenAutoStartFails() throws {
        let runner = ScriptedBackendCommandRunner(results: [
            ["--version"]: .success(BackendCommandOutput(stdout: "container 0.12.3\n", stderr: "", exitCode: 0)),
            ["system", "status"]: .success(BackendCommandOutput(stdout: "status             stopped\n", stderr: "", exitCode: 0)),
            ["system", "start"]: .success(BackendCommandOutput(stdout: "", stderr: "could not start\n", exitCode: 1))
        ])
        let backend = AppleContainerCLIBackend(runner: runner)

        let readiness = try backend.checkReadiness()

        XCTAssertEqual(readiness, .notReady([
            DoctorFinding(
                kind: .backendServiceStopped,
                message: "Backend Service is not running and sand could not auto-start it. Check the backend service, then retry `sand doctor`."
            )
        ]))
        XCTAssertEqual(runner.calls, [
            ["--version"],
            ["system", "status"],
            ["system", "start"],
            ["system", "status"]
        ])
    }

    func testDoctorReportsMissingDefaultSandboxImageAfterBackendServiceIsRunning() throws {
        let runner = ScriptedBackendCommandRunner(results: [
            ["--version"]: .success(BackendCommandOutput(stdout: "container 0.12.3\n", stderr: "", exitCode: 0)),
            ["system", "status"]: .success(BackendCommandOutput(stdout: "status             running\n", stderr: "", exitCode: 0)),
            ["image", "inspect", "sand/developer-ready:ubuntu-lts"]: .success(BackendCommandOutput(stdout: "", stderr: "image not found\n", exitCode: 1))
        ])
        let backend = AppleContainerCLIBackend(runner: runner)

        let readiness = try backend.checkReadiness()

        XCTAssertEqual(readiness, .notReady([
            DoctorFinding(
                kind: .defaultImageMissing,
                message: "Default Sandbox Image sand/developer-ready:ubuntu-lts is not available. Build it with scripts/build-developer-ready-image.sh before creating Sandbox VMs."
            )
        ]))
        XCTAssertEqual(runner.calls, [
            ["--version"],
            ["system", "status"],
            ["image", "inspect", "sand/developer-ready:ubuntu-lts"]
        ])
    }
}

private final class ScriptedBackendCommandRunner: BackendCommandRunner {
    enum Result {
        case success(BackendCommandOutput)
        case failure(any Error)
    }

    private let results: [[String]: Result]
    var calls: [[String]] = []
    var ioModes: [BackendCommandIO] = []

    init(results: [[String]: Result]) {
        self.results = results
    }

    func run(arguments: [String], io: BackendCommandIO) throws -> BackendCommandOutput {
        calls.append(arguments)
        ioModes.append(io)
        guard let result = results[arguments] else {
            throw UnexpectedBackendCommand(arguments: arguments)
        }
        switch result {
        case .success(let output): return output
        case .failure(let error): throw error
        }
    }
}

private struct FixedBackendTerminal: BackendTerminal {
    var inputIsTerminal: Bool
    var outputIsTerminal: Bool

    var standardInputIsTerminal: Bool { inputIsTerminal }
    var standardOutputIsTerminal: Bool { outputIsTerminal }
}

private struct UnexpectedBackendCommand: Error, Equatable {
    var arguments: [String]
}
