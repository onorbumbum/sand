/// Defines the interface for sandbox VM backend operations.
///
/// Implementations handle VM provisioning, starting, stopping,
/// and execution on the host system.
public protocol SandboxBackend {
    func checkReadiness() throws -> BackendReadiness
    func provision(_ spec: SandboxSpec) throws
    func apply(_ spec: SandboxSpec) throws
    func start(_ spec: SandboxSpec) throws
    func stop(_ sandboxName: SandboxName) throws
    func run(_ request: BackendRunRequest) throws -> CommandResult
    func shell(_ request: BackendShellRequest) throws -> CommandResult
    func gui(_ request: BackendGUIRequest) throws -> CommandResult
    func status(_ sandboxName: SandboxName) throws -> SandboxRuntimeStatus
    func logs(_ sandboxName: SandboxName) throws -> SandboxLogs
    func delete(_ sandboxName: SandboxName) throws
}

/// The readiness state of the backend.
public enum BackendReadiness: Equatable {
    case ready
    case notReady([DoctorFinding])
}

/// A request to run a command in a sandbox VM.
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

/// A request to open a shell in a sandbox VM.
public struct BackendShellRequest: Equatable {
    public var sandboxName: SandboxName
    public var workingDirectory: GuestPath

    public init(sandboxName: SandboxName, workingDirectory: GuestPath) {
        self.sandboxName = sandboxName
        self.workingDirectory = workingDirectory
    }
}

/// A request to open a graphical desktop session for a sandbox VM.
public struct BackendGUIRequest: Equatable {
    public var spec: SandboxSpec

    public init(spec: SandboxSpec) {
        self.spec = spec
    }
}

/// The runtime status of a sandbox VM.
public enum SandboxRuntimeStatus: Equatable {
    case missing
    case stopped
    case running
}

/// Log output from a sandbox VM.
public struct SandboxLogs: Equatable {
    public var text: String

    public init(text: String) {
        self.text = text
    }
}