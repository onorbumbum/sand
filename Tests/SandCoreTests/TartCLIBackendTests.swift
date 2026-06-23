import XCTest
@testable import SandCore

final class TartCLIBackendTests: XCTestCase {
    func testProvisionClonesSetsResourcesInjectsKeyAndLeavesSandboxStopped() throws {
        let name = try SandboxName("macbox")
        let keyStore = StaticTartKeyStore()
        let starter = RecordingTartVMStarter()
        let runner = ScriptedTartRunner(results: [
            ["--version"]: .success(.init(stdout: "2.32.1\n", stderr: "", exitCode: 0)),
            ["clone", "ghcr.io/example/macos:latest", "macbox"]: .success(.init(stdout: "cloned\n", stderr: "", exitCode: 0)),
            ["set", "macbox", "--cpu", "4", "--memory", "8192"]: .success(.init(stdout: "", stderr: "", exitCode: 0)),
            ["ip", "macbox"]: .success(.init(stdout: "192.168.65.2\n", stderr: "", exitCode: 0)),
            ["exec", "macbox", "/bin/zsh", "-lc", "mkdir -p ~/.ssh && chmod 700 ~/.ssh && grep -qxF 'ssh-ed25519 TEST sand-macbox' ~/.ssh/authorized_keys 2>/dev/null || printf '%s\\n' 'ssh-ed25519 TEST sand-macbox' >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && sync"]: .success(.init(stdout: "", stderr: "", exitCode: 0)),
            ["stop", "macbox"]: .success(.init(stdout: "", stderr: "", exitCode: 0))
        ])
        let backend = TartCLIBackend(runner: runner, sshRunner: ScriptedTartRunner(results: [:]), starter: starter, keyStore: keyStore, sleeper: { _ in }, maxIPAttempts: 1)

        try backend.provision(SandboxSpec(name: name, image: SandboxImage(reference: "ghcr.io/example/macos:latest"), guestOS: .macOS))

        XCTAssertEqual(runner.calls, [
            ["--version"],
            ["clone", "ghcr.io/example/macos:latest", "macbox"],
            ["set", "macbox", "--cpu", "4", "--memory", "8192"],
            ["ip", "macbox"],
            ["exec", "macbox", "/bin/zsh", "-lc", "mkdir -p ~/.ssh && chmod 700 ~/.ssh && grep -qxF 'ssh-ed25519 TEST sand-macbox' ~/.ssh/authorized_keys 2>/dev/null || printf '%s\\n' 'ssh-ed25519 TEST sand-macbox' >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && sync"],
            ["stop", "macbox"]
        ])
        XCTAssertEqual(starter.calls, [TartStartCall(arguments: ["run", "--no-graphics", "macbox"], logPath: "/tmp/macbox-start.log")])
        XCTAssertEqual(keyStore.created, ["macbox"])
        XCTAssertTrue(keyStore.logs["macbox:clone"]?.contains("cloned") == true)
    }

