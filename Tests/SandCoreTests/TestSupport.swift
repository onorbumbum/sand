import Foundation
@testable import SandCore

final class MemoryMetadataStore: HostMetadataStore {
    private var specsByName: [String: SandboxSpec]
    private let hostDirectory: String
    private let writable: Bool
    private let lock = NSLock()
    var lockEvents: [String] = []

    init(specs: [SandboxSpec] = [], currentHostDirectory: String = "/workspace", writable: Bool = true) {
        self.specsByName = Dictionary(uniqueKeysWithValues: specs.map { ($0.name.rawValue, $0) })
        self.hostDirectory = currentHostDirectory
        self.writable = writable
    }

    func createSpec(_ spec: SandboxSpec) throws {
        if specsByName[spec.name.rawValue] != nil {
            throw HostMetadataError.duplicateSandboxName(spec.name.rawValue)
        }
        specsByName[spec.name.rawValue] = spec
    }

    func readSpec(named name: SandboxName) throws -> SandboxSpec {
        guard let spec = specsByName[name.rawValue] else {
            throw HostMetadataError.specNotFound(name.rawValue)
        }
        return spec
    }

    func writeSpec(_ spec: SandboxSpec) throws {
        specsByName[spec.name.rawValue] = spec
    }

    func deleteSpec(named name: SandboxName) throws {
        specsByName.removeValue(forKey: name.rawValue)
    }

    func listSpecs() throws -> [SandboxSpec] {
        Array(specsByName.values).sorted { $0.name.rawValue < $1.name.rawValue }
    }

    func currentHostDirectory() -> String {
        hostDirectory
    }

    func schemaVersion() throws -> Int {
        SandboxSpec.supportedSchemaVersion
    }

    func checkWritability() throws {
        if !writable {
            throw CocoaError(.fileWriteNoPermission)
        }
    }

    func withLifecycleMutationLock<T>(_ operation: () throws -> T) throws -> T {
        lock.lock()
        lockEvents.append("enter")
        defer {
            lockEvents.append("exit")
            lock.unlock()
        }
        return try operation()
    }
}

final class RecordingSandboxBackend: SandboxBackend {
    var calls: [BackendCall] = []
    var runtimeStatus: SandboxRuntimeStatus
    var provisionError: (any Error)?

    init(status: SandboxRuntimeStatus = .running, provisionError: (any Error)? = nil) {
        self.runtimeStatus = status
        self.provisionError = provisionError
    }

    func checkReadiness() throws -> BackendReadiness {
        calls.append(.checkReadiness)
        return .ready
    }

    func provision(_ spec: SandboxSpec) throws {
        calls.append(.provision(spec.name.rawValue))
        if let provisionError = provisionError { throw provisionError }
        runtimeStatus = .stopped
    }

    func apply(_ spec: SandboxSpec) throws {
        calls.append(.apply(spec.name.rawValue))
    }

    func start(_ sandboxName: SandboxName) throws {
        calls.append(.start(sandboxName.rawValue))
        runtimeStatus = .running
    }

    func stop(_ sandboxName: SandboxName) throws {
        calls.append(.stop(sandboxName.rawValue))
        runtimeStatus = .stopped
    }

    func run(_ request: BackendRunRequest) throws -> CommandResult {
        calls.append(.run(request.sandboxName.rawValue, request.command.arguments, request.workingDirectory.rawValue))
        return .success
    }

    func shell(_ request: BackendShellRequest) throws -> CommandResult {
        calls.append(.shell(request.sandboxName.rawValue, request.workingDirectory.rawValue))
        return .success
    }

    func status(_ sandboxName: SandboxName) throws -> SandboxRuntimeStatus {
        calls.append(.status(sandboxName.rawValue))
        return runtimeStatus
    }

    func logs(_ sandboxName: SandboxName) throws -> SandboxLogs {
        calls.append(.logs(sandboxName.rawValue))
        return SandboxLogs(text: "")
    }

    func delete(_ sandboxName: SandboxName) throws {
        calls.append(.delete(sandboxName.rawValue))
        runtimeStatus = .missing
    }
}

enum BackendTestError: Error, Equatable {
    case provisionFailed
}

enum BackendCall: Equatable {
    case checkReadiness
    case provision(String)
    case apply(String)
    case start(String)
    case stop(String)
    case run(String, [String], String)
    case shell(String, String)
    case status(String)
    case logs(String)
    case delete(String)
}

final class RecordingPromptConfirmation: PromptConfirmation {
    var decisions: [ConfirmationDecision]
    var requests: [ConfirmationRequest] = []

    init(decisions: [ConfirmationDecision] = [.proceed]) {
        self.decisions = decisions
    }

    func confirm(_ request: ConfirmationRequest) throws -> ConfirmationDecision {
        requests.append(request)
        if decisions.isEmpty { return .proceed }
        return decisions.removeFirst()
    }
}
