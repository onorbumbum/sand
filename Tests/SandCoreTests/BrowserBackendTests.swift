import XCTest
@testable import SandCore

private func ok(_ stdout: String) -> ScriptedBackendCommandRunner.Result {
    .success(BackendCommandOutput(stdout: stdout, stderr: "", exitCode: 0))
}

private func fail(_ stderr: String) -> ScriptedBackendCommandRunner.Result {
    .success(BackendCommandOutput(stdout: "", stderr: stderr, exitCode: 1))
}

private let browserBootstrapCommand = [
    "/bin/bash",
    "-lc",
    "sudo -n mkdir -p /state/sandbox/.pi /state/sandbox/secrets && sudo -n chown -R sandbox:sandbox /state/sandbox && exec /usr/local/bin/sand-browser-up"
]

private func browserSpec() throws -> SandboxSpec {
    SandboxSpec(
        name: try SandboxName("web"),
        image: .browserDefault,
        resourceProfile: ResourceProfile(cpus: 2, memory: MemorySize(gigabytes: 2)),
        browser: BrowserSettings(viewPort: 6081)
    )
}

final class AppleContainerBrowserTests: XCTestCase {
    func testBrowserSandboxPublishesOnlyTheNoVNCViewOnHostLoopbackAndStartsTheBrowser() throws {
        let create = ["create", "--name", "web", "--cpus", "2", "--memory", "2048M", "--volume", "sand-state-web:/state", "--publish", "127.0.0.1:6081:6080", "sand/browser:ubuntu-lts"] + browserBootstrapCommand
        let runner = ScriptedBackendCommandRunner(results: [
            ["volume", "inspect", "sand-state-web"]: fail("not found\n"),
            ["volume", "create", "sand-state-web"]: ok("sand-state-web\n"),
            create: ok("web\n")
        ])

        try AppleContainerCLIBackend(runner: runner).provision(try browserSpec())

        XCTAssertEqual(runner.calls.last, create)
        XCTAssertFalse(runner.calls.last!.contains { $0.contains("9222") }, "DevTools must never be published")
    }
}

final class DockerCLIBackendTests: XCTestCase {
    func testProvisionCreatesContainerWithStateVolumeFoldersResourcesAndImage() throws {
        let create = ["create", "--name", "mybox", "--hostname", "mybox", "--cpus", "2", "--memory", "3072M", "--volume", "sand-state-mybox:/state", "--mount", "type=bind,source=/Users/onur/site,target=/workspace", "--mount", "type=bind,source=/Users/onur/ref,target=/reference,readonly", "sand/developer-ready:ubuntu-lts", "/bin/bash", "-lc", "sudo -n mkdir -p /state/sandbox/.pi /state/sandbox/secrets && sudo -n chown -R sandbox:sandbox /state/sandbox && exec sleep infinity"]
        let runner = ScriptedBackendCommandRunner(results: [
            ["volume", "inspect", "sand-state-mybox"]: fail("Error response from daemon: get sand-state-mybox: no such volume\n"),
            ["volume", "create", "sand-state-mybox"]: ok("sand-state-mybox\n"),
            create: ok("abc123\n")
        ])
        let spec = SandboxSpec(
            name: try SandboxName("mybox"),
            resourceProfile: ResourceProfile(cpus: 2, memory: MemorySize(megabytes: 3072)),
            sharedFolders: [
                SharedFolder(displayHostPath: "~/site", resolvedHostPath: "/Users/onur/site", guestPath: try GuestPath("/workspace"), accessMode: .readWrite),
                SharedFolder(displayHostPath: "~/ref", resolvedHostPath: "/Users/onur/ref", guestPath: try GuestPath("/reference"), accessMode: .readOnly)
            ]
        )

        try DockerCLIBackend(runner: runner).provision(spec)

        XCTAssertEqual(runner.calls, [["volume", "inspect", "sand-state-mybox"], ["volume", "create", "sand-state-mybox"], create])
    }

