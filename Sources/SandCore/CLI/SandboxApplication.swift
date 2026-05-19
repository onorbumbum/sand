public protocol SandboxApplication {
    func run(_ request: RunRequest) throws -> CommandResult
}

public struct RunRequest: Equatable {
    public var sandboxName: SandboxName
    public var command: WorkloadCommand

    public init(sandboxName: SandboxName, command: WorkloadCommand) {
        self.sandboxName = sandboxName
        self.command = command
    }
}

public enum CommandResult: Equatable {
    case success
    case failure(exitCode: Int)
}
