public struct CLICommandRouter {
    private let application: any SandboxApplication

    public init(application: any SandboxApplication) {
        self.application = application
    }

    @discardableResult
    public func dispatch(arguments: [String]) throws -> CommandResult {
        guard let sandboxNameArgument = arguments.first else {
            throw CLICommandError.missingSandboxName
        }

        guard arguments.count >= 2 else {
            throw CLICommandError.missingAction
        }

        let sandboxName = try SandboxName(sandboxNameArgument)
        let action = arguments[1]

        switch action {
        case "run":
            let workloadArguments = Array(arguments.dropFirst(2))
            let command = try WorkloadCommand(arguments: workloadArguments)
            return try application.run(RunRequest(sandboxName: sandboxName, command: command))
        default:
            throw CLICommandError.unsupportedAction(action)
        }
    }
}

public enum CLICommandError: Error, Equatable, CustomStringConvertible {
    case missingSandboxName
    case missingAction
    case unsupportedAction(String)

    public var description: String {
        switch self {
        case .missingSandboxName:
            return "missing sandbox name"
        case .missingAction:
            return "missing sandbox action"
        case .unsupportedAction(let action):
            return "unsupported sandbox action: \(action)"
        }
    }
}
