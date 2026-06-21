import Foundation

/// Parses and dispatches CLI commands to the application layer.
public struct CLICommandRouter {
    public static let productVersion = "0.1.0-dev"

    private let application: any SandboxApplication
    private let readTextFile: (String) throws -> String
    private let writeOutput: (String) -> Void

    /// Initializes the command router with an application handler.
    public init(
        application: any SandboxApplication,
        readTextFile: @escaping (String) throws -> String = { try String(contentsOfFile: $0, encoding: .utf8) },
        writeOutput: @escaping (String) -> Void = { Swift.print($0) }
    ) {
        self.application = application
        self.readTextFile = readTextFile
        self.writeOutput = writeOutput
    }

    /// Parses command-line arguments and dispatches to the appropriate handler.
    @discardableResult
    public func dispatch(arguments: [String]) throws -> CommandResult {
        guard let first = arguments.first else {
            writeOutput(CLIHelp.topLevel)
            return .success
        }

        switch first {
        case "--help", "-h":
            try requireExactCount(arguments, 1)
            writeOutput(CLIHelp.topLevel)
            return .success
        case "--version":
            try requireExactCount(arguments, 1)
            writeOutput("sand \(Self.productVersion)")
            return .success
        case "doctor":
            if try printHelpIfRequested(arguments, CLIHelp.doctor) { return .success }
            try requireExactCount(arguments, 1)
            return try application.doctor()
        case "list":
            if try printHelpIfRequested(arguments, CLIHelp.list) { return .success }
            try requireExactCount(arguments, 1)
            return try application.list()
        case "create":
            if try printHelpIfRequested(arguments, CLIHelp.create) { return .success }
            return try dispatchCreate(Array(arguments.dropFirst()))
        case "apply":
            if try printHelpIfRequested(arguments, CLIHelp.apply) { return .success }
            let name = try singleNameArgument(arguments, command: "apply")
            return try application.apply(NamedSandboxRequest(sandboxName: name))
        case "delete":
            if try printHelpIfRequested(arguments, CLIHelp.delete) { return .success }
            return try dispatchDelete(Array(arguments.dropFirst()))
        case "folders":
            if try printHelpIfRequested(arguments, CLIHelp.folders) { return .success }
            return try dispatchFolders(Array(arguments.dropFirst()))
        case "status":
            if try printHelpIfRequested(arguments, CLIHelp.status) { return .success }
            let name = try singleNameArgument(arguments, command: "status")
            return try application.status(NamedSandboxRequest(sandboxName: name))
        case "start":
            if try printHelpIfRequested(arguments, CLIHelp.start) { return .success }
            let name = try singleNameArgument(arguments, command: "start")
            return try application.start(NamedSandboxRequest(sandboxName: name))
        case "stop":
            if try printHelpIfRequested(arguments, CLIHelp.stop) { return .success }
            let name = try singleNameArgument(arguments, command: "stop")
            return try application.stop(NamedSandboxRequest(sandboxName: name))
        case "shell":
            if try printHelpIfRequested(arguments, CLIHelp.shell) { return .success }
            let name = try singleNameArgument(arguments, command: "shell")
            return try application.shell(ShellRequest(sandboxName: name))
        case "run":
            if try printHelpIfRequested(arguments, CLIHelp.run) { return .success }
            guard arguments.count >= 3 else { throw CLICommandError.missingArgument("run <name> <command> [args...]") }
            let name = try SandboxName(arguments[1])
            let command = try WorkloadCommand(arguments: Array(arguments.dropFirst(2)))
            return try application.run(RunRequest(sandboxName: name, command: command))
        case "logs":
            if try printHelpIfRequested(arguments, CLIHelp.logs) { return .success }
            let name = try singleNameArgument(arguments, command: "logs")
            return try application.logs(NamedSandboxRequest(sandboxName: name))
        case "spec":
            if try printHelpIfRequested(arguments, CLIHelp.spec) { return .success }
            let name = try singleNameArgument(arguments, command: "spec")
            return try application.spec(NamedSandboxRequest(sandboxName: name))
        case "reset":
            throw CLICommandError.unsupportedCommand("reset")
        default:
            throw CLICommandError.unsupportedCommand(first)
        }
    }

