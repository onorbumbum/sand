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
    public var failedPhase: String?
    public var manualCleanupGuidance: String?

    public init(
        status: String,
        exitCode: Int,
        recordPath: String,
        failedPhase: String? = nil,
        manualCleanupGuidance: String? = nil
    ) {
        self.status = status
        self.exitCode = exitCode
        self.recordPath = recordPath
        self.failedPhase = failedPhase
        self.manualCleanupGuidance = manualCleanupGuidance
    }
}

/// File paths for captured host hook output stored in the run record.
public struct HookOutputReference: Equatable {
    public var stdoutPath: String
    public var stderrPath: String

    public init(stdoutPath: String, stderrPath: String) {
        self.stdoutPath = stdoutPath
        self.stderrPath = stderrPath
    }
}

/// Structured event appended to an Ephemeral Run Record.
public struct EphemeralRunEvent: Equatable {
    public var phase: String
    public var status: String
    public var command: [String]
    public var workingDirectory: String
    public var exitCode: Int
    public var stdoutPath: String
    public var stderrPath: String

    public init(
        phase: String,
        status: String,
        command: [String],
        workingDirectory: String,
        exitCode: Int,
        stdoutPath: String,
        stderrPath: String
    ) {
        self.phase = phase
        self.status = status
        self.command = command
        self.workingDirectory = workingDirectory
        self.exitCode = exitCode
        self.stdoutPath = stdoutPath
        self.stderrPath = stderrPath
    }
}

/// Stores durable records for bounded Ephemeral Sandbox Run attempts.
public protocol EphemeralRunRecordStore {
    func allocateIdentity(namePrefix: String) throws -> EphemeralRunIdentity
    func createAttempt(identity: EphemeralRunIdentity, sourceSpecText: String, sourcePath: String) throws
    func writeGeneratedSpec(_ spec: SandboxSpec, identity: EphemeralRunIdentity) throws
    func writeHookOutput(phase: String, index: Int, stdout: String, stderr: String, identity: EphemeralRunIdentity) throws -> HookOutputReference
    func appendEvent(_ event: EphemeralRunEvent, identity: EphemeralRunIdentity) throws
    func writeResult(_ result: EphemeralRunResult, identity: EphemeralRunIdentity) throws
}

/// Request for running a Host Mac command with captured non-interactive IO.
public struct HostCommandRequest: Equatable {
    public var command: WorkloadCommand
    public var workingDirectory: String
    public var environment: [String: String]

    public init(command: WorkloadCommand, workingDirectory: String, environment: [String: String]) {
        self.command = command
        self.workingDirectory = workingDirectory
        self.environment = environment
    }
}

/// Captured Host Mac command result.
public struct HostCommandResult: Equatable {
    public var commandResult: CommandResult
    public var stdout: String
    public var stderr: String

    public init(commandResult: CommandResult, stdout: String, stderr: String) {
        self.commandResult = commandResult
        self.stdout = stdout
        self.stderr = stderr
    }
}

/// Port for Host Mac lifecycle hooks.
public protocol HostCommandRunner {
    func run(_ request: HostCommandRequest) throws -> HostCommandResult
}

/// Process-backed Host Mac command runner.
public struct ProcessHostCommandRunner: HostCommandRunner {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func run(_ request: HostCommandRequest) throws -> HostCommandResult {
        let executable = resolveExecutable(
            request.command.arguments[0],
            workingDirectory: request.workingDirectory,
            environment: request.environment
        )
        guard let executable else {
            return HostCommandResult(
                commandResult: .failure(exitCode: 127),
                stdout: "",
                stderr: "\(request.command.arguments[0]): command not found\n"
            )
        }

        let process = Process()
        process.executableURL = executable
        process.arguments = Array(request.command.arguments.dropFirst())
        process.currentDirectoryURL = URL(fileURLWithPath: request.workingDirectory, isDirectory: true)
        process.environment = request.environment

        let stdin = Pipe()
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardInput = stdin
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        try? stdin.fileHandleForWriting.close()
        let stdoutData = stdout.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderr.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        let exitCode = Int(process.terminationStatus)
        return HostCommandResult(
            commandResult: exitCode == 0 ? .success : .failure(exitCode: exitCode),
            stdout: String(data: stdoutData, encoding: .utf8) ?? "",
            stderr: String(data: stderrData, encoding: .utf8) ?? ""
        )
    }

