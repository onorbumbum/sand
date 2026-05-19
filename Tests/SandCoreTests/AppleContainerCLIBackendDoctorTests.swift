import XCTest
@testable import SandCore

final class AppleContainerCLIBackendDoctorTests: XCTestCase {
    func testDeleteUsesBackendForceSoDestructiveConfirmationLivesOnlyInSand() throws {
        let runner = ScriptedBackendCommandRunner(results: [
            ["delete", "--force", "mybox"]: .success(BackendCommandOutput(stdout: "", stderr: "", exitCode: 0))
        ])
        let backend = AppleContainerCLIBackend(runner: runner)

        try backend.delete(try SandboxName("mybox"))

        XCTAssertEqual(runner.calls, [["delete", "--force", "mybox"]])
    }

    func testRunAndShellPassWorkdirBeforeSandboxNameForAppleExecSyntaxAndUseInheritedTerminalIO() throws {
        let runner = ScriptedBackendCommandRunner(results: [
            ["exec", "--interactive", "--tty", "--workdir", "/workspace", "mybox", "echo", "hello"]: .success(BackendCommandOutput(stdout: "", stderr: "", exitCode: 0)),
            ["exec", "--interactive", "--tty", "--workdir", "/workspace", "mybox", "/bin/bash"]: .success(BackendCommandOutput(stdout: "", stderr: "", exitCode: 0))
        ])
        let backend = AppleContainerCLIBackend(runner: runner, terminal: FixedBackendTerminal(inputIsTerminal: true, outputIsTerminal: true))
        let name = try SandboxName("mybox")
        let workdir = try GuestPath("/workspace")

        XCTAssertEqual(try backend.run(BackendRunRequest(sandboxName: name, command: try WorkloadCommand(arguments: ["echo", "hello"]), workingDirectory: workdir)), .success)
        XCTAssertEqual(try backend.shell(BackendShellRequest(sandboxName: name, workingDirectory: workdir)), .success)

        XCTAssertEqual(runner.calls, [
            ["exec", "--interactive", "--tty", "--workdir", "/workspace", "mybox", "echo", "hello"],
            ["exec", "--interactive", "--tty", "--workdir", "/workspace", "mybox", "/bin/bash"]
        ])
        XCTAssertEqual(runner.ioModes, [.inherited, .inherited])
    }

    func testRunDoesNotAllocateTTYForRedirectedUsageButKeepsStandardInputOpen() throws {
        let runner = ScriptedBackendCommandRunner(results: [
            ["exec", "--interactive", "--workdir", "/workspace", "mybox", "grep", "needle"]: .success(BackendCommandOutput(stdout: "", stderr: "", exitCode: 0))
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
        XCTAssertEqual(runner.calls, [["exec", "--interactive", "--workdir", "/workspace", "mybox", "grep", "needle"]])
        XCTAssertEqual(runner.ioModes, [.inherited])
    }

    func testMissingWorkloadCommandReturnsBackendExitCodeWithoutSwallowingContainerErrorOutput() throws {
        let runner = ScriptedBackendCommandRunner(results: [
            ["exec", "--interactive", "--workdir", "/workspace", "mybox", "not-installed-tool"]: .success(BackendCommandOutput(stdout: "", stderr: "command not found\n", exitCode: 127))
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

    func testProvisionCreatesNamedStoppedSandboxWithLongLivedInitResourceProfileAndImage() throws {
        let runner = ScriptedBackendCommandRunner(results: [
            ["create", "--name", "mybox", "--cpus", "6", "--memory", "12288M", "custom:latest", "sleep", "infinity"]: .success(BackendCommandOutput(stdout: "mybox\n", stderr: "", exitCode: 0))
        ])
        let backend = AppleContainerCLIBackend(runner: runner)
        let spec = SandboxSpec(
            name: try SandboxName("mybox"),
            image: SandboxImage(reference: "custom:latest"),
            resourceProfile: ResourceProfile(cpus: 6, memory: MemorySize(gigabytes: 12))
        )

        try backend.provision(spec)

        XCTAssertEqual(runner.calls, [["create", "--name", "mybox", "--cpus", "6", "--memory", "12288M", "custom:latest", "sleep", "infinity"]])
    }

    func testProvisionThrowsWhenBackendCreateCommandFails() throws {
        let runner = ScriptedBackendCommandRunner(results: [
            ["create", "--name", "mybox", "--cpus", "4", "--memory", "8192M", "sand/developer-ready:ubuntu-lts", "sleep", "infinity"]: .success(BackendCommandOutput(stdout: "", stderr: "image not found\n", exitCode: 1))
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
                message: "Backend Service is not running and sand could not auto-start it. Run `container system start` and retry `sand doctor`."
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