    // Parses and dispatches the `create` command with its options.
    private func dispatchCreate(_ arguments: [String]) throws -> CommandResult {
        guard let firstArgument = arguments.first else { throw CLICommandError.missingSandboxName }
        var name: SandboxName?
        var image = SandboxImage.developerReadyDefault
        var resourceProfile = ResourceProfile.default
        var authoredSpecText: String?
        var index = 0

        if !firstArgument.hasPrefix("--") {
            name = try SandboxName(firstArgument)
            index = 1
        }

        while index < arguments.count {
            switch arguments[index] {
            case "--from":
                index += 1
                guard index < arguments.count else { throw CLICommandError.missingOptionValue("--from") }
                let text = try readTextFile(arguments[index])
                let spec = try SandboxSpec.parseYAML(text)
                if let explicitName = name, explicitName != spec.name {
                    throw CLICommandError.specNameMismatch(expected: explicitName.rawValue, actual: spec.name.rawValue)
                }
                name = spec.name
                authoredSpecText = text
            case "--cpus":
                index += 1
                guard index < arguments.count, let cpus = Int(arguments[index]) else { throw CLICommandError.missingOptionValue("--cpus") }
                resourceProfile.cpus = cpus
            case "--memory":
                index += 1
                guard index < arguments.count else { throw CLICommandError.missingOptionValue("--memory") }
                resourceProfile.memory = try MemorySize.parse(arguments[index])
            case "--image":
                index += 1
                guard index < arguments.count else { throw CLICommandError.missingOptionValue("--image") }
                image = SandboxImage(reference: arguments[index])
            case "--inbound", "--port", "--publish":
                throw CLICommandError.unsupportedOption(arguments[index])
            default:
                throw CLICommandError.unsupportedOption(arguments[index])
            }
            index += 1
        }

        guard let name else { throw CLICommandError.missingSandboxName }
        return try application.create(CreateRequest(sandboxName: name, authoredSpecText: authoredSpecText, image: image, resourceProfile: resourceProfile))
    }

    // Parses and dispatches the `delete` command with its options.
    private func dispatchDelete(_ arguments: [String]) throws -> CommandResult {
        guard let nameArgument = arguments.first else { throw CLICommandError.missingSandboxName }
        let name = try SandboxName(nameArgument)
        var force = false
        for argument in arguments.dropFirst() {
            switch argument {
            case "--force": force = true
            default: throw CLICommandError.unsupportedOption(argument)
            }
        }
        return try application.delete(DeleteRequest(sandboxName: name, force: force))
    }

    // Parses and dispatches the `folders` subcommand.
    private func dispatchFolders(_ arguments: [String]) throws -> CommandResult {
        guard let action = arguments.first else { throw CLICommandError.missingAction }
        switch action {
        case "add":
            guard arguments.count >= 4 else { throw CLICommandError.missingArgument("folders add <name> <host-path> <mode>") }
            let name = try SandboxName(arguments[1])
            let hostPath = arguments[2]
            let accessMode = arguments[3]
            var guestPath: GuestPath?
            var index = 4
            while index < arguments.count {
                switch arguments[index] {
                case "--as":
                    index += 1
                    guard index < arguments.count else { throw CLICommandError.missingOptionValue("--as") }
                    guestPath = try GuestPath(arguments[index])
                default:
                    throw CLICommandError.unsupportedOption(arguments[index])
                }
                index += 1
            }
            return try application.addFolder(AddFolderRequest(sandboxName: name, displayHostPath: hostPath, accessMode: accessMode, guestPath: guestPath))
        case "list":
            guard arguments.count == 2 else { throw CLICommandError.missingSandboxName }
            return try application.listFolders(NamedSandboxRequest(sandboxName: try SandboxName(arguments[1])))
        case "remove":
            guard arguments.count == 3 else { throw CLICommandError.missingArgument("folders remove <name> <host-path>") }
            return try application.removeFolder(RemoveFolderRequest(sandboxName: try SandboxName(arguments[1]), displayHostPath: arguments[2]))
        default:
            throw CLICommandError.unsupportedAction(action)
        }
    }

    private func singleNameArgument(_ arguments: [String], command: String) throws -> SandboxName {
        guard arguments.count == 2 else { throw CLICommandError.missingArgument("\(command) <name>") }
        return try SandboxName(arguments[1])
    }

