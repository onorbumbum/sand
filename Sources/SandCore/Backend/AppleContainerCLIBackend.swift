import Darwin
import Foundation

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
                        message: "Backend Service is not running and sand could not auto-start it. Run `container system start` and retry `sand doctor`."
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

    public func provision(_ spec: SandboxSpec) throws {
        try ensureGuestStateVolume(for: spec.name)
        try createRuntime(from: spec)
    }

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

    public func start(_ sandboxName: SandboxName) throws {
        _ = try runRequired(arguments: ["start", sandboxName.rawValue])
    }

    public func stop(_ sandboxName: SandboxName) throws {
        _ = try runRequired(arguments: ["stop", sandboxName.rawValue])
    }

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

    private func execArguments(sandboxName: SandboxName, workingDirectory: GuestPath, command: [String]) -> [String] {
        var arguments = ["exec", "--interactive"]
        if terminal.standardInputIsTerminal && terminal.standardOutputIsTerminal {
            arguments.append("--tty")
        }
        arguments += ["--user", "sandbox", "--workdir", workingDirectory.rawValue, sandboxName.rawValue]
        arguments += command
        return arguments
    }

    public func status(_ sandboxName: SandboxName) throws -> SandboxRuntimeStatus {
        let output = try runRequired(arguments: ["inspect", sandboxName.rawValue])
        let text = output.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        if text == "[]" { return .missing }
        if text.contains("\"status\":\"running\"") || text.contains("\"status\" : \"running\"") {
            return .running
        }
        return .stopped
    }

    public func logs(_ sandboxName: SandboxName) throws -> SandboxLogs {
        let output = try runRequired(arguments: ["logs", sandboxName.rawValue])
        return SandboxLogs(text: output.stdout)
    }

    public func delete(_ sandboxName: SandboxName) throws {
        try deleteRuntime(sandboxName)
        _ = try runRequired(arguments: ["volume", "delete", guestStateVolumeName(for: sandboxName)])
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

    private func createArguments(for spec: SandboxSpec) -> [String] {
        var arguments = [
            "create",
            "--name", spec.name.rawValue,
            "--cpus", String(spec.resourceProfile.cpus),
            "--memory", "\(spec.resourceProfile.memory.megabytes)M",
            "--volume", "\(guestStateVolumeName(for: spec.name)):/state"
        ]
        for folder in spec.allowedFolders {
            arguments += ["--mount", mountArgument(for: folder)]
        }
        arguments += [spec.image.reference, "sleep", "infinity"]
        return arguments
    }

    private func mountArgument(for folder: AllowedFolder) -> String {
        var argument = "type=bind,source=\(folder.resolvedHostPath),target=\(folder.guestPath.rawValue)"
        if folder.accessMode == .readOnly {
            argument += ",readonly"
        }
        return argument
    }

    private func guestStateVolumeName(for sandboxName: SandboxName) -> String {
        "sand-state-\(sandboxName.rawValue)"
    }

    private func runRequired(arguments: [String]) throws -> BackendCommandOutput {
        let output = try runner.run(arguments: arguments)
        guard output.exitCode == 0 else {
            throw AppleContainerCLIBackendError.commandFailed(arguments: arguments, exitCode: output.exitCode, stderr: output.stderr)
        }
        return output
    }
}

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

public enum BackendCommandIO: Equatable {
    case captured
    case inherited
}

public protocol BackendCommandRunner {
    func run(arguments: [String], io: BackendCommandIO) throws -> BackendCommandOutput
}

public extension BackendCommandRunner {
    func run(arguments: [String]) throws -> BackendCommandOutput {
        try run(arguments: arguments, io: .captured)
    }
}

public protocol BackendTerminal {
    var standardInputIsTerminal: Bool { get }
    var standardOutputIsTerminal: Bool { get }
}

public struct ProcessBackendTerminal: BackendTerminal {
    public init() {}

    public var standardInputIsTerminal: Bool {
        isatty(STDIN_FILENO) == 1
    }

    public var standardOutputIsTerminal: Bool {
        isatty(STDOUT_FILENO) == 1
    }
}

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
