import Foundation

/// Request to execute an explicit bounded Ephemeral Sandbox Run.
public struct EphemeralRunRequest: Equatable {
    public var authoredSpecText: String
    public var sourcePath: String
    public var workloadOverride: WorkloadCommand?

    public init(authoredSpecText: String, sourcePath: String, workloadOverride: WorkloadCommand? = nil) {
        self.authoredSpecText = authoredSpecText
        self.sourcePath = sourcePath
        self.workloadOverride = workloadOverride
    }
}

/// Allocated identity for a single Ephemeral Sandbox Run.
public struct EphemeralRunIdentity: Equatable {
    public var runID: String
    public var sandboxName: SandboxName
    public var recordPath: String

    public init(runID: String, sandboxName: SandboxName, recordPath: String) {
        self.runID = runID
        self.sandboxName = sandboxName
        self.recordPath = recordPath
    }
}

/// Persisted final summary for an Ephemeral Sandbox Run.
public struct EphemeralRunResult: Equatable {
    public var status: String
    public var exitCode: Int
    public var recordPath: String

    public init(status: String, exitCode: Int, recordPath: String) {
        self.status = status
        self.exitCode = exitCode
        self.recordPath = recordPath
    }
}

/// Stores durable records for bounded Ephemeral Sandbox Run attempts.
public protocol EphemeralRunRecordStore {
    func allocateIdentity(namePrefix: String) throws -> EphemeralRunIdentity
    func createAttempt(identity: EphemeralRunIdentity, sourceSpecText: String, sourcePath: String) throws
    func writeGeneratedSpec(_ spec: SandboxSpec, identity: EphemeralRunIdentity) throws
    func writeResult(_ result: EphemeralRunResult, identity: EphemeralRunIdentity) throws
}

/// Coordinates the bounded create-start-run-stop-delete happy path for ephemeral runs.
public struct EphemeralRunCoordinator {
    private let metadataStore: any HostMetadataStore
    private let backend: any SandboxBackend
    private let runRecordStore: any EphemeralRunRecordStore
    private let writeOutput: (String) -> Void

    public init(
        metadataStore: any HostMetadataStore,
        backend: any SandboxBackend,
        runRecordStore: any EphemeralRunRecordStore,
        writeOutput: @escaping (String) -> Void = { Swift.print($0) }
    ) {
        self.metadataStore = metadataStore
        self.backend = backend
        self.runRecordStore = runRecordStore
        self.writeOutput = writeOutput
    }

    public func run(_ request: EphemeralRunRequest) throws -> CommandResult {
        let spec = try EphemeralSpec.parseYAML(request.authoredSpecText)
        let plan = try EphemeralRunPlan.build(from: spec, workloadOverride: request.workloadOverride)
        let identity = try runRecordStore.allocateIdentity(namePrefix: plan.namePrefix)
        try runRecordStore.createAttempt(identity: identity, sourceSpecText: request.authoredSpecText, sourcePath: request.sourcePath)

        let sandboxSpec = try plan.concreteSandboxSpec(
            name: identity.sandboxName,
            sourcePath: request.sourcePath
        )
        try runRecordStore.writeGeneratedSpec(sandboxSpec, identity: identity)

        try metadataStore.withLifecycleMutationLock {
            try metadataStore.createSpec(sandboxSpec)
            try backend.provision(sandboxSpec)
            try backend.start(identity.sandboxName)
        }

        let workloadResult = try backend.run(
            BackendRunRequest(
                sandboxName: identity.sandboxName,
                command: plan.workload.command,
                workingDirectory: plan.workload.workdir
            )
        )

        try metadataStore.withLifecycleMutationLock {
            try backend.stop(identity.sandboxName)
            try backend.delete(identity.sandboxName)
            try metadataStore.deleteSpec(named: identity.sandboxName)
        }

        let result: EphemeralRunResult
        switch workloadResult {
        case .success:
            result = EphemeralRunResult(status: "success", exitCode: 0, recordPath: identity.recordPath)
        case .failure(let exitCode):
            result = EphemeralRunResult(status: "failure", exitCode: exitCode, recordPath: identity.recordPath)
        }
        try runRecordStore.writeResult(result, identity: identity)

        writeOutput("Ephemeral run status: \(result.status)")
        writeOutput("Run record: \(identity.recordPath)")
        return workloadResult
    }
}