    func testBrowserSandboxPublishesOnlyTheNoVNCViewOnHostLoopback() throws {
        let create = ["create", "--name", "web", "--hostname", "web", "--cpus", "2", "--memory", "2048M", "--volume", "sand-state-web:/state", "--publish", "127.0.0.1:6081:6080", "--shm-size", "1g", "sand/browser:ubuntu-lts"] + browserBootstrapCommand
        let runner = ScriptedBackendCommandRunner(results: [
            ["volume", "inspect", "sand-state-web"]: ok("[{}]\n"),
            create: ok("abc\n")
        ])

        try DockerCLIBackend(runner: runner).provision(try browserSpec())

        XCTAssertEqual(runner.calls.last, create)
    }

    func testStatusReadsDockerStateAndTreatsNoSuchContainerAsMissing() throws {
        let runner = ScriptedBackendCommandRunner(results: [
            ["container", "inspect", "--format", "{{.State.Status}}", "gone"]: fail("Error: No such container: gone\n"),
            ["container", "inspect", "--format", "{{.State.Status}}", "idle"]: ok("exited\n"),
            ["container", "inspect", "--format", "{{.State.Status}}", "fresh"]: ok("created\n"),
            ["container", "inspect", "--format", "{{.State.Status}}", "busy"]: ok("running\n")
        ])
        let backend = DockerCLIBackend(runner: runner)

        XCTAssertEqual(try backend.status(try SandboxName("gone")), .missing)
        XCTAssertEqual(try backend.status(try SandboxName("idle")), .stopped)
        XCTAssertEqual(try backend.status(try SandboxName("fresh")), .stopped)
        XCTAssertEqual(try backend.status(try SandboxName("busy")), .running)
    }

    func testDeleteForceRemovesContainerThenGuestStateVolume() throws {
        let runner = ScriptedBackendCommandRunner(results: [
            ["container", "inspect", "--format", "{{.State.Status}}", "mybox"]: ok("exited\n"),
            ["rm", "--force", "mybox"]: ok("mybox\n"),
            ["volume", "inspect", "sand-state-mybox"]: ok("[{}]\n"),
            ["volume", "rm", "sand-state-mybox"]: ok("sand-state-mybox\n")
        ])

        try DockerCLIBackend(runner: runner).delete(try SandboxName("mybox"))

        XCTAssertEqual(runner.calls.last, ["volume", "rm", "sand-state-mybox"])
        XCTAssertTrue(runner.calls.contains(["rm", "--force", "mybox"]))
    }

    func testRunExecsAsSandboxUserInMappedWorkdirWithInheritedIO() throws {
        let exec = ["exec", "--interactive", "--tty", "--user", "sandbox", "--workdir", "/workspace", "mybox", "pi", "--version"]
        let runner = ScriptedBackendCommandRunner(results: [exec: ok("")])
        let backend = DockerCLIBackend(runner: runner, terminal: FixedBackendTerminal(inputIsTerminal: true, outputIsTerminal: true))

        let result = try backend.run(BackendRunRequest(sandboxName: try SandboxName("mybox"), command: try WorkloadCommand(arguments: ["pi", "--version"]), workingDirectory: try GuestPath("/workspace")))

        XCTAssertEqual(result, .success)
        XCTAssertEqual(runner.calls, [exec])
        XCTAssertEqual(runner.ioModes, [.inherited])
    }

    func testDoctorExplainsHowToStartColimaWhenDockerDaemonIsDown() throws {
        let runner = ScriptedBackendCommandRunner(results: [
            ["--version"]: ok("Docker version 29.0.0\n"),
            ["info", "--format", "{{.ServerVersion}}"]: fail("Cannot connect to the Docker daemon\n")
        ])

        let readiness = try DockerCLIBackend(runner: runner).checkReadiness()

        XCTAssertEqual(readiness, .notReady([
            DoctorFinding(kind: .backendServiceStopped, message: "Docker daemon is not reachable. Start it (for example `colima start --cpu 4 --memory 4`), then retry `sand doctor`.")
        ]))
    }

