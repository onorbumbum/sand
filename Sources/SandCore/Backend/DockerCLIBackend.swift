import Foundation

/// Backend implementation using a Docker-compatible CLI.
///
/// Lets Linux Sandbox VMs run where Apple `container` cannot (Intel Macs,
/// macOS before 26), typically with colima providing the Linux VM. The guest
/// contract matches `AppleContainerCLIBackend`: same image, Guest State volume,
/// Shared Folder mounts, sandbox user and main process.
public struct DockerCLIBackend: SandboxBackend {
    private let runner: any BackendCommandRunner
    private let translator: BackendErrorTranslator
    private let terminal: any BackendTerminal

    public init(
        runner: any BackendCommandRunner = ProcessBackendCommandRunner(executable: "docker"),
        translator: BackendErrorTranslator = BackendErrorTranslator(),
        terminal: any BackendTerminal = ProcessBackendTerminal()
    ) {
        self.runner = runner
        self.translator = translator
        self.terminal = terminal
    }

    public func checkReadiness() throws -> BackendReadiness {
        guard commandSucceeds(["--version"]) else {
            return .notReady([
                DoctorFinding(
                    kind: .backendExecutableMissing,
                    message: "Docker CLI is not available. Install it (for example `brew install docker colima`) and make sure it is on PATH."
                )
            ])
        }
        guard commandSucceeds(["info", "--format", "{{.ServerVersion}}"]) else {
            return .notReady([
                DoctorFinding(
                    kind: .backendServiceStopped,
                    message: "Docker daemon is not reachable. Start it (for example `colima start --cpu 4 --memory 4`), then retry `sand doctor`."
                )
            ])
        }
        guard commandSucceeds(["image", "inspect", SandboxImage.developerReadyDefault.reference]) else {
            return .notReady([
                DoctorFinding(
                    kind: .defaultImageMissing,
                    message: "Default Sandbox Image \(SandboxImage.developerReadyDefault.reference) is not available. Build it with scripts/build-developer-ready-image.sh before creating Sandbox VMs."
                )
            ])
        }
        return .ready
    }

    public func provision(_ spec: SandboxSpec) throws {
        try ensureGuestStateVolume(for: spec.name)
        _ = try runRequired(arguments: createArguments(for: spec))
    }

    public func apply(_ spec: SandboxSpec) throws {
        let currentStatus = try status(spec.name)
        if currentStatus == .running {
            try stop(spec.name)
        }
        if currentStatus != .missing {
            _ = try runRequired(arguments: ["rm", "--force", spec.name.rawValue])
        }
        try provision(spec)
        if currentStatus == .running {
            try start(spec)
        }
    }

    public func start(_ spec: SandboxSpec) throws {
        _ = try runRequired(arguments: ["start", spec.name.rawValue])
    }

    public func stop(_ sandboxName: SandboxName) throws {
        _ = try runRequired(arguments: ["stop", sandboxName.rawValue])
    }

    public func run(_ request: BackendRunRequest) throws -> CommandResult {
        try exec(sandboxName: request.sandboxName, workingDirectory: request.workingDirectory, command: request.command.arguments)
    }

    public func shell(_ request: BackendShellRequest) throws -> CommandResult {
        try exec(sandboxName: request.sandboxName, workingDirectory: request.workingDirectory, command: ["/bin/bash"])
    }

    public func gui(_ request: BackendGUIRequest) throws -> CommandResult {
        throw SandboxGUIError.unsupportedGuestOS(request.spec.guestOS.rawValue)
    }

    public func installSigningCredentials(_ request: BackendSigningCredentialsRequest) throws -> CommandResult {
        throw SandboxSigningError.unsupportedGuestOS(GuestOS.linux.rawValue)
    }