    func testStartMountsMacOSSharedFoldersAndCreatesGuestPathSymlinks() throws {
        let name = try SandboxName("macbox")
        let starter = RecordingTartVMStarter()
        let syntheticScript = "set -e\nsudo -n mkdir -p /etc/synthetic.d\nmkdir -p '/Users/admin/.sand/synthetic/workspace'\ncurrent=$(cat /etc/synthetic.d/sand 2>/dev/null || true)\ndesired='workspace\tUsers/admin/.sand/synthetic/workspace\n'\nneeds_restart=0\nif [ \"$current\" != \"$desired\" ]; then printf '%s' \"$desired\" | sudo -n tee /etc/synthetic.d/sand >/dev/null; needs_restart=1; fi\nif [ ! -e '/workspace' ]; then needs_restart=1; fi\nif [ \"$needs_restart\" = 1 ]; then sync; echo SAND_SYNTHETIC_CHANGED; fi"
        let symlinkScript = """
        set -e
        sudo -n mkdir -p '/workspace'
        if [ -e '/workspace/sand' ] && [ ! -L '/workspace/sand' ]; then echo 'Guest Path exists and is not a symlink: /workspace/sand' >&2; exit 1; fi
        sudo -n rm -f '/workspace/sand'
        sudo -n ln -s '/Volumes/My Shared Files/sand-L3dvcmtzcGFjZS9zYW5k' '/workspace/sand'
        sudo -n mkdir -p '/Users/admin'
        if [ -e '/Users/admin/reference' ] && [ ! -L '/Users/admin/reference' ]; then echo 'Guest Path exists and is not a symlink: /Users/admin/reference' >&2; exit 1; fi
        sudo -n rm -f '/Users/admin/reference'
        sudo -n ln -s '/Volumes/My Shared Files/sand-L1VzZXJzL2FkbWluL3JlZmVyZW5jZQ' '/Users/admin/reference'
        """
        let runner = ScriptedTartRunner(results: [
            ["--version"]: .success(.init(stdout: "2.32.1\n", stderr: "", exitCode: 0)),
            ["exec", "macbox", "/bin/zsh", "-lc", syntheticScript]: .success(.init(stdout: "SAND_SYNTHETIC_CHANGED\n", stderr: "", exitCode: 0)),
            ["stop", "macbox"]: .success(.init(stdout: "", stderr: "", exitCode: 0)),
            ["exec", "macbox", "/bin/zsh", "-lc", symlinkScript]: .success(.init(stdout: "", stderr: "", exitCode: 0))
        ])
        let backend = TartCLIBackend(runner: runner, sshRunner: ScriptedTartRunner(results: [:]), starter: starter, keyStore: StaticTartKeyStore(), sleeper: { _ in }, maxIPAttempts: 1)
        let spec = SandboxSpec(
            name: name,
            image: SandboxImage(reference: "ghcr.io/example/macos:latest"),
            guestOS: .macOS,
            sharedFolders: [
                SharedFolder(displayHostPath: "~/Projects/sand", resolvedHostPath: "/Users/onur/Projects/sand", guestPath: try GuestPath("/workspace/sand"), accessMode: .readWrite),
                SharedFolder(displayHostPath: "~/Reference", resolvedHostPath: "/Users/onur/Reference", guestPath: try GuestPath("/Users/admin/reference"), accessMode: .readOnly)
            ]
        )

        try backend.start(spec)

        XCTAssertEqual(starter.calls, [
            TartStartCall(arguments: ["run", "--no-graphics", "--dir", "sand-L3dvcmtzcGFjZS9zYW5k:/Users/onur/Projects/sand", "--dir", "sand-L1VzZXJzL2FkbWluL3JlZmVyZW5jZQ:/Users/onur/Reference:ro", "macbox"], logPath: "/tmp/macbox-start.log"),
            TartStartCall(arguments: ["run", "--no-graphics", "--dir", "sand-L3dvcmtzcGFjZS9zYW5k:/Users/onur/Projects/sand", "--dir", "sand-L1VzZXJzL2FkbWluL3JlZmVyZW5jZQ:/Users/onur/Reference:ro", "macbox"], logPath: "/tmp/macbox-start.log")
        ])
        XCTAssertEqual(runner.calls, [
            ["--version"],
            ["exec", "macbox", "/bin/zsh", "-lc", syntheticScript],
            ["stop", "macbox"],
            ["exec", "macbox", "/bin/zsh", "-lc", symlinkScript]
        ])
    }