    func testDoctorReportsMissingDefaultImage() throws {
        let runner = ScriptedBackendCommandRunner(results: [
            ["--version"]: ok("Docker version 29.0.0\n"),
            ["info", "--format", "{{.ServerVersion}}"]: ok("29.0.0\n"),
            ["image", "inspect", "sand/developer-ready:ubuntu-lts"]: fail("No such image\n")
        ])

        let readiness = try DockerCLIBackend(runner: runner).checkReadiness()

        XCTAssertEqual(readiness, .notReady([
            DoctorFinding(kind: .defaultImageMissing, message: "Default Sandbox Image sand/developer-ready:ubuntu-lts is not available. Build it with scripts/build-developer-ready-image.sh before creating Sandbox VMs.")
        ]))
    }
}

final class LinuxBackendSelectionTests: XCTestCase {
    func testIntelMacsUseDockerAndAppleSiliconUsesAppleContainer() {
        XCTAssertEqual(LinuxBackendKind.select(environment: [:], isAppleSilicon: false), .docker)
        XCTAssertEqual(LinuxBackendKind.select(environment: [:], isAppleSilicon: true), .appleContainer)
    }

    func testEnvironmentOverrideWins() {
        XCTAssertEqual(LinuxBackendKind.select(environment: ["SAND_LINUX_BACKEND": "docker"], isAppleSilicon: true), .docker)
        XCTAssertEqual(LinuxBackendKind.select(environment: ["SAND_LINUX_BACKEND": "apple-container"], isAppleSilicon: false), .appleContainer)
    }
}

final class HostDoctorPlatformTests: XCTestCase {
    func testDockerBackendMakesIntelMacsSupported() {
        XCTAssertTrue(HostDoctorPlatform(linuxBackend: .docker, isAppleSilicon: false).isSupported)
        XCTAssertFalse(HostDoctorPlatform(linuxBackend: .appleContainer, isAppleSilicon: false).isSupported)
        XCTAssertTrue(HostDoctorPlatform(linuxBackend: .appleContainer, isAppleSilicon: true).isSupported)
    }
}

final class DockerErrorTranslationTests: XCTestCase {
    func testSharedFolderOutsideTheDockerVMSharesExplainsTheFix() {
        let error = DockerCLIBackendError.commandFailed(
            arguments: ["create", "--name", "t1", "--mount", "type=bind,source=/private/tmp/proj,target=/workspace", "img"],
            exitCode: 125,
            stderr: "Error response from daemon: invalid mount config for type \"bind\": bind source path does not exist: /private/tmp/proj\n"
        )

        XCTAssertEqual(
            BackendErrorTranslator().translate(error),
            .commandFailed("Shared Folder /private/tmp/proj is not visible to the Docker VM. colima shares only your home folder by default: use a folder under ~, or add a mount with `colima start --edit`.")
        )
    }

    func testDockerDaemonDownIsReportedAsServiceUnavailable() {
        let error = DockerCLIBackendError.commandFailed(arguments: ["start", "t1"], exitCode: 1, stderr: "Cannot connect to the Docker daemon at unix:///var/run/docker.sock. Is the docker daemon running?\n")

        XCTAssertEqual(
            BackendErrorTranslator().translate(error),
            .serviceUnavailable("Sandbox backend service is not available. Run `sand doctor` to repair prerequisites, then retry.")
        )
    }

    func testUnrecognisedDockerFailuresKeepTheEngineDetail() {
        let error = DockerCLIBackendError.commandFailed(arguments: ["create", "--name", "t1", "img"], exitCode: 125, stderr: "Error response from daemon: Conflict. The container name \"/t1\" is already in use\n")

        guard case .commandFailed(let message) = BackendErrorTranslator().translate(error) else { return XCTFail("expected commandFailed") }
        XCTAssertTrue(message.contains("The container name \"/t1\" is already in use"), message)
    }
}
