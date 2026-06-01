/// Defines the interface for sandbox VM operations.
///
/// Implementations handle the lifecycle of sandbox VMs.
public protocol SandboxApplication {
    func doctor() throws -> CommandResult
    func create(_ request: CreateRequest) throws -> CommandResult
    func list() throws -> CommandResult
    func apply(_ request: NamedSandboxRequest) throws -> CommandResult
    func delete(_ request: DeleteRequest) throws -> CommandResult
    func status(_ request: NamedSandboxRequest) throws -> CommandResult
    func start(_ request: NamedSandboxRequest) throws -> CommandResult
    func stop(_ request: NamedSandboxRequest) throws -> CommandResult
    func shell(_ request: ShellRequest) throws -> CommandResult
    func run(_ request: RunRequest) throws -> CommandResult
    func logs(_ request: NamedSandboxRequest) throws -> CommandResult
    func spec(_ request: NamedSandboxRequest) throws -> CommandResult
    func addFolder(_ request: AddFolderRequest) throws -> CommandResult
    func listFolders(_ request: NamedSandboxRequest) throws -> CommandResult
    func removeFolder(_ request: RemoveFolderRequest) throws -> CommandResult
}

/// A request containing only a sandbox name.
public struct NamedSandboxRequest: Equatable {
    public var sandboxName: SandboxName

    public init(sandboxName: SandboxName) {
        self.sandboxName = sandboxName
    }
}

/// A request to create a new sandbox VM.
public struct CreateRequest: Equatable {
    public var sandboxName: SandboxName
    public var authoredSpecText: String?
    public var image: SandboxImage
    public var resourceProfile: ResourceProfile

    public init(
        sandboxName: SandboxName,
        authoredSpecText: String? = nil,
        image: SandboxImage = .developerReadyDefault,
        resourceProfile: ResourceProfile = .default
    ) {
        self.sandboxName = sandboxName
        self.authoredSpecText = authoredSpecText
        self.image = image
        self.resourceProfile = resourceProfile
    }
}

/// A request to delete a sandbox VM.
public struct DeleteRequest: Equatable {
    public var sandboxName: SandboxName
    public var force: Bool

    public init(sandboxName: SandboxName, force: Bool = false) {
        self.sandboxName = sandboxName
        self.force = force
    }
}

/// A request to open a shell in a sandbox VM.
public struct ShellRequest: Equatable {
    public var sandboxName: SandboxName

    public init(sandboxName: SandboxName) {
        self.sandboxName = sandboxName
    }
}

/// A request to run a command in a sandbox VM.
public struct RunRequest: Equatable {
    public var sandboxName: SandboxName
    public var command: WorkloadCommand

    public init(sandboxName: SandboxName, command: WorkloadCommand) {
        self.sandboxName = sandboxName
        self.command = command
    }
}

/// A request to add an allowed folder to a sandbox.
public struct AddFolderRequest: Equatable {
    public var sandboxName: SandboxName
    public var displayHostPath: String
    public var accessMode: String
    public var guestPath: GuestPath?

    public init(sandboxName: SandboxName, displayHostPath: String, accessMode: String, guestPath: GuestPath? = nil) {
        self.sandboxName = sandboxName
        self.displayHostPath = displayHostPath
        self.accessMode = accessMode
        self.guestPath = guestPath
    }
}

/// A request to remove an allowed folder from a sandbox.
public struct RemoveFolderRequest: Equatable {
    public var sandboxName: SandboxName
    public var displayHostPath: String

    public init(sandboxName: SandboxName, displayHostPath: String) {
        self.sandboxName = sandboxName
        self.displayHostPath = displayHostPath
    }
}

/// The result of a command execution.
public enum CommandResult: Equatable {
    case success
    case failure(exitCode: Int)

    public var processExitCode: Int32 {
        switch self {
        case .success: return 0
        case .failure(let exitCode): return Int32(exitCode)
        }
    }
}