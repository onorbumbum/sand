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
            ["set", "macbox", "--cpu", "4", "--memory", "16384", "--disk-size", "64"]: .success(.init(stdout: "", stderr: "", exitCode: 0)),
            ["ip", "macbox"]: .success(.init(stdout: "192.168.65.2\n", stderr: "", exitCode: 0)),
            ["exec", "macbox", "/bin/zsh", "-lc", "mkdir -p ~/.ssh && chmod 700 ~/.ssh && grep -qxF 'ssh-ed25519 TEST sand-macbox' ~/.ssh/authorized_keys 2>/dev/null || printf '%s\\n' 'ssh-ed25519 TEST sand-macbox' >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && sync"]: .success(.init(stdout: "", stderr: "", exitCode: 0)),
            ["stop", "macbox", "--timeout", "120"]: .success(.init(stdout: "", stderr: "", exitCode: 0))
        ])
        let backend = TartCLIBackend(runner: runner, sshRunner: ScriptedTartRunner(results: [:]), starter: starter, keyStore: keyStore, sleeper: { _ in }, maxIPAttempts: 1)

        try backend.provision(SandboxSpec(name: name, image: SandboxImage(reference: "ghcr.io/example/macos:latest"), guestOS: .macOS))

        XCTAssertEqual(runner.calls, [
            ["--version"],
            ["clone", "ghcr.io/example/macos:latest", "macbox"],
            ["set", "macbox", "--cpu", "4", "--memory", "16384", "--disk-size", "64"],
            ["ip", "macbox"],
            ["exec", "macbox", "/bin/zsh", "-lc", "mkdir -p ~/.ssh && chmod 700 ~/.ssh && grep -qxF 'ssh-ed25519 TEST sand-macbox' ~/.ssh/authorized_keys 2>/dev/null || printf '%s\\n' 'ssh-ed25519 TEST sand-macbox' >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && sync"],
            ["stop", "macbox", "--timeout", "120"]
        ])
        XCTAssertEqual(starter.calls, [TartStartCall(arguments: ["run", "--no-graphics", "--root-disk-opts", "sync=full", "macbox"], logPath: "/tmp/macbox-start.log")])
        XCTAssertEqual(keyStore.created, ["macbox"])
        XCTAssertTrue(keyStore.logs["macbox:clone"]?.contains("cloned") == true)
    }

    func testProvisionCanCloneFromLocalSandboxAndGrowDisk() throws {
        let name = try SandboxName("workbox")
        let runner = ScriptedTartRunner(results: [
            ["--version"]: .success(.init(stdout: "2.32.1\n", stderr: "", exitCode: 0)),
            ["clone", "cleanbox", "workbox"]: .success(.init(stdout: "cloned\n", stderr: "", exitCode: 0)),
            ["set", "workbox", "--cpu", "4", "--memory", "16384", "--disk-size", "150"]: .success(.init(stdout: "", stderr: "", exitCode: 0)),
            ["ip", "workbox"]: .success(.init(stdout: "192.168.65.2\n", stderr: "", exitCode: 0)),
            ["exec", "workbox", "/bin/zsh", "-lc", "mkdir -p ~/.ssh && chmod 700 ~/.ssh && grep -qxF 'ssh-ed25519 TEST sand-workbox' ~/.ssh/authorized_keys 2>/dev/null || printf '%s\\n' 'ssh-ed25519 TEST sand-workbox' >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && sync"]: .success(.init(stdout: "", stderr: "", exitCode: 0)),
            ["stop", "workbox", "--timeout", "120"]: .success(.init(stdout: "", stderr: "", exitCode: 0))
        ])
        let backend = TartCLIBackend(runner: runner, sshRunner: ScriptedTartRunner(results: [:]), starter: RecordingTartVMStarter(), keyStore: StaticTartKeyStore(), sleeper: { _ in }, maxIPAttempts: 1)

        try backend.provision(SandboxSpec(name: name, image: SandboxImage(reference: "cleanbox"), guestOS: .macOS, diskSize: DiskSize(gigabytes: 150)))

        XCTAssertEqual(runner.calls.prefix(3), [
            ["--version"],
            ["clone", "cleanbox", "workbox"],
            ["set", "workbox", "--cpu", "4", "--memory", "16384", "--disk-size", "150"]
        ])
    }

    func testProvisionFromIPSWCreatesVMSetsResourcesAndLeavesSetupRequiredWithoutCloneStartOrKey() throws {
        let name = try SandboxName("ipswbox")
        let keyStore = StaticTartKeyStore()
        let starter = RecordingTartVMStarter()
        let runner = ScriptedTartRunner(results: [
            ["--version"]: .success(.init(stdout: "2.32.1\n", stderr: "", exitCode: 0)),
            ["create", "ipswbox", "--from-ipsw", "latest"]: .success(.init(stdout: "created\n", stderr: "", exitCode: 0)),
            ["set", "ipswbox", "--cpu", "4", "--memory", "16384", "--disk-size", "64"]: .success(.init(stdout: "", stderr: "", exitCode: 0))
        ])
        let backend = TartCLIBackend(runner: runner, sshRunner: ScriptedTartRunner(results: [:]), starter: starter, keyStore: keyStore, sleeper: { _ in }, maxIPAttempts: 1)

        try backend.provisionFromIPSW(SandboxSpec(name: name, image: SandboxImage(reference: "ipsw:latest"), guestOS: .macOS, bootstrapState: .setupRequired), ipswSource: "latest")

        XCTAssertEqual(runner.calls, [
            ["--version"],
            ["create", "ipswbox", "--from-ipsw", "latest"],
            ["set", "ipswbox", "--cpu", "4", "--memory", "16384", "--disk-size", "64"]
        ])
        XCTAssertEqual(starter.calls, [])
        XCTAssertEqual(keyStore.created, ["ipswbox"])
        XCTAssertTrue(keyStore.logs["ipswbox:create"]?.contains("created") == true)
    }

    func testBootstrapInjectsKeyOverSSHPasswordAuthThenVerifiesWithKeyAndStops() throws {
        let name = try SandboxName("ipswbox")
        let injectScript = "mkdir -p ~/.ssh && chmod 700 ~/.ssh && grep -qxF 'ssh-ed25519 TEST sand-ipswbox' ~/.ssh/authorized_keys 2>/dev/null || printf '%s\\n' 'ssh-ed25519 TEST sand-ipswbox' >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && sync"
        let keyPrefix = ["-i", "/tmp/ipswbox-id_ed25519", "-o", "BatchMode=yes", "-o", "PasswordAuthentication=no", "-o", "StrictHostKeyChecking=no", "-o", "UserKnownHostsFile=/dev/null", "-o", "ConnectTimeout=5", "admin@192.168.65.2"]
        let keyReady = keyPrefix + ["printf SAND_SSH_READY"]
        let starter = RecordingTartVMStarter()
        let runner = ScriptedTartRunner(results: [
            ["--version"]: .success(.init(stdout: "2.32.1\n", stderr: "", exitCode: 0)),
            ["list", "--format", "json"]: .success(.init(stdout: "[{\"Name\":\"ipswbox\",\"State\":\"running\",\"Running\":true}]", stderr: "", exitCode: 0)),
            ["ip", "ipswbox"]: .success(.init(stdout: "192.168.65.2\n", stderr: "", exitCode: 0)),
            ["stop", "ipswbox", "--timeout", "120"]: .success(.init(stdout: "", stderr: "", exitCode: 0))
        ])
        let sshRunner = ScriptedTartRunner(results: [
            (keyPrefix + ["true"]): .success(.init(stdout: "", stderr: "", exitCode: 0)),
            (keyPrefix + ["sudo -n true"]): .success(.init(stdout: "", stderr: "", exitCode: 0))
        ])
        let passwordSSHRunner = RecordingTartPasswordSSHRunner()
        let backend = TartCLIBackend(runner: runner, sshRunner: sshRunner, starter: starter, keyStore: StaticTartKeyStore(), passwordSSHRunner: passwordSSHRunner, sleeper: { _ in }, maxIPAttempts: 1)

        try backend.bootstrap(SandboxSpec(name: name, image: SandboxImage(reference: "ipsw:latest"), guestOS: .macOS, bootstrapState: .setupRequired))

        XCTAssertEqual(runner.calls, [
            ["--version"],
            ["list", "--format", "json"],
            ["ip", "ipswbox"],
            ["stop", "ipswbox", "--timeout", "120"]
        ])
        XCTAssertEqual(passwordSSHRunner.calls, [TartPasswordSSHCall(ipAddress: "192.168.65.2", remoteCommand: injectScript)])
        XCTAssertEqual(sshRunner.calls, [keyReady, keyPrefix + ["true"], keyPrefix + ["sudo -n true"]])
        XCTAssertEqual(sshRunner.ioModes, [.captured, .captured, .captured])
        XCTAssertEqual(starter.calls, [])
    }

    func testBootstrapConfiguresSharedFoldersOverKeyBasedSSH() throws {
        let name = try SandboxName("ipswbox")
        let injectScript = "mkdir -p ~/.ssh && chmod 700 ~/.ssh && grep -qxF 'ssh-ed25519 TEST sand-ipswbox' ~/.ssh/authorized_keys 2>/dev/null || printf '%s\\n' 'ssh-ed25519 TEST sand-ipswbox' >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && sync"
        let keyPrefix = ["-i", "/tmp/ipswbox-id_ed25519", "-o", "BatchMode=yes", "-o", "PasswordAuthentication=no", "-o", "StrictHostKeyChecking=no", "-o", "UserKnownHostsFile=/dev/null", "-o", "ConnectTimeout=5", "admin@192.168.65.2"]
        let keyReady = keyPrefix + ["printf SAND_SSH_READY"]
        let symlinkScript = """
        set -e
        sudo -n mkdir -p '/workspace'
        if [ -e '/workspace/sand' ] && [ ! -L '/workspace/sand' ]; then echo 'Guest Path exists and is not a symlink: /workspace/sand' >&2; exit 1; fi
        sudo -n rm -f '/workspace/sand'
        sudo -n ln -s '/Volumes/My Shared Files/sand-L3dvcmtzcGFjZS9zYW5k' '/workspace/sand'
        """
        let runner = ScriptedTartRunner(results: [
            ["--version"]: .success(.init(stdout: "2.32.1\n", stderr: "", exitCode: 0)),
            ["list", "--format", "json"]: .success(.init(stdout: "[{\"Name\":\"ipswbox\",\"State\":\"running\",\"Running\":true}]", stderr: "", exitCode: 0)),
            ["ip", "ipswbox"]: .success(.init(stdout: "192.168.65.2\n", stderr: "", exitCode: 0)),
            ["stop", "ipswbox", "--timeout", "120"]: .success(.init(stdout: "", stderr: "", exitCode: 0))
        ])
        let sshRunner = ScriptedTartRunner(results: [
            (keyPrefix + ["true"]): .success(.init(stdout: "", stderr: "", exitCode: 0)),
            (keyPrefix + ["sudo -n true"]): .success(.init(stdout: "", stderr: "", exitCode: 0)),
            (keyPrefix + [symlinkScript]): .success(.init(stdout: "", stderr: "", exitCode: 0))
        ])
        let passwordSSHRunner = RecordingTartPasswordSSHRunner()
        let backend = TartCLIBackend(runner: runner, sshRunner: sshRunner, starter: RecordingTartVMStarter(), keyStore: StaticTartKeyStore(), passwordSSHRunner: passwordSSHRunner, sleeper: { _ in }, maxIPAttempts: 1)
        let spec = SandboxSpec(
            name: name,
            image: SandboxImage(reference: "ipsw:latest"),
            guestOS: .macOS,
            bootstrapState: .setupRequired,
            sharedFolders: [
                SharedFolder(displayHostPath: "~/Projects/sand", resolvedHostPath: "/Users/onur/Projects/sand", guestPath: try GuestPath("/workspace/sand"), accessMode: .readWrite)
            ]
        )

        try backend.bootstrap(spec)

        XCTAssertEqual(passwordSSHRunner.calls, [TartPasswordSSHCall(ipAddress: "192.168.65.2", remoteCommand: injectScript)])
        XCTAssertEqual(sshRunner.calls, [keyReady, keyPrefix + ["true"], keyPrefix + ["sudo -n true"], keyPrefix + [symlinkScript]])
        XCTAssertFalse(runner.calls.contains { $0.first == "exec" })
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
            ["stop", "macbox", "--timeout", "120"]: .success(.init(stdout: "", stderr: "", exitCode: 0)),
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
            TartStartCall(arguments: ["run", "--no-graphics", "--root-disk-opts", "sync=full", "--dir", "sand-L3dvcmtzcGFjZS9zYW5k:/Users/onur/Projects/sand", "--dir", "sand-L1VzZXJzL2FkbWluL3JlZmVyZW5jZQ:/Users/onur/Reference:ro", "macbox"], logPath: "/tmp/macbox-start.log"),
            TartStartCall(arguments: ["run", "--no-graphics", "--root-disk-opts", "sync=full", "--dir", "sand-L3dvcmtzcGFjZS9zYW5k:/Users/onur/Projects/sand", "--dir", "sand-L1VzZXJzL2FkbWluL3JlZmVyZW5jZQ:/Users/onur/Reference:ro", "macbox"], logPath: "/tmp/macbox-start.log")
        ])
        XCTAssertEqual(runner.calls, [
            ["--version"],
            ["exec", "macbox", "/bin/zsh", "-lc", syntheticScript],
            ["stop", "macbox", "--timeout", "120"],
            ["exec", "macbox", "/bin/zsh", "-lc", symlinkScript]
        ])
    }

    func testStartMountsMacOSSharedFolderWhenGuestPathIsSyntheticRoot() throws {
        let name = try SandboxName("macbox")
        let starter = RecordingTartVMStarter()
        let syntheticScript = "set -e\nsudo -n mkdir -p /etc/synthetic.d\nmkdir -p '/Users/admin/.sand/synthetic/workspace'\ncurrent=$(cat /etc/synthetic.d/sand 2>/dev/null || true)\ndesired='workspace\tUsers/admin/.sand/synthetic/workspace\n'\nneeds_restart=0\nif [ \"$current\" != \"$desired\" ]; then printf '%s' \"$desired\" | sudo -n tee /etc/synthetic.d/sand >/dev/null; needs_restart=1; fi\nif [ ! -e '/workspace' ]; then needs_restart=1; fi\nif [ \"$needs_restart\" = 1 ]; then sync; echo SAND_SYNTHETIC_CHANGED; fi"
        let symlinkScript = """
        set -e
        sudo -n mkdir -p '/Users/admin/.sand/synthetic'
        if [ -e '/Users/admin/.sand/synthetic/workspace' ] && [ ! -L '/Users/admin/.sand/synthetic/workspace' ]; then sudo -n rm -rf '/Users/admin/.sand/synthetic/workspace'; fi
        sudo -n rm -f '/Users/admin/.sand/synthetic/workspace'
        sudo -n ln -s '/Volumes/My Shared Files/sand-L3dvcmtzcGFjZQ' '/Users/admin/.sand/synthetic/workspace'
        """
        let runner = ScriptedTartRunner(results: [
            ["--version"]: .success(.init(stdout: "2.32.1\n", stderr: "", exitCode: 0)),
            ["exec", "macbox", "/bin/zsh", "-lc", syntheticScript]: .success(.init(stdout: "SAND_SYNTHETIC_CHANGED\n", stderr: "", exitCode: 0)),
            ["stop", "macbox", "--timeout", "120"]: .success(.init(stdout: "", stderr: "", exitCode: 0)),
            ["exec", "macbox", "/bin/zsh", "-lc", symlinkScript]: .success(.init(stdout: "", stderr: "", exitCode: 0))
        ])
        let backend = TartCLIBackend(runner: runner, sshRunner: ScriptedTartRunner(results: [:]), starter: starter, keyStore: StaticTartKeyStore(), sleeper: { _ in }, maxIPAttempts: 1)
        let spec = SandboxSpec(
            name: name,
            image: SandboxImage(reference: "ghcr.io/example/macos:latest"),
            guestOS: .macOS,
            sharedFolders: [
                SharedFolder(displayHostPath: "~/Projects/sand", resolvedHostPath: "/Users/onur/Projects/sand", guestPath: try GuestPath("/workspace"), accessMode: .readWrite)
            ]
        )

        try backend.start(spec)

        XCTAssertEqual(starter.calls, [
            TartStartCall(arguments: ["run", "--no-graphics", "--root-disk-opts", "sync=full", "--dir", "sand-L3dvcmtzcGFjZQ:/Users/onur/Projects/sand", "macbox"], logPath: "/tmp/macbox-start.log"),
            TartStartCall(arguments: ["run", "--no-graphics", "--root-disk-opts", "sync=full", "--dir", "sand-L3dvcmtzcGFjZQ:/Users/onur/Projects/sand", "macbox"], logPath: "/tmp/macbox-start.log")
        ])
        XCTAssertEqual(runner.calls, [
            ["--version"],
            ["exec", "macbox", "/bin/zsh", "-lc", syntheticScript],
            ["stop", "macbox", "--timeout", "120"],
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
            ["stop", "macbox", "--timeout", "120"]: .success(.init(stdout: "", stderr: "", exitCode: 0)),
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
            ["stop", "macbox", "--timeout", "120"],
            ["--version"],
            ["exec", "macbox", "/bin/zsh", "-lc", syntheticScript],
            ["stop", "macbox", "--timeout", "120"],
            ["exec", "macbox", "/bin/zsh", "-lc", symlinkScript]
        ])
        XCTAssertEqual(starter.calls, [
            TartStartCall(arguments: ["run", "--no-graphics", "--root-disk-opts", "sync=full", "--dir", "sand-L3dvcmtzcGFjZS9zYW5k:/Users/onur/Projects/sand", "macbox"], logPath: "/tmp/macbox-start.log"),
            TartStartCall(arguments: ["run", "--no-graphics", "--root-disk-opts", "sync=full", "--dir", "sand-L3dvcmtzcGFjZS9zYW5k:/Users/onur/Projects/sand", "macbox"], logPath: "/tmp/macbox-start.log")
        ])
    }

    func testDeleteStopsDeletesMacOSVMAndRemovesInjectedKeyPair() throws {
        let name = try SandboxName("macbox")
        let keyStore = StaticTartKeyStore()
        let runner = ScriptedTartRunner(results: [
            ["list", "--format", "json"]: .success(.init(stdout: """
            [{"Name":"macbox","State":"running","Running":true}]
            """, stderr: "", exitCode: 0)),
            ["stop", "macbox", "--timeout", "120"]: .success(.init(stdout: "", stderr: "", exitCode: 0)),
            ["delete", "macbox"]: .success(.init(stdout: "", stderr: "", exitCode: 0))
        ])
        let backend = TartCLIBackend(runner: runner, sshRunner: ScriptedTartRunner(results: [:]), starter: RecordingTartVMStarter(), keyStore: keyStore)

        try backend.delete(name)

        XCTAssertEqual(runner.calls, [
            ["list", "--format", "json"],
            ["stop", "macbox", "--timeout", "120"],
            ["delete", "macbox"]
        ])
        XCTAssertEqual(keyStore.deleted, ["macbox"])
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

    func testShellAllocatesTTYForInteractiveMacOSShell() throws {
        let name = try SandboxName("macbox")
        let tartRunner = ScriptedTartRunner(results: [
            ["ip", "macbox"]: .success(.init(stdout: "192.168.65.2\n", stderr: "", exitCode: 0))
        ])
        let sshRunner = ScriptedTartRunner(results: [
            ["-i", "/tmp/macbox-id_ed25519", "-o", "BatchMode=yes", "-o", "PasswordAuthentication=no", "-o", "StrictHostKeyChecking=no", "-o", "UserKnownHostsFile=/dev/null", "-o", "ConnectTimeout=5", "admin@192.168.65.2", "true"]: .success(.init(stdout: "", stderr: "", exitCode: 0)),
            ["-tt", "-i", "/tmp/macbox-id_ed25519", "-o", "BatchMode=yes", "-o", "PasswordAuthentication=no", "-o", "StrictHostKeyChecking=no", "-o", "UserKnownHostsFile=/dev/null", "-o", "ConnectTimeout=5", "admin@192.168.65.2", "cd '/Users/admin' && exec /bin/zsh -l"]: .success(.init(stdout: "", stderr: "", exitCode: 0))
        ])
        let backend = TartCLIBackend(runner: tartRunner, sshRunner: sshRunner, starter: RecordingTartVMStarter(), keyStore: StaticTartKeyStore(), sleeper: { _ in }, maxIPAttempts: 1)

        let result = try backend.shell(BackendShellRequest(sandboxName: name, workingDirectory: try GuestPath("/Users/admin")))

        XCTAssertEqual(result, .success)
        XCTAssertEqual(sshRunner.calls, [
            ["-i", "/tmp/macbox-id_ed25519", "-o", "BatchMode=yes", "-o", "PasswordAuthentication=no", "-o", "StrictHostKeyChecking=no", "-o", "UserKnownHostsFile=/dev/null", "-o", "ConnectTimeout=5", "admin@192.168.65.2", "true"],
            ["-tt", "-i", "/tmp/macbox-id_ed25519", "-o", "BatchMode=yes", "-o", "PasswordAuthentication=no", "-o", "StrictHostKeyChecking=no", "-o", "UserKnownHostsFile=/dev/null", "-o", "ConnectTimeout=5", "admin@192.168.65.2", "cd '/Users/admin' && exec /bin/zsh -l"]
        ])
        XCTAssertEqual(sshRunner.ioModes, [.captured, .inherited])
    }

    func testGUIStartsTartVNCAndOpensHostScreenSharingAtVMAddress() throws {
        let name = try SandboxName("macbox")
        let starter = RecordingTartVMStarter()
        let screenSharing = RecordingTartScreenSharingOpener()
        let runner = ScriptedTartRunner(results: [
            ["ip", "macbox"]: .success(.init(stdout: "192.168.65.2\n", stderr: "", exitCode: 0))
        ])
        let backend = TartCLIBackend(runner: runner, sshRunner: ScriptedTartRunner(results: [:]), starter: starter, keyStore: StaticTartKeyStore(), screenSharing: screenSharing, sleeper: { _ in }, maxIPAttempts: 1)
        let spec = SandboxSpec(
            name: name,
            image: SandboxImage(reference: "ghcr.io/example/macos:latest"),
            guestOS: .macOS,
            sharedFolders: [
                SharedFolder(displayHostPath: "~/Projects/sand", resolvedHostPath: "/Users/onur/Projects/sand", guestPath: try GuestPath("/workspace/sand"), accessMode: .readWrite)
            ]
        )

        XCTAssertEqual(try backend.gui(BackendGUIRequest(spec: spec)), .success)

        XCTAssertEqual(starter.calls, [
            TartStartCall(arguments: ["run", "--vnc", "--root-disk-opts", "sync=full", "--dir", "sand-L3dvcmtzcGFjZS9zYW5k:/Users/onur/Projects/sand", "macbox"], logPath: "/tmp/macbox-gui.log")
        ])
        XCTAssertEqual(runner.calls, [["ip", "macbox"]])
        XCTAssertEqual(screenSharing.openedURLs, ["vnc://admin@192.168.65.2"])
    }

    func testGUIForSetupRequiredIPSWVMUsesTartBuiltInVNCWithoutGuestScreenSharing() throws {
        let name = try SandboxName("ipswbox")
        let starter = RecordingTartVMStarter()
        let screenSharing = RecordingTartScreenSharingOpener()
        let runner = ScriptedTartRunner(results: [:])
        let backend = TartCLIBackend(runner: runner, sshRunner: ScriptedTartRunner(results: [:]), starter: starter, keyStore: StaticTartKeyStore(), screenSharing: screenSharing, sleeper: { _ in }, maxIPAttempts: 1)
        let spec = SandboxSpec(name: name, image: SandboxImage(reference: "ipsw:latest"), guestOS: .macOS, bootstrapState: .setupRequired)

        XCTAssertEqual(try backend.gui(BackendGUIRequest(spec: spec)), .success)

        XCTAssertEqual(starter.calls, [
            TartStartCall(arguments: ["run", "--vnc-experimental", "--root-disk-opts", "sync=full", "ipswbox"], logPath: "/tmp/ipswbox-gui.log")
        ])
        XCTAssertEqual(runner.calls, [])
        XCTAssertEqual(screenSharing.openedURLs, [])
    }

    func testInstallSigningCredentialsInjectsP12AndProvisioningProfileIntoGuestKeychain() throws {
        let name = try SandboxName("macbox")
        let runner = PermissiveTartRunner()
        let backend = TartCLIBackend(runner: runner, sshRunner: ScriptedTartRunner(results: [:]), starter: RecordingTartVMStarter(), keyStore: StaticTartKeyStore(), sleeper: { _ in }, maxIPAttempts: 1)

        XCTAssertEqual(try backend.installSigningCredentials(BackendSigningCredentialsRequest(sandboxName: name, certificateP12: Data("CERT".utf8), certificatePassword: "cert-pass", provisioningProfile: Data("PROFILE".utf8), keychainName: "ci-signing", keychainPassword: "kc-pass")), .success)

        XCTAssertEqual(runner.calls.count, 1)
        XCTAssertEqual(Array(runner.calls[0].prefix(3)), ["exec", "macbox", "/bin/zsh"])
        XCTAssertEqual(runner.calls[0][3], "-lc")
        let script = runner.calls[0][4]
        XCTAssertTrue(script.contains("CERT_B64='Q0VSVA=='"))
        XCTAssertTrue(script.contains("PROFILE_B64='UFJPRklMRQ=='"))
        XCTAssertTrue(script.contains("/usr/bin/security create-keychain -p \"$KEYCHAIN_PASSWORD\" \"$KEYCHAIN_PATH\""))
        XCTAssertTrue(script.contains("/usr/bin/security import \"$WORKDIR/certificate.p12\" -k \"$KEYCHAIN_PATH\" -P \"$CERT_PASSWORD\""))
        XCTAssertTrue(script.contains("/usr/bin/security set-key-partition-list -S apple-tool:,apple:,codesign:"))
        XCTAssertTrue(script.contains("$HOME/Library/MobileDevice/Provisioning Profiles/$PROFILE_UUID.mobileprovision"))
        XCTAssertTrue(script.contains("SAND_SIGNING_CREDENTIALS_INSTALLED"))
        XCTAssertFalse(script.contains("login.keychain"))
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

private final class PermissiveTartRunner: BackendCommandRunner {
    var calls: [[String]] = []

    func run(arguments: [String], io: BackendCommandIO) throws -> BackendCommandOutput {
        calls.append(arguments)
        return BackendCommandOutput(stdout: "SAND_SIGNING_CREDENTIALS_INSTALLED TEST-UUID\n", stderr: "", exitCode: 0)
    }
}

private final class RecordingTartVMStarter: TartVMStarter {
    var calls: [TartStartCall] = []

    func start(arguments: [String], logPath: String) throws {
        calls.append(TartStartCall(arguments: arguments, logPath: logPath))
    }
}

private final class RecordingTartScreenSharingOpener: TartScreenSharingOpener {
    var openedURLs: [String] = []

    func open(url: String) throws {
        openedURLs.append(url)
    }
}

private final class RecordingTartPasswordSSHRunner: TartPasswordSSHRunner {
    var calls: [TartPasswordSSHCall] = []

    func run(ipAddress: String, remoteCommand: String) throws -> BackendCommandOutput {
        calls.append(TartPasswordSSHCall(ipAddress: ipAddress, remoteCommand: remoteCommand))
        return BackendCommandOutput(stdout: "", stderr: "", exitCode: 0)
    }
}

private struct TartPasswordSSHCall: Equatable {
    var ipAddress: String
    var remoteCommand: String
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