    func testApplyRestartsRunningMacOSVMWithSharedFoldersWithoutDeletingDisk() throws {
        let name = try SandboxName("macbox")
        let starter = RecordingTartVMStarter()
        let syntheticScript = "set -e\nsudo -n mkdir -p /etc/synthetic.d\nmkdir -p '/Users/admin/.sand/synthetic/workspace'\ncurrent=$(cat /etc/synthetic.d/sand 2>/dev/null || true)\ndesired='workspace\tUsers/admin/.sand/synthetic/workspace\n'\nneeds_restart=0\nif [ \"$current\" != \"$desired\" ]; then printf '%s' \"$desired\" | sudo -n tee /etc/synthetic.d/sand >/dev/null; needs_restart=1; fi\nif [ ! -e '/workspace' ]; then needs_restart=1; fi\nif [ \"$needs_restart\" = 1 ]; then sync; echo SAND_SYNTHETIC_CHANGED; fi"
        let symlinkScript = """
        set -e
        sudo -n mkdir -p '/workspace'
        if [ -e '/workspace/sand' ] && [ ! -L '/workspace/sand' ]; then echo 'Guest Path exists and is not a symlink: /workspace/sand' >&2; exit 1; fi
        sudo -n rm -f '/workspace/sand'
        sudo -n ln -s '/Volumes/My Shared Files/sand-L3dvcmtzcGFjZS9zYW5k' '/workspace/sand'
        """
        let runner = ScriptedTartRunner(results: [
            ["list", "--format", "json"]: .success(.init(stdout: """
            [{"Name":"macbox","State":"running","Running":true}]
            """, stderr: "", exitCode: 0)),
            ["stop", "macbox"]: .success(.init(stdout: "", stderr: "", exitCode: 0)),
            ["--version"]: .success(.init(stdout: "2.32.1\n", stderr: "", exitCode: 0)),
            ["exec", "macbox", "/bin/zsh", "-lc", syntheticScript]: .success(.init(stdout: "SAND_SYNTHETIC_CHANGED\n", stderr: "", exitCode: 0)),
            ["exec", "macbox", "/bin/zsh", "-lc", symlinkScript]: .success(.init(stdout: "", stderr: "", exitCode: 0))
        ])
        let backend = TartCLIBackend(runner: runner, sshRunner: ScriptedTartRunner(results: [:]), starter: starter, keyStore: StaticTartKeyStore(), sleeper: { _ in }, maxIPAttempts: 1)
        let spec = SandboxSpec(
            name: name,
            image: SandboxImage(reference: "ghcr.io/example/macos:latest"),
            guestOS: .macOS,
            sharedFolders: [
                SharedFolder(displayHostPath: "~/Projects/sand", resolvedHostPath: "/Users/onur/Projects/sand", guestPath: try GuestPath("/workspace/sand"), accessMode: .readWrite)
            ]
        )

        try backend.apply(spec)

        XCTAssertEqual(runner.calls, [
            ["list", "--format", "json"],
            ["stop", "macbox"],
            ["--version"],
            ["exec", "macbox", "/bin/zsh", "-lc", syntheticScript],
            ["stop", "macbox"],
            ["exec", "macbox", "/bin/zsh", "-lc", symlinkScript]
        ])
        XCTAssertEqual(starter.calls, [
            TartStartCall(arguments: ["run", "--no-graphics", "--dir", "sand-L3dvcmtzcGFjZS9zYW5k:/Users/onur/Projects/sand", "macbox"], logPath: "/tmp/macbox-start.log"),
            TartStartCall(arguments: ["run", "--no-graphics", "--dir", "sand-L3dvcmtzcGFjZS9zYW5k:/Users/onur/Projects/sand", "macbox"], logPath: "/tmp/macbox-start.log")
        ])
    }

    func testRunUsesTartIPThenHiddenSSHWithInjectedPrivateKey() throws {
        let name = try SandboxName("macbox")
        let tartRunner = ScriptedTartRunner(results: [
            ["ip", "macbox"]: .success(.init(stdout: "192.168.65.2\n", stderr: "", exitCode: 0))
        ])
        let sshRunner = ScriptedTartRunner(results: [
            ["-i", "/tmp/macbox-id_ed25519", "-o", "BatchMode=yes", "-o", "PasswordAuthentication=no", "-o", "StrictHostKeyChecking=no", "-o", "UserKnownHostsFile=/dev/null", "-o", "ConnectTimeout=5", "admin@192.168.65.2", "true"]: .success(.init(stdout: "", stderr: "", exitCode: 0)),
            ["-i", "/tmp/macbox-id_ed25519", "-o", "BatchMode=yes", "-o", "PasswordAuthentication=no", "-o", "StrictHostKeyChecking=no", "-o", "UserKnownHostsFile=/dev/null", "-o", "ConnectTimeout=5", "admin@192.168.65.2", "cd '/workspace/project' && exec 'xcodebuild' '-scheme' 'App'"]: .success(.init(stdout: "", stderr: "", exitCode: 0))
        ])
        let backend = TartCLIBackend(runner: tartRunner, sshRunner: sshRunner, starter: RecordingTartVMStarter(), keyStore: StaticTartKeyStore(), sleeper: { _ in }, maxIPAttempts: 1)

        let result = try backend.run(BackendRunRequest(sandboxName: name, command: try WorkloadCommand(arguments: ["xcodebuild", "-scheme", "App"]), workingDirectory: try GuestPath("/workspace/project")))

        XCTAssertEqual(result, .success)
        XCTAssertEqual(tartRunner.calls, [["ip", "macbox"]])
        XCTAssertEqual(sshRunner.calls, [
            ["-i", "/tmp/macbox-id_ed25519", "-o", "BatchMode=yes", "-o", "PasswordAuthentication=no", "-o", "StrictHostKeyChecking=no", "-o", "UserKnownHostsFile=/dev/null", "-o", "ConnectTimeout=5", "admin@192.168.65.2", "true"],
            ["-i", "/tmp/macbox-id_ed25519", "-o", "BatchMode=yes", "-o", "PasswordAuthentication=no", "-o", "StrictHostKeyChecking=no", "-o", "UserKnownHostsFile=/dev/null", "-o", "ConnectTimeout=5", "admin@192.168.65.2", "cd '/workspace/project' && exec 'xcodebuild' '-scheme' 'App'"]
        ])
        XCTAssertEqual(sshRunner.ioModes, [.captured, .inherited])
    }

