import Darwin
import Foundation

/// Backend implementation using Apple's container CLI.
///
/// Interfaces with the container CLI for VM lifecycle operations.
public struct AppleContainerCLIBackend: SandboxBackend {
    private let runner: any BackendCommandRunner
    private let translator: BackendErrorTranslator
    private let terminal: any BackendTerminal

    public init(
        runner: any BackendCommandRunner = ProcessBackendCommandRunner(executable: "container"),
        translator: BackendErrorTranslator = BackendErrorTranslator(),
        terminal: any BackendTerminal = ProcessBackendTerminal()
    ) {
        self.runner = runner
        self.translator = translator
        self.terminal = terminal
    }

    /// Checks if the backend is ready to create and manage VMs.
    public func checkReadiness() throws -> BackendReadiness {
        var findings: [DoctorFinding] = []

        guard commandSucceeds(["--version"]) else {
            return .notReady([
                DoctorFinding(
                    kind: .backendExecutableMissing,
                    message: "Apple container executable is not available. Install Apple's container CLI and make sure it is on PATH before creating Sandbox VMs."
                )
            ])
        }

        if !backendServiceIsRunning() {
            _ = commandSucceeds(["system", "start"])
            if !backendServiceIsRunning() {
                findings.append(
                    DoctorFinding(
                        kind: .backendServiceStopped,
                        message: "Backend Service is not running and sand could not auto-start it. Check the backend service, then retry `sand doctor`."
                    )
                )
                return .notReady(findings)
            }
        }

        if !commandSucceeds(["image", "inspect", SandboxImage.developerReadyDefault.reference]) {
            findings.append(
                DoctorFinding(
                    kind: .defaultImageMissing,
                    message: "Default Sandbox Image \(SandboxImage.developerReadyDefault.reference) is not available. Build it with scripts/build-developer-ready-image.sh before creating Sandbox VMs."
                )
            )
        }

        return findings.isEmpty ? .ready : .notReady(findings)
    }

    private func commandSucceeds(_ arguments: [String]) -> Bool {
        do {
            return try runner.run(arguments: arguments).exitCode == 0
        } catch {
            return false
        }
    }

    // Parses the output of `container system status` to check if the service is running.
    private func backendServiceIsRunning() -> Bool {
        do {
            let output = try runner.run(arguments: ["system", "status"])
            guard output.exitCode == 0 else { return false }
            for line in output.stdout.split(separator: "\n") {
                let fields = line.split(whereSeparator: { character in
                    character == " " || character == "\t"
                })
                if fields.first == "status" && fields.last == "running" {
                    return true
                }
            }
            return false
        } catch {
            return false
        }
    }

    /// Provisions a new sandbox VM from the given spec.
    public func provision(_ spec: SandboxSpec) throws {
        try ensureGuestStateVolume(for: spec.name)
        try createRuntime(from: spec)
    }

    /// Applies changes to an existing sandbox VM.
    ///
    /// Stops the VM if running, deletes the old runtime, creates a new one,
    /// then restarts if it was previously running.
    public func apply(_ spec: SandboxSpec) throws {
        let currentStatus = try status(spec.name)
        if currentStatus == .running {
            try stop(spec.name)
        }
        if currentStatus != .missing {
            try deleteRuntime(spec.name)
        }
        try ensureGuestStateVolume(for: spec.name)
        try createRuntime(from: spec)
        if currentStatus == .running {
            try start(spec.name)
        }
    }

    /// Starts a stopped sandbox VM.
    public func start(_ sandboxName: SandboxName) throws {
        _ = try runRequired(arguments: ["start", sandboxName.rawValue])
    }

    /// Stops a running sandbox VM.
    public func stop(_ sandboxName: SandboxName) throws {
        _ = try runRequired(arguments: ["stop", sandboxName.rawValue])
    }

    /// Runs a command in the sandbox VM.
    public func run(_ request: BackendRunRequest) throws -> CommandResult {
        let output = try runner.run(
            arguments: execArguments(
                sandboxName: request.sandboxName,
                workingDirectory: request.workingDirectory,
                command: request.command.arguments
            ),
            io: .inherited
        )
        return output.exitCode == 0 ? .success : .failure(exitCode: output.exitCode)
    }

