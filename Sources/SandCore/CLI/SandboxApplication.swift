import Foundation

/// Defines the interface for sandbox VM operations.
///
/// Implementations handle the lifecycle of sandbox VMs.
public protocol SandboxApplication {
    func doctor() throws -> CommandResult
    func create(_ request: CreateRequest) throws -> CommandResult
    func bootstrap(_ request: NamedSandboxRequest) throws -> CommandResult
    func list() throws -> CommandResult
    func apply(_ request: NamedSandboxRequest) throws -> CommandResult
    func delete(_ request: DeleteRequest) throws -> CommandResult
    func status(_ request: NamedSandboxRequest) throws -> CommandResult
    func start(_ request: NamedSandboxRequest) throws -> CommandResult
    func stop(_ request: NamedSandboxRequest) throws -> CommandResult
    func shell(_ request: ShellRequest) throws -> CommandResult
    func run(_ request: RunRequest) throws -> CommandResult
    func gui(_ request: GUIRequest) throws -> CommandResult
    func logs(_ request: NamedSandboxRequest) throws -> CommandResult
    func spec(_ request: NamedSandboxRequest) throws -> CommandResult
    func addFolder(_ request: AddFolderRequest) throws -> CommandResult
    func listFolders(_ request: NamedSandboxRequest) throws -> CommandResult
    func removeFolder(_ request: RemoveFolderRequest) throws -> CommandResult
    func installSigningCredentials(_ request: SigningCredentialsRequest) throws -> CommandResult
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
    public var guestOS: GuestOS
    public var resourceProfile: ResourceProfile
    public var diskSize: DiskSize?
    public var sourceReference: String?
    public var ipswSource: String?

    public init(
        sandboxName: SandboxName,
        authoredSpecText: String? = nil,
        image: SandboxImage = .developerReadyDefault,
        guestOS: GuestOS = .linux,
        resourceProfile: ResourceProfile? = nil,
        diskSize: DiskSize? = nil,
        sourceReference: String? = nil,
        ipswSource: String? = nil
    ) {
        self.sandboxName = sandboxName
        self.authoredSpecText = authoredSpecText
        self.image = image
        self.guestOS = guestOS
        self.resourceProfile = resourceProfile ?? ResourceProfile.default(for: guestOS)
        self.diskSize = diskSize
        self.sourceReference = sourceReference
        self.ipswSource = ipswSource
    }
}

public enum SandboxCreateError: Error, Equatable, CustomStringConvertible {
    case localCloneSourceNotStopped(String)

    public var description: String {
        switch self {
        case .localCloneSourceNotStopped(let name): return "local macOS clone source must be stopped: \(name)"
        }
    }
}

/// Errors raised when building or bootstrapping a self-made macOS base.
public enum SandboxBootstrapError: Error, Equatable, CustomStringConvertible {
    case unsupportedGuestOS(String)
    case alreadyBootstrapped(String)
    case setupRequired(String)

    public var description: String {
        switch self {
        case .unsupportedGuestOS(let guestOS):
            return "self-built IPSW bases and bootstrap are macOS-only; Sandbox VM uses \(guestOS)."
        case .alreadyBootstrapped(let name):
            return "Sandbox VM \(name) is already bootstrapped and ready for `sand shell \(name)`."
        case .setupRequired(let name):
            return "Sandbox VM \(name) still needs first-boot setup. Run `sand gui \(name)` to create/enable the Sandbox User, then run `sand bootstrap \(name)`."
        }
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

/// Errors raised when opening a graphical desktop session.
public enum SandboxGUIError: Error, Equatable, CustomStringConvertible {
    case unsupportedGuestOS(String)

    public var description: String {
        switch self {
        case .unsupportedGuestOS(let guestOS):
            return "gui is macOS-only; Sandbox VM uses \(guestOS)."
        }
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

/// A request to open a graphical desktop session in a sandbox VM.
public struct GUIRequest: Equatable {
    public var sandboxName: SandboxName

    public init(sandboxName: SandboxName) {
        self.sandboxName = sandboxName
    }
}

/// A request to add a shared folder to a sandbox.
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

/// A request to remove a shared folder from a sandbox.
public struct RemoveFolderRequest: Equatable {
    public var sandboxName: SandboxName
    public var displayHostPath: String

    public init(sandboxName: SandboxName, displayHostPath: String) {
        self.sandboxName = sandboxName
        self.displayHostPath = displayHostPath
    }
}

/// A request to install distribution-signing credentials as a Sandbox Guest Secret.
public struct SigningCredentialsRequest: Equatable {
    public var sandboxName: SandboxName
    public var certificateP12: Data
    public var certificatePassword: String
    public var provisioningProfile: Data
    public var keychainName: String
    public var keychainPassword: String

    public init(
        sandboxName: SandboxName,
        certificateP12: Data,
        certificatePassword: String,
        provisioningProfile: Data,
        keychainName: String = "sand-signing",
        keychainPassword: String
    ) {
        self.sandboxName = sandboxName
        self.certificateP12 = certificateP12
        self.certificatePassword = certificatePassword
        self.provisioningProfile = provisioningProfile
        self.keychainName = keychainName
        self.keychainPassword = keychainPassword
    }
}

public enum SandboxSigningError: Error, Equatable, CustomStringConvertible {
    case unsupportedGuestOS(String)

    public var description: String {
        switch self {
        case .unsupportedGuestOS(let guestOS): return "signing credentials are macOS-only; Sandbox VM uses \(guestOS)."
        }
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
