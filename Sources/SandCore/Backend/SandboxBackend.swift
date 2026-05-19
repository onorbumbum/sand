public protocol SandboxBackend {
    func checkReadiness() throws -> BackendReadiness
    func provision(_ spec: SandboxSpec) throws
    func apply(_ spec: SandboxSpec) throws
    func start(_ sandboxName: SandboxName) throws
    func stop(_ sandboxName: SandboxName) throws
    func run(_ request: BackendRunRequest) throws -> CommandResult
    func shell(_ request: BackendShellRequest) throws -> CommandResult
    func status(_ sandboxName: SandboxName) throws -> SandboxRuntimeStatus
    func logs(_ sandboxName: SandboxName) throws -> SandboxLogs
    func delete(_ sandboxName: SandboxName) throws
}

public enum BackendReadiness: Equatable {
    case ready
    case notReady([DoctorFinding])
}

public struct BackendRunRequest: Equatable {
    public var sandboxName: SandboxName
    public var command: WorkloadCommand
    public var workingDirectory: GuestPath

    public init(sandboxName: SandboxName, command: WorkloadCommand, workingDirectory: GuestPath) {
        self.sandboxName = sandboxName
        self.command = command
        self.workingDirectory = workingDirectory
    }
}

public struct BackendShellRequest: Equatable {
    public var sandboxName: SandboxName
    public var workingDirectory: GuestPath

    public init(sandboxName: SandboxName, workingDirectory: GuestPath) {
        self.sandboxName = sandboxName
        self.workingDirectory = workingDirectory
    }
}

public enum SandboxRuntimeStatus: Equatable {
    case missing
    case stopped
    case running
}

public struct SandboxLogs: Equatable {
    public var text: String

    public init(text: String) {
        self.text = text
    }
}