/// Filesystem-backed run record store under ~/.sand/ephemeral-runs.
public final class FileEphemeralRunRecordStore: EphemeralRunRecordStore {
    private let root: URL
    private let fileManager: FileManager
    private let timestampProvider: () -> String
    private let suffixGenerator: () -> String

    public convenience init(
        root: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".sand/ephemeral-runs", isDirectory: true),
        fileManager: FileManager = .default
    ) {
        self.init(
            root: root,
            fileManager: fileManager,
            timestampProvider: FileEphemeralRunRecordStore.timestampString,
            suffixGenerator: FileEphemeralRunRecordStore.randomSuffix
        )
    }

    public init(
        root: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".sand/ephemeral-runs", isDirectory: true),
        fileManager: FileManager = .default,
        timestampProvider: @escaping () -> String,
        suffixGenerator: @escaping () -> String
    ) {
        self.root = root
        self.fileManager = fileManager
        self.timestampProvider = timestampProvider
        self.suffixGenerator = suffixGenerator
    }

    public func allocateIdentity(namePrefix: String) throws -> EphemeralRunIdentity {
        _ = try SandboxName(namePrefix)
        let timestamp = timestampProvider()
        let suffix = suffixGenerator()
        let sandboxName = try SandboxName("\(namePrefix)-\(timestamp)-\(suffix)")
        let runID = "\(timestamp)-\(suffix)"
        let recordURL = root.appendingPathComponent(runID, isDirectory: true)
        return EphemeralRunIdentity(runID: runID, sandboxName: sandboxName, recordPath: recordURL.path)
    }

    public func createAttempt(identity: EphemeralRunIdentity, sourceSpecText: String, sourcePath: String) throws {
        let directory = URL(fileURLWithPath: identity.recordPath, isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        try identityJSON(for: identity).write(to: directory.appendingPathComponent("identity.json"), atomically: true, encoding: .utf8)
        try sourceSpecText.write(to: directory.appendingPathComponent("source-ephemeral-spec.yaml"), atomically: true, encoding: .utf8)
        try (sourcePath + "\n").write(to: directory.appendingPathComponent("source-path.txt"), atomically: true, encoding: .utf8)
    }

    public func writeGeneratedSpec(_ spec: SandboxSpec, identity: EphemeralRunIdentity) throws {
        let directory = URL(fileURLWithPath: identity.recordPath, isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        try spec.renderedYAML().write(to: directory.appendingPathComponent("generated-sandbox-spec.yaml"), atomically: true, encoding: .utf8)
    }

    public func writeResult(_ result: EphemeralRunResult, identity: EphemeralRunIdentity) throws {
        let directory = URL(fileURLWithPath: identity.recordPath, isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let json = """
        {
          "status": "\(result.status)",
          "exitCode": \(result.exitCode),
          "recordPath": "\(escapeJSON(result.recordPath))"
        }
        """
        try (json + "\n").write(to: directory.appendingPathComponent("result.json"), atomically: true, encoding: .utf8)
    }

    private static func timestampString() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: Date())
    }

    private static func randomSuffix() -> String {
        String(UUID().uuidString.lowercased().filter { $0.isLetter || $0.isNumber }.prefix(6))
    }

    private func identityJSON(for identity: EphemeralRunIdentity) -> String {
        """
        {
          "runID": "\(escapeJSON(identity.runID))",
          "sandboxName": "\(escapeJSON(identity.sandboxName.rawValue))",
          "recordPath": "\(escapeJSON(identity.recordPath))"
        }
        """ + "\n"
    }

    private func escapeJSON(_ value: String) -> String {
        value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
    }
}

