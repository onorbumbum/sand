import Foundation

public struct CLICommandRouter {
    private let application: any SandboxApplication
    private let readTextFile: (String) throws -> String

    public init(application: any SandboxApplication, readTextFile: @escaping (String) throws -> String = { try String(contentsOfFile: $0, encoding: .utf8) }) {
        self.application = application
        self.readTextFile = readTextFile
    }

    @discardableResult
    public func dispatch(arguments: [String]) throws -> CommandResult {
        guard let first = arguments.first else {
            throw CLICommandError.missingCommand
        }

        switch first {
        case "doctor":
            try requireExactCount(arguments, 1)
            return try application.doctor()
        case "list":
            try requireExactCount(arguments, 1)
            return try application.list()
        case "create":
            return try dispatchCreate(Array(arguments.dropFirst()))
        case "apply":
            let name = try singleNameArgument(arguments, command: "apply")
            return try application.apply(NamedSandboxRequest(sandboxName: name))
        case "delete":
            return try dispatchDelete(Array(arguments.dropFirst()))
        case "folders":
            return try dispatchFolders(Array(arguments.dropFirst()))
        case "reset":
            throw CLICommandError.unsupportedCommand("reset")
        default:
            return try dispatchSandboxFirst(nameArgument: first, remaining: Array(arguments.dropFirst()))
        }
    }

    private func dispatchCreate(_ arguments: [String]) throws -> CommandResult {
        guard let nameArgument = arguments.first else { throw CLICommandError.missingSandboxName }
        let name = try SandboxName(nameArgument)
        var image = SandboxImage.developerReadyDefault
        var resourceProfile = ResourceProfile.default
        var authoredSpecText: String?
        var index = 1

        while index < arguments.count {
            switch arguments[index] {
            case "--from":
                index += 1
                guard index < arguments.count else { throw CLICommandError.missingOptionValue("--from") }
                authoredSpecText = try readTextFile(arguments[index])
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

        return try application.create(CreateRequest(sandboxName: name, authoredSpecText: authoredSpecText, image: image, resourceProfile: resourceProfile))
    }

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

    private func dispatchSandboxFirst(nameArgument: String, remaining: [String]) throws -> CommandResult {
        let name = try SandboxName(nameArgument)
        guard let action = remaining.first else { throw CLICommandError.missingAction }

        switch action {
        case "status":
            try requireExactCount(remaining, 1)
            return try application.status(NamedSandboxRequest(sandboxName: name))
        case "start":
            try requireExactCount(remaining, 1)
            return try application.start(NamedSandboxRequest(sandboxName: name))
        case "stop":
            try requireExactCount(remaining, 1)
            return try application.stop(NamedSandboxRequest(sandboxName: name))
        case "shell":
            try requireExactCount(remaining, 1)
            return try application.shell(ShellRequest(sandboxName: name))
        case "run":
            let workloadArguments = Array(remaining.dropFirst())
            let command = try WorkloadCommand(arguments: workloadArguments)
            return try application.run(RunRequest(sandboxName: name, command: command))
        case "logs":
            try requireExactCount(remaining, 1)
            return try application.logs(NamedSandboxRequest(sandboxName: name))
        case "spec":
            try requireExactCount(remaining, 1)
            return try application.spec(NamedSandboxRequest(sandboxName: name))
        case "pi":
            throw CLICommandError.unsupportedAction("pi")
        default:
            throw CLICommandError.unsupportedAction(action)
        }
    }

    private func singleNameArgument(_ arguments: [String], command: String) throws -> SandboxName {
        guard arguments.count == 2 else { throw CLICommandError.missingArgument("\(command) <name>") }
        return try SandboxName(arguments[1])
    }

    private func requireExactCount(_ arguments: [String], _ count: Int) throws {
        guard arguments.count == count else { throw CLICommandError.unexpectedArguments(Array(arguments.dropFirst(count))) }
    }
}

public enum CLICommandError: Error, Equatable, CustomStringConvertible {
    case missingCommand
    case missingSandboxName
    case missingAction
    case missingArgument(String)
    case missingOptionValue(String)
    case unsupportedCommand(String)
    case unsupportedAction(String)
    case unsupportedOption(String)
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
        case .unexpectedArguments(let arguments): return "unexpected arguments: \(arguments.joined(separator: " "))"
        }
    }
}