    public func status(_ sandboxName: SandboxName) throws -> SandboxRuntimeStatus {
        let output = try runner.run(arguments: ["container", "inspect", "--format", "{{.State.Status}}", sandboxName.rawValue])
        if output.exitCode != 0 {
            if output.stderr.lowercased().contains("no such") { return .missing }
            throw translator.translate(DockerCLIBackendError.commandFailed(arguments: ["container", "inspect", sandboxName.rawValue], exitCode: output.exitCode, stderr: output.stderr))
        }
        return output.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == "running" ? .running : .stopped
    }

    public func logs(_ sandboxName: SandboxName) throws -> SandboxLogs {
        let output = try runRequired(arguments: ["logs", sandboxName.rawValue])
        return SandboxLogs(text: output.stdout + output.stderr)
    }

    public func delete(_ sandboxName: SandboxName) throws {
        if try status(sandboxName) != .missing {
            _ = try runRequired(arguments: ["rm", "--force", sandboxName.rawValue])
        }
        let volume = LinuxGuestRuntime.guestStateVolumeName(for: sandboxName)
        if commandSucceeds(["volume", "inspect", volume]) {
            _ = try runRequired(arguments: ["volume", "rm", volume])
        }
    }

    private func exec(sandboxName: SandboxName, workingDirectory: GuestPath, command: [String]) throws -> CommandResult {
        var arguments = ["exec", "--interactive"]
        if terminal.standardInputIsTerminal && terminal.standardOutputIsTerminal {
            arguments.append("--tty")
        }
        arguments += ["--user", "sandbox", "--workdir", workingDirectory.rawValue, sandboxName.rawValue]
        arguments += command
        let output = try runner.run(arguments: arguments, io: .inherited)
        return output.exitCode == 0 ? .success : .failure(exitCode: output.exitCode)
    }

    private func createArguments(for spec: SandboxSpec) -> [String] {
        var arguments = [
            "create",
            "--name", spec.name.rawValue,
            "--hostname", spec.name.rawValue,
            "--cpus", String(spec.resourceProfile.cpus),
            "--memory", "\(spec.resourceProfile.memory.megabytes)M",
            "--volume", "\(LinuxGuestRuntime.guestStateVolumeName(for: spec.name)):/state"
        ]
        for folder in spec.sharedFolders {
            arguments += ["--mount", LinuxGuestRuntime.mountArgument(for: folder)]
        }
        arguments += LinuxGuestRuntime.browserPublishArguments(for: spec)
        if spec.browser != nil {
            // Docker's 64 MB default /dev/shm crashes Chromium tabs.
            arguments += ["--shm-size", "1g"]
        }
        arguments.append(spec.image.reference)
        arguments += LinuxGuestRuntime.mainCommand(for: spec)
        return arguments
    }

    private func ensureGuestStateVolume(for sandboxName: SandboxName) throws {
        let volume = LinuxGuestRuntime.guestStateVolumeName(for: sandboxName)
        guard !commandSucceeds(["volume", "inspect", volume]) else { return }
        _ = try runRequired(arguments: ["volume", "create", volume])
    }

    private func commandSucceeds(_ arguments: [String]) -> Bool {
        (try? runner.run(arguments: arguments).exitCode == 0) ?? false
    }

    private func runRequired(arguments: [String]) throws -> BackendCommandOutput {
        do {
            let output = try runner.run(arguments: arguments)
            guard output.exitCode == 0 else {
                throw translator.translate(DockerCLIBackendError.commandFailed(arguments: arguments, exitCode: output.exitCode, stderr: output.stderr))
            }
            return output
        } catch let error as BackendTranslatedError {
            throw error
        } catch {
            throw translator.translate(error)
        }
    }
}

/// Errors from the Docker CLI backend.
public enum DockerCLIBackendError: Error, Equatable, CustomStringConvertible {
    case commandFailed(arguments: [String], exitCode: Int, stderr: String)

    public var description: String {
        switch self {
        case .commandFailed(let arguments, let exitCode, let stderr):
            let detail = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            return "docker command failed (exit \(exitCode)): \(arguments.joined(separator: " "))\(detail.isEmpty ? "" : " — \(detail)")"
        }
    }
}