public struct EphemeralSpec: Equatable {
    public static let defaultNamePrefix = "ephemeral"

    public var schemaVersion: Int
    public var description: String?
    public var namePrefix: String
    public var image: SandboxImage
    public var resourceProfile: ResourceProfile
    public var allowedFolders: [EphemeralAllowedFolderIntent]
    public var workload: EphemeralWorkloadIntent?

    public static func parseYAML(_ text: String) throws -> EphemeralSpec {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var schemaVersion: Int?
        var description: String?
        var namePrefix = EphemeralSpec.defaultNamePrefix
        var image = SandboxImage.developerReadyDefault
        var resourceProfile = ResourceProfile.default
        var workload = PartialEphemeralCommand()
        var allowedFolders: [EphemeralAllowedFolderIntent] = []
        var currentFolder: PartialEphemeralAllowedFolder?
        var inWorkload = false
        var inWorkloadArgs = false
        var inResources = false
        var inAllowedFolders = false
        var cpus: Int?
        var memory: MemorySize?

        func finishCurrentFolder() throws {
            if let folder = currentFolder {
                allowedFolders.append(try folder.build())
                currentFolder = nil
            }
        }

        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { continue }

            if !rawLine.hasPrefix(" ") {
                try finishCurrentFolder()
                inWorkload = false
                inWorkloadArgs = false
                inResources = false
                inAllowedFolders = false
            }

            if inWorkloadArgs {
                if line.hasPrefix("- ") {
                    let argument = String(line.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                    try rejectCommandListShorthand(argument)
                    workload.args.append(argument)
                    continue
                }
                inWorkloadArgs = false
            }

            if inWorkload, line.hasPrefix("- ") {
                throw EphemeralSpecError.unsupportedCommandListShorthand
            }

            if inAllowedFolders, line.hasPrefix("- ") {
                try finishCurrentFolder()
                currentFolder = PartialEphemeralAllowedFolder()
                let remainder = String(line.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                if !remainder.isEmpty {
                    guard let (key, value) = parseYAMLKeyValue(remainder) else {
                        throw EphemeralSpecError.malformedLine(rawLine)
                    }
                    try currentFolder?.set(key: key, value: value)
                }
                continue
            }

            guard let (key, value) = parseYAMLKeyValue(line) else {
                if inAllowedFolders, line == "[]" { continue }
                throw EphemeralSpecError.malformedLine(rawLine)
            }

            if inResources {
                switch key {
                case "cpus":
                    guard let value = Int(value) else { throw EphemeralSpecError.malformedLine(rawLine) }
                    cpus = value
                case "memory": memory = try MemorySize.parse(value)
                default: throw EphemeralSpecError.unsupportedField("resources.\(key)")
                }
                continue
            }

            if inWorkload {
                switch key {
                case "command":
                    try rejectCommandListShorthand(value)
                    workload.command = value
                case "workdir": workload.workdir = try GuestPath(value)
                case "args":
                    if value == "[]" { workload.args = [] }
                    else {
                        guard value.isEmpty else { throw EphemeralSpecError.malformedLine(rawLine) }
                        inWorkloadArgs = true
                    }
                default: throw EphemeralSpecError.unsupportedField("workload.\(key)")
                }
                continue
            }

            if inAllowedFolders {
                guard currentFolder != nil else { throw EphemeralSpecError.malformedLine(rawLine) }
                try currentFolder?.set(key: key, value: value)
                continue
            }

            switch key {
            case "schemaVersion":
                guard let value = Int(value) else { throw EphemeralSpecError.malformedLine(rawLine) }
                schemaVersion = value
            case "description": description = value
            case "namePrefix": namePrefix = value
            case "image": image = SandboxImage(reference: value)
            case "resources":
                guard value.isEmpty else { throw EphemeralSpecError.malformedLine(rawLine) }
                inResources = true
            case "workload":
                if isCommandListShorthand(value) { throw EphemeralSpecError.unsupportedCommandListShorthand }
                guard value.isEmpty else { throw EphemeralSpecError.malformedLine(rawLine) }
                inWorkload = true
            case "allowedFolders":
                if value == "[]" { inAllowedFolders = false }
                else {
                    guard value.isEmpty else { throw EphemeralSpecError.malformedLine(rawLine) }
                    inAllowedFolders = true
                }
            default:
                throw EphemeralSpecError.unsupportedField(key)
            }
        }

        try finishCurrentFolder()

        let version = try requireYAMLValue(schemaVersion, "schemaVersion", missingError: EphemeralSpecError.missingField)
        guard version == SandboxSpec.supportedSchemaVersion else {
            throw EphemeralSpecError.unsupportedSchemaVersion(version)
        }
        if let cpus { resourceProfile.cpus = cpus }
        if let memory { resourceProfile.memory = memory }
        return EphemeralSpec(
            schemaVersion: version,
            description: description,
            namePrefix: namePrefix,
            image: image,
            resourceProfile: resourceProfile,
            allowedFolders: allowedFolders,
            workload: try workload.buildIfPresent()
        )
    }
}

public struct EphemeralRunPlan: Equatable {
    public var namePrefix: String
    public var image: SandboxImage
    public var resourceProfile: ResourceProfile
    public var allowedFolders: [EphemeralAllowedFolderIntent]
    public var workload: EphemeralCommandSpec