    /// Opens an interactive shell in the sandbox VM.
    public func shell(_ request: BackendShellRequest) throws -> CommandResult {
        let output = try runner.run(
            arguments: execArguments(
                sandboxName: request.sandboxName,
                workingDirectory: request.workingDirectory,
                command: ["/bin/bash"]
            ),
            io: .inherited
        )
        return output.exitCode == 0 ? .success : .failure(exitCode: output.exitCode)
    }

    // Builds exec arguments, adding --tty if stdin/stdout are terminals.
    private func execArguments(sandboxName: SandboxName, workingDirectory: GuestPath, command: [String]) -> [String] {
        var arguments = ["exec", "--interactive"]
        if terminal.standardInputIsTerminal && terminal.standardOutputIsTerminal {
            arguments.append("--tty")
        }
        arguments += ["--user", "sandbox", "--workdir", workingDirectory.rawValue, sandboxName.rawValue]
        arguments += command
        return arguments
    }

    /// Returns the current runtime status of the sandbox VM.
    public func status(_ sandboxName: SandboxName) throws -> SandboxRuntimeStatus {
        let output = try runRequired(arguments: ["inspect", sandboxName.rawValue])
        let text = output.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        if text == "[]" { return .missing }
        if text.contains("\"status\":\"running\"") || text.contains("\"status\" : \"running\"") {
            return .running
        }
        return .stopped
    }

    /// Returns the logs from the sandbox VM.
    public func logs(_ sandboxName: SandboxName) throws -> SandboxLogs {
        let output = try runRequired(arguments: ["logs", sandboxName.rawValue])
        return SandboxLogs(text: output.stdout)
    }

    /// Deletes the sandbox VM and its associated resources.
    public func delete(_ sandboxName: SandboxName) throws {
        if try status(sandboxName) != .missing {
            try deleteRuntime(sandboxName)
        }
        if try guestStateVolumeExists(for: sandboxName) {
            _ = try runRequired(arguments: ["volume", "delete", guestStateVolumeName(for: sandboxName)])
        }
    }

    // Checks if the state volume exists by inspecting it and handling "not found" errors.
    private func guestStateVolumeExists(for sandboxName: SandboxName) throws -> Bool {
        let arguments = ["volume", "inspect", guestStateVolumeName(for: sandboxName)]
        do {
            let output = try runner.run(arguments: arguments)
            let detail = "\(output.stdout)\n\(output.stderr)".lowercased()
            if detail.contains("not found") || detail.contains("no such") {
                return false
            }
            guard output.exitCode == 0 else {
                throw translator.translate(AppleContainerCLIBackendError.commandFailed(arguments: arguments, exitCode: output.exitCode, stderr: output.stderr))
            }
            return true
        } catch let error as BackendTranslatedError {
            throw error
        } catch {
            throw translator.translate(error)
        }
    }

    private func ensureGuestStateVolume(for sandboxName: SandboxName) throws {
        guard !commandSucceeds(["volume", "inspect", guestStateVolumeName(for: sandboxName)]) else { return }
        _ = try runRequired(arguments: ["volume", "create", guestStateVolumeName(for: sandboxName)])
    }

    private func createRuntime(from spec: SandboxSpec) throws {
        _ = try runRequired(arguments: createArguments(for: spec))
    }

    private func deleteRuntime(_ sandboxName: SandboxName) throws {
        _ = try runRequired(arguments: ["delete", "--force", sandboxName.rawValue])
    }

    // Builds the arguments for `container create`, including volume mounts for shared folders.
    private func createArguments(for spec: SandboxSpec) -> [String] {
        var arguments = [
            "create",
            "--name", spec.name.rawValue,
            "--cpus", String(spec.resourceProfile.cpus),
            "--memory", "\(spec.resourceProfile.memory.megabytes)M",
            "--volume", "\(guestStateVolumeName(for: spec.name)):/state"
        ]
        for folder in spec.sharedFolders {
            arguments += ["--mount", mountArgument(for: folder)]
        }
        arguments.append(spec.image.reference)
        arguments += guestStateBootstrapCommand()
        return arguments
    }

    private func guestStateBootstrapCommand() -> [String] {
        [
            "/bin/bash",
            "-lc",
            "sudo -n mkdir -p /state/sandbox/.pi /state/sandbox/secrets && sudo -n chown -R sandbox:sandbox /state/sandbox && exec sleep infinity"
        ]
    }