    func testStatusReadsOnlyTheRequestedVMFromActualTartJSON() throws {
        let runner = ScriptedTartRunner(results: [
            ["list", "--format", "json"]: .success(.init(stdout: """
            [
              {"Name":"other","State":"running","Running":true},
              {"Name":"macbox","State":"stopped","Running":false}
            ]
            """, stderr: "", exitCode: 0))
        ])
        let backend = TartCLIBackend(runner: runner, sshRunner: ScriptedTartRunner(results: [:]), starter: RecordingTartVMStarter(), keyStore: StaticTartKeyStore())

        XCTAssertEqual(try backend.status(try SandboxName("macbox")), .stopped)
    }

    func testMissingTartReadinessGivesActionableInstallMessage() throws {
        let runner = ScriptedTartRunner(results: [
            ["--version"]: .success(.init(stdout: "", stderr: "env: tart: No such file or directory", exitCode: 127))
        ])
        let backend = TartCLIBackend(runner: runner, sshRunner: ScriptedTartRunner(results: [:]), starter: RecordingTartVMStarter(), keyStore: StaticTartKeyStore())

        XCTAssertEqual(try backend.checkReadiness(), .notReady([
            DoctorFinding(kind: .backendExecutableMissing, message: "tart executable is not available. Install it with `brew install cirruslabs/cli/tart` and retry.")
        ]))
    }

    func testTartErrorTranslationUsesStderrFixtures() throws {
        let runner = ScriptedTartRunner(results: [
            ["--version"]: .success(.init(stdout: "2.32.1", stderr: "", exitCode: 0)),
            ["clone", "missing", "macbox"]: .success(.init(stdout: "", stderr: "pull failed: image not found", exitCode: 1))
        ])
        let backend = TartCLIBackend(runner: runner, sshRunner: ScriptedTartRunner(results: [:]), starter: RecordingTartVMStarter(), keyStore: StaticTartKeyStore())

        XCTAssertThrowsError(try backend.provision(SandboxSpec(name: try SandboxName("macbox"), image: SandboxImage(reference: "missing"), guestOS: .macOS))) { error in
            XCTAssertEqual(String(describing: error), "Could not clone the macOS Sandbox VM image. Check the image reference and run `sand logs macbox` for details.")
        }
    }
}

private final class ScriptedTartRunner: BackendCommandRunner {
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
        guard let result = results[arguments] else { throw UnexpectedTartCommand(arguments: arguments) }
        switch result {
        case .success(let output): return output
        case .failure(let error): throw error
        }
    }
}

private final class RecordingTartVMStarter: TartVMStarter {
    var calls: [TartStartCall] = []

    func start(arguments: [String], logPath: String) throws {
        calls.append(TartStartCall(arguments: arguments, logPath: logPath))
    }
}

private struct TartStartCall: Equatable {
    var arguments: [String]
    var logPath: String
}

private final class StaticTartKeyStore: TartSSHKeyStore {
    var created: [String] = []
    var deleted: [String] = []
    var logs: [String: String] = [:]

    func createKeyPair(for sandboxName: SandboxName) throws {
        created.append(sandboxName.rawValue)
    }

    func privateKeyPath(for sandboxName: SandboxName) throws -> String {
        "/tmp/\(sandboxName.rawValue)-id_ed25519"
    }

    func publicKey(for sandboxName: SandboxName) throws -> String {
        "ssh-ed25519 TEST sand-\(sandboxName.rawValue)\n"
    }

    func deleteKeyPair(for sandboxName: SandboxName) throws {
        deleted.append(sandboxName.rawValue)
    }

    func logPath(for sandboxName: SandboxName, kind: String) throws -> String {
        "/tmp/\(sandboxName.rawValue)-\(kind).log"
    }

    func readLog(for sandboxName: SandboxName, kind: String) throws -> String {
        logs["\(sandboxName.rawValue):\(kind)"] ?? ""
    }

    func writeLog(_ text: String, for sandboxName: SandboxName, kind: String) throws {
        logs["\(sandboxName.rawValue):\(kind)"] = text
    }
}

private struct UnexpectedTartCommand: Error, Equatable {
    var arguments: [String]
}
