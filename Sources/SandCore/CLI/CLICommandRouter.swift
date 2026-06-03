import Foundation

/// Parses and dispatches CLI commands to the application layer.
public struct CLICommandRouter {
    public static let productVersion = "0.2.1-dev"

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
        case "ephemeral":
            if try printHelpIfRequested(arguments, CLIHelp.ephemeral) { return .success }
            return try dispatchEphemeral(Array(arguments.dropFirst()))
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
        case "reset":
            throw CLICommandError.unsupportedCommand("reset")
        default:
            return try dispatchSandboxFirst(nameArgument: first, remaining: Array(arguments.dropFirst()))
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

    // Parses and dispatches the `ephemeral` command with its options.
    private func dispatchEphemeral(_ arguments: [String]) throws -> CommandResult {
        guard let first = arguments.first else { throw CLICommandError.missingArgument("ephemeral --from <ephemeral-spec.yaml>") }
        if first == "init" {
            return try dispatchEphemeralInit(Array(arguments.dropFirst()))
        }

        guard arguments.count >= 2 else { throw CLICommandError.missingArgument("ephemeral --from <ephemeral-spec.yaml>") }
        guard arguments[0] == "--from" else { throw CLICommandError.unsupportedOption(arguments[0]) }
        let sourcePath = arguments[1]

        let workloadOverride: WorkloadCommand?
        if arguments.count == 2 {
            workloadOverride = nil
        } else {
            guard arguments[2] == "--" else {
                if arguments[2].hasPrefix("--") { throw CLICommandError.unsupportedOption(arguments[2]) }
                throw CLICommandError.unexpectedArguments(Array(arguments.dropFirst(2)))
            }
            let overrideArguments = Array(arguments.dropFirst(3))
            guard !overrideArguments.isEmpty else {
                throw CLICommandError.missingArgument("ephemeral --from <ephemeral-spec.yaml> -- <command> [args...]")
            }
            workloadOverride = try WorkloadCommand(arguments: overrideArguments)
        }

        let specText = try readTextFile(sourcePath)
        return try application.ephemeral(EphemeralRunRequest(authoredSpecText: specText, sourcePath: sourcePath, workloadOverride: workloadOverride))
    }

    private func dispatchEphemeralInit(_ arguments: [String]) throws -> CommandResult {
        guard let first = arguments.first else {
            throw CLICommandError.missingArgument("ephemeral init <path> [--force] or ephemeral init --stdout")
        }

        if first == "--stdout" {
            try requireExactCount(arguments, 1)
            writeOutput(EphemeralSpecTemplate.starterYAML)
            return .success
        }

        if first.hasPrefix("--") { throw CLICommandError.unsupportedOption(first) }
        let outputPath = first
        var force = false
        for argument in arguments.dropFirst() {
            switch argument {
            case "--force": force = true
            default:
                if argument.hasPrefix("--") { throw CLICommandError.unsupportedOption(argument) }
                throw CLICommandError.unexpectedArguments([argument])
            }
        }

        if FileManager.default.fileExists(atPath: outputPath), !force {
            throw CLICommandError.outputFileExists(outputPath)
        }
        try EphemeralSpecTemplate.starterYAML.write(toFile: outputPath, atomically: true, encoding: .utf8)
        return .success
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

    // Dispatches sandbox-first commands like `<name> status`.
    private func dispatchSandboxFirst(nameArgument: String, remaining: [String]) throws -> CommandResult {
        let name = try SandboxName(nameArgument)
        guard let action = remaining.first else { throw CLICommandError.missingAction }
        if action == "--help" || action == "-h" {
            try requireExactCount(remaining, 1)
            writeOutput(CLIHelp.sandboxActions)
            return .success
        }

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
      sand ephemeral --from <ephemeral-spec.yaml> [-- <workload override...>]
                                 Run a bounded Ephemeral Sandbox Run
      sand ephemeral init <path> [--force]
                                 Write a starter Ephemeral Spec YAML file
      sand ephemeral init --stdout
                                 Print the starter Ephemeral Spec YAML file
      list                           List Sandbox VMs
      apply <name>                   Apply spec changes
      delete <name> [--force]        Delete a Sandbox VM
      folders <action> ...           Manage allowed Host Mac folders
      <name> status                  Show Sandbox VM status
      <name> start                   Start a Sandbox VM
      <name> stop                    Stop a Sandbox VM
      <name> shell                   Open a shell
      <name> run <command> [args...] Run a Workload Command
      <name> logs                    Show logs
      <name> spec                    Print the sandbox spec

    Use `sand <command> --help` or `sand <name> --help` for command help.
    """

    static let doctor = """
    Usage: sand doctor

    Verifies host support, backend readiness, default image availability, and ~/.sand writability.
    """

    static let list = """
    Usage: sand list

    Lists known Sandbox VMs with runtime state, image, and allowed folder count.
    """

    static let create = """
    Usage: sand create <name> [--image <image>] [--cpus <count>] [--memory <size>] [--from <spec.yaml>]

    Creates a Sandbox VM from generated defaults or from an authored spec.
    """

    static let ephemeral = """
    Usage: sand ephemeral --from <ephemeral-spec.yaml> [-- <workload override...>]
           sand ephemeral init <path> [--force]
           sand ephemeral init --stdout

    `sand ephemeral --from` creates a temporary Sandbox VM, runs the spec workload or CLI workload override, stops and deletes it, and prints the run record path.

    `sand ephemeral init` writes a starter Ephemeral Spec YAML file or prints it with --stdout. It only generates a template and does not create a Sandbox VM.
    """

    static let apply = """
    Usage: sand apply <name>

    Applies allowed spec changes to an existing Sandbox VM.
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

    static let sandboxActions = """
    Usage: sand <name> <action> [arguments]

    Actions:
      status                         Show status
      start                          Start the Sandbox VM
      stop                           Stop the Sandbox VM
      shell                          Open an interactive shell
      run <command> [args...]        Run a Workload Command
      logs                           Show logs
      spec                           Print the sandbox spec
    """
}

private enum EphemeralSpecTemplate {
    static let starterYAML = """
    schemaVersion: 1
    description: Easy ephemeral smoke test
    namePrefix: smoke

    beforeProvision:
      - command: sh
        args:
          - -lc
          - 'mkdir -p work && echo "beforeProvision prepared work" > work/output.txt'

    allowedFolders:
      - hostPath: ./work
        guestPath: /workspace
        accessMode: read-write

    workload:
      command: sh
      args:
        - -lc
        - 'echo "workload wrote from Sandbox Guest" >> /workspace/output.txt && ls -la /workspace >> /workspace/output.txt'
      workdir: /workspace

    afterStop:
      - command: sh
        args:
          - -lc
          - 'echo "afterStop processed host-visible output" >> work/output.txt && cp work/output.txt work/after-stop.txt && cat work/after-stop.txt'
    """ + "\n"
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
    case outputFileExists(String)
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
        case .outputFileExists(let path): return "refusing to overwrite existing file: \(path) (use --force to replace it)"
        case .unexpectedArguments(let arguments): return "unexpected arguments: \(arguments.joined(separator: " "))"
        }
    }
}