    private func mountArgument(for folder: SharedFolder) -> String {
        var argument = "type=bind,source=\(folder.resolvedHostPath),target=\(folder.guestPath.rawValue)"
        if folder.accessMode == .readOnly {
            argument += ",readonly"
        }
        return argument
    }

    private func guestStateVolumeName(for sandboxName: SandboxName) -> String {
        "sand-state-\(sandboxName.rawValue)"
    }

    // Runs a command and translates errors to user-friendly messages.
    private func runRequired(arguments: [String]) throws -> BackendCommandOutput {
        do {
            let output = try runner.run(arguments: arguments)
            guard output.exitCode == 0 else {
                let rawError = AppleContainerCLIBackendError.commandFailed(arguments: arguments, exitCode: output.exitCode, stderr: output.stderr)
                throw translator.translate(rawError)
            }
            return output
        } catch let error as BackendTranslatedError {
            throw error
        } catch {
            throw translator.translate(error)
        }
    }
}

/// Errors from the Apple container CLI backend.
public enum AppleContainerCLIBackendError: Error, Equatable, CustomStringConvertible {
    case commandFailed(arguments: [String], exitCode: Int, stderr: String)

    public var description: String {
        switch self {
        case .commandFailed(let arguments, let exitCode, let stderr):
            let detail = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            return "backend command failed (exit \(exitCode)): \(arguments.joined(separator: " "))\(detail.isEmpty ? "" : " — \(detail)")"
        }
    }
}

/// I/O mode for backend command execution.
public enum BackendCommandIO: Equatable {
    case captured
    case inherited
}

/// Runs backend commands as processes.
public protocol BackendCommandRunner {
    func run(arguments: [String], io: BackendCommandIO) throws -> BackendCommandOutput
}

public extension BackendCommandRunner {
    func run(arguments: [String]) throws -> BackendCommandOutput {
        try run(arguments: arguments, io: .captured)
    }
}

/// Checks whether stdin/stdout are connected to a terminal.
public protocol BackendTerminal {
    var standardInputIsTerminal: Bool { get }
    var standardOutputIsTerminal: Bool { get }
}

/// Terminal detection using isatty.
public struct ProcessBackendTerminal: BackendTerminal {
    public init() {}

    public var standardInputIsTerminal: Bool {
        isatty(STDIN_FILENO) == 1
    }

    public var standardOutputIsTerminal: Bool {
        isatty(STDOUT_FILENO) == 1
    }
}

/// Output from a backend command.
public struct BackendCommandOutput: Equatable {
    public var stdout: String
    public var stderr: String
    public var exitCode: Int

    public init(stdout: String, stderr: String, exitCode: Int) {
        self.stdout = stdout
        self.stderr = stderr
        self.exitCode = exitCode
    }
}

/// Runs backend commands using /usr/bin/env.
public struct ProcessBackendCommandRunner: BackendCommandRunner {
    private let executable: String

    public init(executable: String) {
        self.executable = executable
    }

    public func run(arguments: [String], io: BackendCommandIO) throws -> BackendCommandOutput {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [executable] + arguments

        switch io {
        case .captured:
            let standardOutput = Pipe()
            let standardError = Pipe()
            process.standardOutput = standardOutput
            process.standardError = standardError

            try process.run()
            process.waitUntilExit()

            let stdout = String(data: standardOutput.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            let stderr = String(data: standardError.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            return BackendCommandOutput(stdout: stdout, stderr: stderr, exitCode: Int(process.terminationStatus))
        case .inherited:
            // Interactive Apple `container exec --tty` needs to own the controlling
            // terminal. A Foundation Process child can print the guest prompt, but
            // keystrokes sent to the terminal do not reliably reach the guest shell.
            // Replace `sand` with the backend command for inherited-IO sessions so
            // stdin/stdout/stderr and terminal control are exactly the user's shell.
            try execReplacingCurrentProcess(arguments: [executable] + arguments)
        }
    }

    private func execReplacingCurrentProcess(arguments: [String]) throws -> Never {
        let cArguments = arguments.map { strdup($0) }
        defer {
            for argument in cArguments {
                free(argument)
            }
        }

        var argv = cArguments + [nil]
        execvp(cArguments[0], &argv)
        throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
    }
}