    private func resolveExecutable(_ command: String, workingDirectory: String, environment: [String: String]) -> URL? {
        if command.contains("/") {
            let url = command.hasPrefix("/")
                ? URL(fileURLWithPath: command)
                : URL(fileURLWithPath: workingDirectory, isDirectory: true).appendingPathComponent(command)
            return fileManager.isExecutableFile(atPath: url.path) ? url : nil
        }

        for pathEntry in (environment["PATH"] ?? "").split(separator: ":", omittingEmptySubsequences: false) {
            let directory = pathEntry.isEmpty ? "." : String(pathEntry)
            let directoryURL = directory.hasPrefix("/")
                ? URL(fileURLWithPath: directory, isDirectory: true)
                : URL(fileURLWithPath: workingDirectory, isDirectory: true).appendingPathComponent(directory, isDirectory: true)
            let url = directoryURL.appendingPathComponent(command)
            if fileManager.isExecutableFile(atPath: url.path) { return url }
        }
        return nil
    }
}

/// Coordinates the bounded create-start-run-stop-delete happy path for ephemeral runs.
public struct EphemeralRunCoordinator {
    private let metadataStore: any HostMetadataStore
    private let backend: any SandboxBackend
    private let runRecordStore: any EphemeralRunRecordStore
    private let hostCommandRunner: any HostCommandRunner
    private let processEnvironment: () -> [String: String]
    private let writeOutput: (String) -> Void

    public init(
        metadataStore: any HostMetadataStore,
        backend: any SandboxBackend,
        runRecordStore: any EphemeralRunRecordStore,
        hostCommandRunner: any HostCommandRunner = ProcessHostCommandRunner(),
        processEnvironment: @escaping () -> [String: String] = { ProcessInfo.processInfo.environment },
        writeOutput: @escaping (String) -> Void = { Swift.print($0) }
    ) {
        self.metadataStore = metadataStore
        self.backend = backend
        self.runRecordStore = runRecordStore
        self.hostCommandRunner = hostCommandRunner
        self.processEnvironment = processEnvironment
        self.writeOutput = writeOutput
    }

    public func run(_ request: EphemeralRunRequest) throws -> CommandResult {
        let spec = try EphemeralSpec.parseYAML(request.authoredSpecText)
        let plan = try EphemeralRunPlan.build(from: spec, workloadOverride: request.workloadOverride)
        let identity = try runRecordStore.allocateIdentity(namePrefix: plan.namePrefix)
        try runRecordStore.createAttempt(identity: identity, sourceSpecText: request.authoredSpecText, sourcePath: request.sourcePath)

        let beforeProvisionResult = try runHostHooks(
            plan.beforeProvisionHooks,
            phase: "beforeProvision",
            identity: identity,
            sourcePath: request.sourcePath
        )
        if beforeProvisionResult != .success {
            return try writeFinalOutcome(
                FinalEphemeralOutcome(result: beforeProvisionResult, failedPhase: "beforeProvision"),
                identity: identity
            )
        }

        let sandboxSpec = try plan.concreteSandboxSpec(
            name: identity.sandboxName,
            sourcePath: request.sourcePath
        )
        try runRecordStore.writeGeneratedSpec(sandboxSpec, identity: identity)

        var startupFailure: (failedPhase: String, cleanupResult: CommandResult)?
        try metadataStore.withLifecycleMutationLock {
            try metadataStore.createSpec(sandboxSpec)

            do {
                try backend.provision(sandboxSpec)
            } catch {
                startupFailure = (
                    failedPhase: "provision",
                    cleanupResult: deleteEphemeralResourcesWithoutLock(named: identity.sandboxName)
                )
                return
            }

            do {
                try backend.start(identity.sandboxName)
            } catch {
                startupFailure = (
                    failedPhase: "start",
                    cleanupResult: deleteEphemeralResourcesWithoutLock(named: identity.sandboxName)
                )
                return
            }
        }

        if let startupFailure {
            return try writeFinalOutcome(
                provisionOrStartFailureOutcome(
                    failedPhase: startupFailure.failedPhase,
                    cleanupResult: startupFailure.cleanupResult,
                    sandboxName: identity.sandboxName
                ),
                identity: identity
            )
        }

        let workloadResult: CommandResult
        do {
            workloadResult = try backend.run(
                BackendRunRequest(
                    sandboxName: identity.sandboxName,
                    command: plan.workload.command,
                    workingDirectory: plan.workload.workdir,
                    replaceCurrentProcess: false
                )
            )
        } catch {
            workloadResult = .failure(exitCode: 1)
        }

        let stopResult: CommandResult
        do {
            try metadataStore.withLifecycleMutationLock {
                try backend.stop(identity.sandboxName)
            }
            stopResult = .success
        } catch {
            stopResult = .failure(exitCode: 1)
        }

        let afterStopResult = try runHostHooks(
            plan.afterStopHooks,
            phase: "afterStop",
            identity: identity,
            sourcePath: request.sourcePath
        )

        let deleteResult = deleteEphemeralResources(named: identity.sandboxName)

        return try writeFinalOutcome(
            dominantOutcome(
                workloadResult: workloadResult,
                stopResult: stopResult,
                afterStopResult: afterStopResult,
                deleteResult: deleteResult,
                sandboxName: identity.sandboxName
            ),
            identity: identity
        )
    }

