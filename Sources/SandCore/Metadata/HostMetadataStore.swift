import Foundation

public protocol HostMetadataStore {
    func readSpec(named name: SandboxName) throws -> SandboxSpec
    func writeSpec(_ spec: SandboxSpec) throws
    func deleteSpec(named name: SandboxName) throws
    func listSpecs() throws -> [SandboxSpec]
    func currentHostDirectory() -> String
}

public enum HostMetadataError: Error, Equatable {
    case specNotFound(String)
}

public struct FileHostMetadataStore: HostMetadataStore {
    private let root: URL
    private let fileManager: FileManager

    public init(root: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".sand"), fileManager: FileManager = .default) {
        self.root = root
        self.fileManager = fileManager
    }

    public func readSpec(named name: SandboxName) throws -> SandboxSpec {
        // Full YAML persistence arrives in the spec slice. This scaffold keeps the boundary explicit.
        throw HostMetadataError.specNotFound(name.rawValue)
    }

    public func writeSpec(_ spec: SandboxSpec) throws {
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
    }

    public func deleteSpec(named name: SandboxName) throws {}

    public func listSpecs() throws -> [SandboxSpec] {
        []
    }

    public func currentHostDirectory() -> String {
        fileManager.currentDirectoryPath
    }
}