    private func printHelpIfRequested(_ arguments: [String], _ help: String) throws -> Bool {
        guard arguments.count >= 2, arguments[1] == "--help" || arguments[1] == "-h" else { return false }
        try requireExactCount(arguments, 2)
        writeOutput(help)
        return true
    }

    private func requireExactCount(_ arguments: [String], _ count: Int) throws {
        guard arguments.count == count else { throw CLICommandError.unexpectedArguments(Array(arguments.dropFirst(count))) }
    }
}

private enum CLIHelp {
    static let topLevel = """
    Usage: sand <command> [options]

    Commands:
      doctor                         Verify host prerequisites
      create <name> [options]        Create a Sandbox VM
      list                           List Sandbox VMs
      apply <name>                   Apply spec changes
      delete <name> [--force]        Delete a Sandbox VM
      folders <action> ...           Manage shared Host Mac folders
      status <name>                  Show Sandbox VM status
      start <name>                   Start a Sandbox VM
      stop <name>                    Stop a Sandbox VM
      shell <name>                   Open a shell
      run <name> <command> [args...] Run a Workload Command
      logs <name>                    Show logs
      spec <name>                    Print the sandbox spec

    Use `sand <command> --help` for command help.
    """

    static let doctor = """
    Usage: sand doctor

    Verifies host support, backend readiness, default image availability, and ~/.sand writability.
    """

    static let list = """
    Usage: sand list

    Lists known Sandbox VMs with runtime state, image, and shared folder count.
    """

    static let create = """
    Usage: sand create <name> [--image <image>] [--cpus <count>] [--memory <size>] [--from <spec.yaml>]

    Creates a Sandbox VM from generated defaults or from an authored spec.
    """

    static let apply = """
    Usage: sand apply <name>

    Applies shared spec changes to an existing Sandbox VM.
    """

    static let delete = """
    Usage: sand delete <name> [--force]

    Deletes the Sandbox VM runtime, guest state volume, and host metadata spec.
    """

    static let folders = """
    Usage: sand folders <action> ...

    Actions:
      folders add <name> <host-path> <rw|ro> [--as <guest-path>]
      folders list <name>
      folders remove <name> <host-path>
    """

    static let status = """
    Usage: sand status <name>

    Shows the current status of a Sandbox VM.
    """

    static let start = """
    Usage: sand start <name>

    Starts a Sandbox VM.
    """

    static let stop = """
    Usage: sand stop <name>

    Stops a Sandbox VM.
    """

    static let shell = """
    Usage: sand shell <name>

    Opens an interactive shell in the Sandbox VM.
    """

    static let run = """
    Usage: sand run <name> <command> [args...]

    Runs a command inside the Sandbox VM.
    """

    static let logs = """
    Usage: sand logs <name>

    Shows logs for a Sandbox VM.
    """

    static let spec = """
    Usage: sand spec <name>

    Prints the sandbox spec.
    """
}

/// Errors that can occur during CLI command processing.
public enum CLICommandError: Error, Equatable, CustomStringConvertible {
    case missingCommand
    case missingSandboxName
    case missingAction
    case missingArgument(String)
    case missingOptionValue(String)
    case unsupportedCommand(String)
    case unsupportedAction(String)
    case unsupportedOption(String)
    case specNameMismatch(expected: String, actual: String)
    case unexpectedArguments([String])

    public var description: String {
        switch self {
        case .missingCommand: return "missing command"
        case .missingSandboxName: return "missing sandbox name"
        case .missingAction: return "missing sandbox action"
        case .missingArgument(let usage): return "missing argument: \(usage)"
        case .missingOptionValue(let option): return "missing value for option: \(option)"
        case .unsupportedCommand(let command): return "unsupported command: \(command)"
        case .unsupportedAction(let action): return "unsupported sandbox action: \(action)"
        case .unsupportedOption(let option): return "unsupported option: \(option)"
        case .specNameMismatch(let expected, let actual): return "sandbox name mismatch: command expected \(expected), spec declares \(actual)"
        case .unexpectedArguments(let arguments): return "unexpected arguments: \(arguments.joined(separator: " "))"
        }
    }
}