    private func runHostHooks(_ hooks: [EphemeralHookIntent], phase: String, identity: EphemeralRunIdentity, sourcePath: String) throws -> CommandResult {
        let workingDirectory = URL(fileURLWithPath: sourcePath)
            .deletingLastPathComponent()
            .standardizedFileURL
            .path

        for (index, hook) in hooks.enumerated() {
            let hookResult: HostCommandResult
            do {
                hookResult = try hostCommandRunner.run(
                    HostCommandRequest(
                        command: hook.command,
                        workingDirectory: workingDirectory,
                        environment: processEnvironment()
                    )
                )
            } catch {
                hookResult = HostCommandResult(commandResult: .failure(exitCode: 1), stdout: "", stderr: "\(error)\n")
            }
            let outputReference = try runRecordStore.writeHookOutput(
                phase: phase,
                index: index,
                stdout: hookResult.stdout,
                stderr: hookResult.stderr,
                identity: identity
            )
            let exitCode = hookResult.commandResult.ephemeralExitCode
            let status = hookResult.commandResult == .success ? "success" : "failure"
            try runRecordStore.appendEvent(
                EphemeralRunEvent(
                    phase: phase,
                    status: status,
                    command: hook.command.arguments,
                    workingDirectory: workingDirectory,
                    exitCode: exitCode,
                    stdoutPath: outputReference.stdoutPath,
                    stderrPath: outputReference.stderrPath
                ),
                identity: identity
            )

            if hookResult.commandResult != .success {
                return hookResult.commandResult
            }
        }

        return .success
    }

    private func deleteEphemeralResources(named sandboxName: SandboxName) -> CommandResult {
        do {
            try metadataStore.withLifecycleMutationLock {
                try deleteEphemeralResourcesWithoutLockOrThrow(named: sandboxName)
            }
            return .success
        } catch {
            return .failure(exitCode: 1)
        }
    }

    private func deleteEphemeralResourcesWithoutLock(named sandboxName: SandboxName) -> CommandResult {
        do {
            try deleteEphemeralResourcesWithoutLockOrThrow(named: sandboxName)
            return .success
        } catch {
            return .failure(exitCode: 1)
        }
    }

    private func deleteEphemeralResourcesWithoutLockOrThrow(named sandboxName: SandboxName) throws {
        try backend.delete(sandboxName)
        try metadataStore.deleteSpec(named: sandboxName)
    }

    private func provisionOrStartFailureOutcome(failedPhase: String, cleanupResult: CommandResult, sandboxName: SandboxName) -> FinalEphemeralOutcome {
        if cleanupResult != .success {
            return FinalEphemeralOutcome(
                result: cleanupResult,
                failedPhase: "delete",
                manualCleanupCommand: manualCleanupCommand(for: sandboxName)
            )
        }
        return FinalEphemeralOutcome(result: .failure(exitCode: 1), failedPhase: failedPhase)
    }

    private func dominantOutcome(
        workloadResult: CommandResult,
        stopResult: CommandResult,
        afterStopResult: CommandResult,
        deleteResult: CommandResult,
        sandboxName: SandboxName
    ) -> FinalEphemeralOutcome {
        if deleteResult != .success {
            return FinalEphemeralOutcome(
                result: deleteResult,
                failedPhase: "delete",
                manualCleanupCommand: manualCleanupCommand(for: sandboxName)
            )
        }
        if afterStopResult != .success { return FinalEphemeralOutcome(result: afterStopResult, failedPhase: "afterStop") }
        if stopResult != .success { return FinalEphemeralOutcome(result: stopResult, failedPhase: "stop") }
        if workloadResult != .success { return FinalEphemeralOutcome(result: workloadResult, failedPhase: "workload") }
        return FinalEphemeralOutcome(result: .success, failedPhase: nil)
    }