    public static func build(from spec: EphemeralSpec, workloadOverride: WorkloadCommand? = nil) throws -> EphemeralRunPlan {
        do {
            _ = try SandboxName(spec.namePrefix)
        } catch {
            throw EphemeralSpecError.invalidNamePrefix(spec.namePrefix)
        }

        let command: WorkloadCommand
        let explicitWorkdir: GuestPath?
        if let override = workloadOverride {
            command = override
            explicitWorkdir = spec.workload?.workdir
        } else {
            let yamlWorkload = try requireYAMLValue(spec.workload, "workload.command", missingError: EphemeralSpecError.missingField)
            command = yamlWorkload.command
            explicitWorkdir = yamlWorkload.workdir
        }

        let workdir = try explicitWorkdir ?? defaultWorkdir(from: spec.allowedFolders)

        return EphemeralRunPlan(
            namePrefix: spec.namePrefix,
            image: spec.image,
            resourceProfile: spec.resourceProfile,
            allowedFolders: spec.allowedFolders,
            workload: EphemeralCommandSpec(command: command, workdir: workdir)
        )
    }

    private static func defaultWorkdir(from allowedFolders: [EphemeralAllowedFolderIntent]) throws -> GuestPath {
        guard let folder = allowedFolders.first(where: { $0.accessMode == .readWrite }) else {
            throw EphemeralSpecError.missingImplicitWorkdir
        }
        if let guestPath = folder.guestPath { return guestPath }
        return try FolderPolicy().defaultGuestPath(forDisplayHostPath: folder.hostPath)
    }

    public func concreteSandboxSpec(name: SandboxName, sourcePath: String) throws -> SandboxSpec {
        let sourceDirectory = URL(fileURLWithPath: sourcePath)
            .deletingLastPathComponent()
            .standardizedFileURL
        let folderPolicy = FolderPolicy { displayHostPath in
            EphemeralRunPlan.resolveHostPath(displayHostPath, relativeTo: sourceDirectory)
        }
        var spec = SandboxSpec(
            name: name,
            image: image,
            resourceProfile: resourceProfile,
            allowedFolders: []
        )

        for folder in allowedFolders {
            spec = try folderPolicy.addFolder(
                to: spec,
                displayHostPath: folder.hostPath,
                accessMode: folder.accessMode.rawValue,
                guestPath: folder.guestPath
            )
        }

        return spec
    }

