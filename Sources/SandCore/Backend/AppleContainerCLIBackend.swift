import Foundation

public struct AppleContainerCLIBackend: SandboxBackend {
    private let runner: any BackendCommandRunner
    private let translator: BackendErrorTranslator

    public init(
        runner: any BackendCommandRunner = ProcessBackendCommandRunner(executable: "container"),
        translator: BackendErrorTranslator = BackendErrorTranslator()
    ) {
        self.runner = runner
        self.translator = translator
    }

    public func checkReadiness() throws -> BackendReadiness {
        do {
            _ = try runner.run(arguments: ["--version"])
            return .ready
        } catch {
            return .notReady([DoctorFinding(kind: .backendExecutableMissing, message: translator.message(for: error))])
        }
    }

    public func provision(_ spec: SandboxSpec) throws {
        _ = try runner.run(arguments: ["create", spec.name.rawValue, spec.image.reference])
    }

    public func apply(_ spec: SandboxSpec) throws {
        _ = try runner.run(arguments: ["update", spec.name.rawValue])
    }

    public func start(_ sandboxName: SandboxName) throws {
        _ = try runner.run(arguments: ["start", sandboxName.rawValue])
    }

    public func stop(_ sandboxName: SandboxName) throws {
        _ = try runner.run(arguments: ["stop", sandboxName.rawValue])
    }

    public func run(_ request: BackendRunRequest) throws -> CommandResult {
        let output = try runner.run(arguments: ["exec", request.sandboxName.rawValue, "--workdir", request.workingDirectory.rawValue] + request.command.arguments)
        return output.exitCode == 0 ? .success : .failure(exitCode: output.exitCode)
    }

    public func shell(_ request: BackendShellRequest) throws -> CommandResult {
        let output = try runner.run(arguments: ["exec", request.sandboxName.rawValue, "--workdir", request.workingDirectory.rawValue, "/bin/bash"])
        return output.exitCode == 0 ? .success : .failure(exitCode: output.exitCode)
    }

    public func status(_ sandboxName: SandboxName) throws -> SandboxRuntimeStatus {
        let output = try runner.run(arguments: ["inspect", sandboxName.rawValue])
        return output.stdout.contains("running") ? .running : .stopped
    }

    public func logs(_ sandboxName: SandboxName) throws -> SandboxLogs {
        let output = try runner.run(arguments: ["logs", sandboxName.rawValue])
        return SandboxLogs(text: output.stdout)
    }

    public func delete(_ sandboxName: SandboxName) throws {
        _ = try runner.run(arguments: ["delete", sandboxName.rawValue])
    }
}

public protocol BackendCommandRunner {
    func run(arguments: [String]) throws -> BackendCommandOutput
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

    public func run(arguments: [String]) throws -> BackendCommandOutput {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [executable] + arguments

        let standardOutput = Pipe()
        let standardError = Pipe()
        process.standardOutput = standardOutput
        process.standardError = standardError

        try process.run()
        process.waitUntilExit()

        let stdout = String(data: standardOutput.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let stderr = String(data: standardError.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return BackendCommandOutput(stdout: stdout, stderr: stderr, exitCode: Int(process.terminationStatus))
    }
}