    @discardableResult
    private func writeFinalOutcome(_ outcome: FinalEphemeralOutcome, identity: EphemeralRunIdentity) throws -> CommandResult {
        let manualCleanupGuidance = outcome.manualCleanupCommand.map {
            "Delete Sandbox VM \(identity.sandboxName.rawValue) manually with: \($0)"
        }
        let result = EphemeralRunResult(
            status: outcome.result == .success ? "success" : "failure",
            exitCode: outcome.result.ephemeralExitCode,
            recordPath: identity.recordPath,
            failedPhase: outcome.failedPhase,
            manualCleanupGuidance: manualCleanupGuidance
        )
        try runRecordStore.writeResult(result, identity: identity)

        writeOutput("Ephemeral run status: \(result.status)")
        writeOutput("Run record: \(identity.recordPath)")
        if result.status == "failure" {
            if let failedPhase = result.failedPhase { writeOutput("Failed phase: \(failedPhase)") }
            writeOutput("Exit code: \(result.exitCode)")
        }
        if let manualCleanupCommand = outcome.manualCleanupCommand {
            writeOutput("Manual cleanup: \(manualCleanupCommand)")
        }
        return outcome.result
    }

    private func manualCleanupCommand(for sandboxName: SandboxName) -> String {
        "sand delete \(sandboxName.rawValue) --force"
    }
}

private struct FinalEphemeralOutcome {
    var result: CommandResult
    var failedPhase: String?
    var manualCleanupCommand: String? = nil
}

