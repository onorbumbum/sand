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
        let identity = try runRecordStore.allocateIdentity(namePrefix: spec.namePrefix)
        try runRecordStore.createAttempt(identity: identity, sourceSpecText: request.authoredSpecText, sourcePath: request.sourcePath)

        let workloadCommand = request.workloadOverride ?? spec.workload.command
        let sandboxSpec = SandboxSpec(
            name: identity.sandboxName,
            image: spec.image,
            resourceProfile: spec.resourceProfile,
            allowedFolders: []
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
                command: workloadCommand,
                workingDirectory: spec.workload.workdir
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

    public init(root: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".sand/ephemeral-runs", isDirectory: true), fileManager: FileManager = .default) {
        self.root = root
        self.fileManager = fileManager
    }

    public func allocateIdentity(namePrefix: String) throws -> EphemeralRunIdentity {
        _ = try SandboxName(namePrefix)
        let timestamp = Self.timestampString()
        let suffix = String(UUID().uuidString.lowercased().prefix(6))
        let sandboxName = try SandboxName("\(namePrefix)-\(timestamp)-\(suffix)")
        let runID = "\(timestamp)-\(suffix)"
        let recordURL = root.appendingPathComponent(runID, isDirectory: true)
        return EphemeralRunIdentity(runID: runID, sandboxName: sandboxName, recordPath: recordURL.path)
    }

    public func createAttempt(identity: EphemeralRunIdentity, sourceSpecText: String, sourcePath: String) throws {
        let directory = URL(fileURLWithPath: identity.recordPath, isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
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

    private static func timestampString(date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: date)
    }

    private func escapeJSON(_ value: String) -> String {
        value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
    }
}

private struct EphemeralSpec {
    var schemaVersion: Int
    var namePrefix: String
    var image: SandboxImage
    var resourceProfile: ResourceProfile
    var workload: EphemeralCommandSpec

    static func parseYAML(_ text: String) throws -> EphemeralSpec {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var schemaVersion: Int?
        var namePrefix = "ephemeral"
        var image = SandboxImage.developerReadyDefault
        var resourceProfile = ResourceProfile.default
        var workload = PartialEphemeralCommand()
        var inWorkload = false
        var inWorkloadArgs = false
        var inResources = false
        var cpus: Int?
        var memory: MemorySize?

        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { continue }

            if !rawLine.hasPrefix(" ") {
                inWorkload = false
                inWorkloadArgs = false
                inResources = false
            }

            if inWorkloadArgs, line.hasPrefix("- ") {
                workload.args.append(String(line.dropFirst(2)).trimmingCharacters(in: .whitespaces))
                continue
            }

            guard let (key, value) = parseEphemeralKeyValue(line) else {
                throw EphemeralSpecError.malformedLine(rawLine)
            }

            if inResources {
                switch key {
                case "cpus": cpus = Int(value)
                case "memory": memory = try MemorySize.parse(value)
                default: throw EphemeralSpecError.unsupportedField("resources.\(key)")
                }
                continue
            }

            if inWorkload {
                switch key {
                case "command": workload.command = value
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

            switch key {
            case "schemaVersion": schemaVersion = Int(value)
            case "namePrefix": namePrefix = value
            case "image": image = SandboxImage(reference: value)
            case "resources":
                guard value.isEmpty else { throw EphemeralSpecError.malformedLine(rawLine) }
                inResources = true
            case "workload":
                guard value.isEmpty else { throw EphemeralSpecError.malformedLine(rawLine) }
                inWorkload = true
            default:
                throw EphemeralSpecError.unsupportedField(key)
            }
        }

        let version = try requireEphemeral(schemaVersion, "schemaVersion")
        guard version == SandboxSpec.supportedSchemaVersion else {
            throw EphemeralSpecError.unsupportedSchemaVersion(version)
        }
        _ = try SandboxName(namePrefix)
        if let cpus { resourceProfile.cpus = cpus }
        if let memory { resourceProfile.memory = memory }
        return EphemeralSpec(
            schemaVersion: version,
            namePrefix: namePrefix,
            image: image,
            resourceProfile: resourceProfile,
            workload: try workload.build()
        )
    }
}

private struct PartialEphemeralCommand {
    var command: String?
    var args: [String] = []
    var workdir: GuestPath?

    func build() throws -> EphemeralCommandSpec {
        let command = try requireEphemeral(command, "workload.command")
        guard !command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw EphemeralSpecError.emptyCommand
        }
        return EphemeralCommandSpec(
            command: try WorkloadCommand(arguments: [command] + args),
            workdir: try requireEphemeral(workdir, "workload.workdir")
        )
    }
}

private struct EphemeralCommandSpec {
    var command: WorkloadCommand
    var workdir: GuestPath
}

private func parseEphemeralKeyValue(_ line: String) -> (String, String)? {
    guard let colon = line.firstIndex(of: ":") else { return nil }
    let key = String(line[..<colon]).trimmingCharacters(in: .whitespaces)
    let value = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
    return (key, value)
}

private func requireEphemeral<T>(_ value: T?, _ field: String) throws -> T {
    guard let value else { throw EphemeralSpecError.missingField(field) }
    return value
}

public enum EphemeralSpecError: Error, Equatable, CustomStringConvertible {
    case unsupportedSchemaVersion(Int)
    case unsupportedField(String)
    case missingField(String)
    case malformedLine(String)
    case emptyCommand

    public var description: String {
        switch self {
        case .unsupportedSchemaVersion(let version): return "unsupported ephemeral spec schema version: \(version)"
        case .unsupportedField(let field): return "unsupported v1 ephemeral spec field: \(field)"
        case .missingField(let field): return "missing ephemeral spec field: \(field)"
        case .malformedLine(let line): return "malformed ephemeral spec line: \(line)"
        case .emptyCommand: return "ephemeral workload command cannot be empty"
        }
    }
}