    private static func resolveHostPath(_ hostPath: String, relativeTo sourceDirectory: URL) -> String {
        let expanded: URL
        if hostPath == "~" {
            expanded = FileManager.default.homeDirectoryForCurrentUser
        } else if hostPath.hasPrefix("~/") {
            expanded = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(String(hostPath.dropFirst(2)))
        } else if hostPath.hasPrefix("/") {
            expanded = URL(fileURLWithPath: hostPath)
        } else {
            expanded = sourceDirectory.appendingPathComponent(hostPath)
        }
        return expanded.resolvingSymlinksInPath().standardizedFileURL.path
    }
}

public struct EphemeralAllowedFolderIntent: Equatable {
    public var hostPath: String
    public var guestPath: GuestPath?
    public var accessMode: AccessMode
}

private struct PartialEphemeralAllowedFolder {
    var hostPath: String?
    var guestPath: GuestPath?
    var accessMode: AccessMode = .readWrite

    mutating func set(key: String, value: String) throws {
        switch key {
        case "hostPath": hostPath = value
        case "guestPath": guestPath = try GuestPath(value)
        case "accessMode": accessMode = try AccessMode.parse(value)
        case "resolvedHostPath": throw EphemeralSpecError.unsupportedField("allowedFolders.resolvedHostPath")
        default: throw EphemeralSpecError.unsupportedField("allowedFolders.\(key)")
        }
    }

    func build() throws -> EphemeralAllowedFolderIntent {
        EphemeralAllowedFolderIntent(
            hostPath: try requireYAMLValue(hostPath, "allowedFolders.hostPath", missingError: EphemeralSpecError.missingField),
            guestPath: guestPath,
            accessMode: accessMode
        )
    }
}

private struct PartialEphemeralCommand {
    var command: String?
    var args: [String] = []
    var workdir: GuestPath?

    func buildIfPresent() throws -> EphemeralWorkloadIntent? {
        guard command != nil || workdir != nil || !args.isEmpty else { return nil }
        let command = try requireYAMLValue(command, "workload.command", missingError: EphemeralSpecError.missingField)
        guard !command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw EphemeralSpecError.emptyCommand
        }
        return EphemeralWorkloadIntent(
            command: try WorkloadCommand(arguments: [command] + args),
            workdir: workdir
        )
    }
}

public struct EphemeralWorkloadIntent: Equatable {
    public var command: WorkloadCommand
    public var workdir: GuestPath?
}

public struct EphemeralCommandSpec: Equatable {
    public var command: WorkloadCommand
    public var workdir: GuestPath
}

private func rejectCommandListShorthand(_ value: String) throws {
    if isCommandListShorthand(value) {
        throw EphemeralSpecError.unsupportedCommandListShorthand
    }
}

private func isCommandListShorthand(_ value: String) -> Bool {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.hasPrefix("[") || trimmed.hasPrefix("- ")
}

public enum EphemeralSpecError: Error, Equatable, CustomStringConvertible {
    case unsupportedSchemaVersion(Int)
    case unsupportedField(String)
    case missingField(String)
    case malformedLine(String)
    case emptyCommand
    case unsupportedCommandListShorthand
    case invalidNamePrefix(String)
    case missingImplicitWorkdir

    public var description: String {
        switch self {
        case .unsupportedSchemaVersion(let version): return "unsupported ephemeral spec schema version: \(version)"
        case .unsupportedField(let field): return "unsupported v1 ephemeral spec field: \(field)"
        case .missingField(let field): return "missing ephemeral spec field: \(field)"
        case .malformedLine(let line): return "malformed ephemeral spec line: \(line)"
        case .emptyCommand: return "ephemeral workload command cannot be empty"
        case .unsupportedCommandListShorthand: return "unsupported v1 ephemeral command-list shorthand"
        case .invalidNamePrefix(let value): return "invalid ephemeral namePrefix: \(value)"
        case .missingImplicitWorkdir: return "no read-write allowed folder is available for default workload workdir"
        }
    }
}