private extension CommandResult {
    var ephemeralExitCode: Int {
        switch self {
        case .success: return 0
        case .failure(let exitCode): return exitCode
        }
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

    public func writeHookOutput(phase: String, index: Int, stdout: String, stderr: String, identity: EphemeralRunIdentity) throws -> HookOutputReference {
        let directory = URL(fileURLWithPath: identity.recordPath, isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let stdoutURL = directory.appendingPathComponent("\(phase)-\(index).stdout")
        let stderrURL = directory.appendingPathComponent("\(phase)-\(index).stderr")
        try stdout.write(to: stdoutURL, atomically: true, encoding: .utf8)
        try stderr.write(to: stderrURL, atomically: true, encoding: .utf8)
        return HookOutputReference(stdoutPath: stdoutURL.path, stderrPath: stderrURL.path)
    }

    public func appendEvent(_ event: EphemeralRunEvent, identity: EphemeralRunIdentity) throws {
        let directory = URL(fileURLWithPath: identity.recordPath, isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let line = eventJSON(event) + "\n"
        let eventLog = directory.appendingPathComponent("events.jsonl")
        if fileManager.fileExists(atPath: eventLog.path) {
            let handle = try FileHandle(forWritingTo: eventLog)
            try handle.seekToEnd()
            try handle.write(contentsOf: Data(line.utf8))
            try handle.close()
        } else {
            try line.write(to: eventLog, atomically: true, encoding: .utf8)
        }
    }

    public func writeResult(_ result: EphemeralRunResult, identity: EphemeralRunIdentity) throws {
        let directory = URL(fileURLWithPath: identity.recordPath, isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        var fields = [
            "  \"status\": \"\(escapeJSON(result.status))\"",
            "  \"exitCode\": \(result.exitCode)",
            "  \"recordPath\": \"\(escapeJSON(result.recordPath))\"",
            "  \"sandboxName\": \"\(escapeJSON(identity.sandboxName.rawValue))\""
        ]
        if let failedPhase = result.failedPhase {
            fields.append("  \"failedPhase\": \"\(escapeJSON(failedPhase))\"")
        }
        if let manualCleanupGuidance = result.manualCleanupGuidance {
            fields.append("  \"manualCleanupGuidance\": \"\(escapeJSON(manualCleanupGuidance))\"")
        }
        let json = "{\n" + fields.joined(separator: ",\n") + "\n}"
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

    private func eventJSON(_ event: EphemeralRunEvent) -> String {
        """
        {"phase":"\(escapeJSON(event.phase))","status":"\(escapeJSON(event.status))","command":\(jsonArray(event.command)),"workingDirectory":"\(escapeJSON(event.workingDirectory))","exitCode":\(event.exitCode),"stdoutPath":"\(escapeJSON(event.stdoutPath))","stderrPath":"\(escapeJSON(event.stderrPath))"}
        """
    }

    private func jsonArray(_ values: [String]) -> String {
        "[" + values.map { "\"\(escapeJSON($0))\"" }.joined(separator: ",") + "]"
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
    public var beforeProvisionHooks: [EphemeralHookIntent]
    public var afterStopHooks: [EphemeralHookIntent]
    public var workload: EphemeralWorkloadIntent?

    public static func parseYAML(_ text: String) throws -> EphemeralSpec {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var schemaVersion: Int?
        var description: String?
        var namePrefix = EphemeralSpec.defaultNamePrefix
        var image = SandboxImage.developerReadyDefault
        var resourceProfile = ResourceProfile.default
        var workload = PartialEphemeralCommand(context: "workload")
        var beforeProvisionHooks: [EphemeralHookIntent] = []
        var currentBeforeProvisionHook: PartialEphemeralCommand?
        var afterStopHooks: [EphemeralHookIntent] = []
        var currentAfterStopHook: PartialEphemeralCommand?
        var allowedFolders: [EphemeralAllowedFolderIntent] = []
        var currentFolder: PartialEphemeralAllowedFolder?
        var inWorkload = false
        var inWorkloadArgs = false
        var inBeforeProvision = false
        var inBeforeProvisionArgs = false
        var inAfterStop = false
        var inAfterStopArgs = false
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

        func finishCurrentBeforeProvisionHook() throws {
            if let hook = currentBeforeProvisionHook {
                beforeProvisionHooks.append(EphemeralHookIntent(command: try hook.buildRequired().command))
                currentBeforeProvisionHook = nil
            }
        }

        func finishCurrentAfterStopHook() throws {
            if let hook = currentAfterStopHook {
                afterStopHooks.append(EphemeralHookIntent(command: try hook.buildRequired().command))
                currentAfterStopHook = nil
            }
        }

        func setHookField(key: String, value: String, rawLine: String) throws {
            switch key {
            case "command":
                try rejectCommandListShorthand(value)
                currentBeforeProvisionHook?.command = value
            case "args":
                if value == "[]" { currentBeforeProvisionHook?.args = [] }
                else {
                    guard value.isEmpty else { throw EphemeralSpecError.malformedLine(rawLine) }
                    inBeforeProvisionArgs = true
                }
            default:
                throw EphemeralSpecError.unsupportedField("beforeProvision.\(key)")
            }
        }

        func setAfterStopHookField(key: String, value: String, rawLine: String) throws {
            switch key {
            case "command":
                try rejectCommandListShorthand(value)
                currentAfterStopHook?.command = value
            case "args":
                if value == "[]" { currentAfterStopHook?.args = [] }
                else {
                    guard value.isEmpty else { throw EphemeralSpecError.malformedLine(rawLine) }
                    inAfterStopArgs = true
                }
            default:
                throw EphemeralSpecError.unsupportedField("afterStop.\(key)")
            }
        }

        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { continue }

            if !rawLine.hasPrefix(" ") {
                try finishCurrentFolder()
                try finishCurrentBeforeProvisionHook()
                try finishCurrentAfterStopHook()
                inWorkload = false
                inWorkloadArgs = false
                inBeforeProvision = false
                inBeforeProvisionArgs = false
                inAfterStop = false
                inAfterStopArgs = false
                inResources = false
                inAllowedFolders = false
            }

            if inWorkloadArgs {
                if line.hasPrefix("- ") {
                    let argument = String(line.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                    try rejectCommandListShorthand(argument)
                    workload.args.append(parseYAMLScalar(argument))
                    continue
                }
                inWorkloadArgs = false
            }

            if inBeforeProvisionArgs {
                if line.hasPrefix("- ") {
                    let argument = String(line.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                    if parseYAMLKeyValue(argument)?.0 != "command" {
                        try rejectCommandListShorthand(argument)
                        currentBeforeProvisionHook?.args.append(parseYAMLScalar(argument))
                        continue
                    }
                }
                inBeforeProvisionArgs = false
            }

            if inAfterStopArgs {
                if line.hasPrefix("- ") {
                    let argument = String(line.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                    if parseYAMLKeyValue(argument)?.0 != "command" {
                        try rejectCommandListShorthand(argument)
                        currentAfterStopHook?.args.append(parseYAMLScalar(argument))
                        continue
                    }
                }
                inAfterStopArgs = false
            }

            if inWorkload, line.hasPrefix("- ") {
                throw EphemeralSpecError.unsupportedCommandListShorthand
            }

            if inBeforeProvision, line.hasPrefix("- ") {
                try finishCurrentBeforeProvisionHook()
                currentBeforeProvisionHook = PartialEphemeralCommand(context: "beforeProvision hook")
                let remainder = String(line.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                if !remainder.isEmpty {
                    guard let (key, value) = parseYAMLKeyValue(remainder) else {
                        throw EphemeralSpecError.malformedLine(rawLine)
                    }
                    try setHookField(key: key, value: value, rawLine: rawLine)
                }
                continue
            }

            if inAfterStop, line.hasPrefix("- ") {
                try finishCurrentAfterStopHook()
                currentAfterStopHook = PartialEphemeralCommand(context: "afterStop hook")
                let remainder = String(line.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                if !remainder.isEmpty {
                    guard let (key, value) = parseYAMLKeyValue(remainder) else {
                        throw EphemeralSpecError.malformedLine(rawLine)
                    }
                    try setAfterStopHookField(key: key, value: value, rawLine: rawLine)
                }
                continue
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

            if inBeforeProvision {
                guard currentBeforeProvisionHook != nil else { throw EphemeralSpecError.malformedLine(rawLine) }
                try setHookField(key: key, value: value, rawLine: rawLine)
                continue
            }

            if inAfterStop {
                guard currentAfterStopHook != nil else { throw EphemeralSpecError.malformedLine(rawLine) }
                try setAfterStopHookField(key: key, value: value, rawLine: rawLine)
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
            case "beforeProvision":
                if value == "[]" { inBeforeProvision = false }
                else {
                    if isCommandListShorthand(value) { throw EphemeralSpecError.unsupportedCommandListShorthand }
                    guard value.isEmpty else { throw EphemeralSpecError.malformedLine(rawLine) }
                    inBeforeProvision = true
                }
            case "afterStop":
                if value == "[]" { inAfterStop = false }
                else {
                    if isCommandListShorthand(value) { throw EphemeralSpecError.unsupportedCommandListShorthand }
                    guard value.isEmpty else { throw EphemeralSpecError.malformedLine(rawLine) }
                    inAfterStop = true
                }
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
        try finishCurrentBeforeProvisionHook()
        try finishCurrentAfterStopHook()

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
            beforeProvisionHooks: beforeProvisionHooks,
            afterStopHooks: afterStopHooks,
            workload: try workload.buildIfPresent()
        )
    }
}

public struct EphemeralRunPlan: Equatable {
    public var namePrefix: String
    public var image: SandboxImage
    public var resourceProfile: ResourceProfile
    public var allowedFolders: [EphemeralAllowedFolderIntent]
    public var beforeProvisionHooks: [EphemeralHookIntent]
    public var afterStopHooks: [EphemeralHookIntent]
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
            beforeProvisionHooks: spec.beforeProvisionHooks,
            afterStopHooks: spec.afterStopHooks,
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

public struct EphemeralHookIntent: Equatable {
    public var command: WorkloadCommand
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
    var context: String

    func buildIfPresent() throws -> EphemeralWorkloadIntent? {
        guard command != nil || workdir != nil || !args.isEmpty else { return nil }
        return try buildRequired()
    }

    func buildRequired() throws -> EphemeralWorkloadIntent {
        let command = try requireYAMLValue(command, "\(context).command", missingError: EphemeralSpecError.missingField)
        guard !command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            if context == "workload" { throw EphemeralSpecError.emptyCommand }
            throw EphemeralSpecError.emptyHookCommand(context.replacingOccurrences(of: " hook", with: ""))
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
    case emptyHookCommand(String)
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
        case .emptyHookCommand(let phase): return "ephemeral \(phase) hook command cannot be empty"
        case .unsupportedCommandListShorthand: return "unsupported v1 ephemeral command-list shorthand"
        case .invalidNamePrefix(let value): return "invalid ephemeral namePrefix: \(value)"
        case .missingImplicitWorkdir: return "no read-write allowed folder is available for default workload workdir"
        }
    }
}
