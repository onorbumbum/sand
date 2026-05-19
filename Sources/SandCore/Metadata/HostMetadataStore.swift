import Darwin
import Foundation

public protocol HostMetadataStore {
    func createSpec(_ spec: SandboxSpec) throws
    func readSpec(named name: SandboxName) throws -> SandboxSpec
    func writeSpec(_ spec: SandboxSpec) throws
    func deleteSpec(named name: SandboxName) throws
    func listSpecs() throws -> [SandboxSpec]
    func currentHostDirectory() -> String
    func schemaVersion() throws -> Int
    func checkWritability() throws
    func withLifecycleMutationLock<T>(_ operation: () throws -> T) throws -> T
}

public enum HostMetadataError: Error, Equatable, CustomStringConvertible {
    case specNotFound(String)
    case duplicateSandboxName(String)
    case unsupportedSchemaVersion(Int)

    public var description: String {
        switch self {
        case .specNotFound(let name): return "sandbox not found: \(name)"
        case .duplicateSandboxName(let name): return "sandbox already exists: \(name)"
        case .unsupportedSchemaVersion(let version): return "unsupported host metadata schema version: \(version)"
        }
    }
}

public final class FileHostMetadataStore: HostMetadataStore {
    private let root: URL
    private let fileManager: FileManager
    private let lock = NSLock()

    public init(root: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".sand"), fileManager: FileManager = .default) {
        self.root = root
        self.fileManager = fileManager
    }

    public func createSpec(_ spec: SandboxSpec) throws {
        if try specExists(named: spec.name) {
            throw HostMetadataError.duplicateSandboxName(spec.name.rawValue)
        }
        try writeSpec(spec)
    }

    public func readSpec(named name: SandboxName) throws -> SandboxSpec {
        let url = specURL(for: name)
        guard fileManager.fileExists(atPath: url.path) else {
            throw HostMetadataError.specNotFound(name.rawValue)
        }
        let text = try String(contentsOf: url, encoding: .utf8)
        return try SandboxSpec.parseYAML(text)
    }

    public func writeSpec(_ spec: SandboxSpec) throws {
        try spec.validateV1()
        try ensureDirectories()
        let destination = specURL(for: spec.name)
        let temporary = specsDirectory().appendingPathComponent(".\(spec.name.rawValue).yaml.tmp")
        try spec.renderedYAML().write(to: temporary, atomically: true, encoding: .utf8)
        if fileManager.fileExists(atPath: destination.path) {
            _ = try fileManager.replaceItemAt(destination, withItemAt: temporary, backupItemName: nil, options: [])
        } else {
            try fileManager.moveItem(at: temporary, to: destination)
        }
    }

    public func deleteSpec(named name: SandboxName) throws {
        let url = specURL(for: name)
        guard fileManager.fileExists(atPath: url.path) else { return }
        try fileManager.removeItem(at: url)
    }

    public func listSpecs() throws -> [SandboxSpec] {
        let directory = specsDirectory()
        guard fileManager.fileExists(atPath: directory.path) else { return [] }
        return try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "yaml" }
            .map { try SandboxSpec.parseYAML(String(contentsOf: $0, encoding: .utf8)) }
            .sorted { $0.name.rawValue < $1.name.rawValue }
    }

    public func currentHostDirectory() -> String {
        fileManager.currentDirectoryPath
    }

    public func schemaVersion() throws -> Int {
        try ensureDirectories()
        let url = root.appendingPathComponent("schema-version")
        if !fileManager.fileExists(atPath: url.path) {
            try "\(SandboxSpec.supportedSchemaVersion)\n".write(to: url, atomically: true, encoding: .utf8)
            return SandboxSpec.supportedSchemaVersion
        }
        let raw = try String(contentsOf: url, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
        let version = Int(raw) ?? -1
        guard version == SandboxSpec.supportedSchemaVersion else {
            throw HostMetadataError.unsupportedSchemaVersion(version)
        }
        return version
    }

    public func checkWritability() throws {
        try ensureDirectories()
        let probe = root.appendingPathComponent(".doctor-writability-\(UUID().uuidString)")
        try "ok\n".write(to: probe, atomically: true, encoding: .utf8)
        try fileManager.removeItem(at: probe)
    }

    public func withLifecycleMutationLock<T>(_ operation: () throws -> T) throws -> T {
        lock.lock()
        defer { lock.unlock() }

        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        let lockFileDescriptor = try openLifecycleLockFile()
        defer { close(lockFileDescriptor) }
        try acquireLifecycleLock(lockFileDescriptor)
        defer { flock(lockFileDescriptor, LOCK_UN) }

        return try operation()
    }

    private func openLifecycleLockFile() throws -> Int32 {
        let descriptor = open(root.appendingPathComponent("lifecycle.lock").path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard descriptor != -1 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        return descriptor
    }

    private func acquireLifecycleLock(_ descriptor: Int32) throws {
        while flock(descriptor, LOCK_EX) == -1 {
            guard errno == EINTR else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        }
    }

    private func ensureDirectories() throws {
        try fileManager.createDirectory(at: specsDirectory(), withIntermediateDirectories: true)
        _ = try schemaVersionIfPresentOrCreate()
    }

    private func schemaVersionIfPresentOrCreate() throws -> Int {
        let url = root.appendingPathComponent("schema-version")
        if !fileManager.fileExists(atPath: url.path) {
            try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
            try "\(SandboxSpec.supportedSchemaVersion)\n".write(to: url, atomically: true, encoding: .utf8)
            return SandboxSpec.supportedSchemaVersion
        }
        let raw = try String(contentsOf: url, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
        let version = Int(raw) ?? -1
        guard version == SandboxSpec.supportedSchemaVersion else {
            throw HostMetadataError.unsupportedSchemaVersion(version)
        }
        return version
    }

    private func specExists(named name: SandboxName) throws -> Bool {
        fileManager.fileExists(atPath: specURL(for: name).path)
    }

    private func specsDirectory() -> URL {
        root.appendingPathComponent("specs", isDirectory: true)
    }

    private func specURL(for name: SandboxName) -> URL {
        specsDirectory().appendingPathComponent("\(name.rawValue).yaml")
    }
}
