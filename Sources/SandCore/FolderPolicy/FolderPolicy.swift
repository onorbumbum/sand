import Foundation

public struct FolderPolicy {
    private let resolvePath: @Sendable (String) -> String

    public init(resolvePath: @escaping @Sendable (String) -> String = FolderPolicy.defaultResolvePath) {
        self.resolvePath = resolvePath
    }

    public func canonicalAccessMode(from input: String) throws -> AccessMode {
        try AccessMode.parse(input)
    }

    public func defaultGuestPath(forDisplayHostPath displayHostPath: String) throws -> GuestPath {
        let name = URL(fileURLWithPath: displayHostPath).lastPathComponent
        return try GuestPath("/workspace/\(name)")
    }

    public func addFolder(
        to spec: SandboxSpec,
        displayHostPath: String,
        accessMode input: String,
        guestPath overrideGuestPath: GuestPath? = nil
    ) throws -> SandboxSpec {
        let mode = try canonicalAccessMode(from: input)
        let resolvedHostPath = resolvePath(displayHostPath)
        let guestPath = try overrideGuestPath ?? defaultGuestPath(forDisplayHostPath: displayHostPath)
        let newFolder = AllowedFolder(
            displayHostPath: displayHostPath,
            resolvedHostPath: resolvedHostPath,
            guestPath: guestPath,
            accessMode: mode
        )

        var updated = spec
        if let existingIndex = updated.allowedFolders.firstIndex(where: { $0.resolvedHostPath == resolvedHostPath }) {
            try validateNoDuplicateGuestPath(guestPath, resolvedHostPath: resolvedHostPath, in: updated.allowedFolders)
            updated.allowedFolders[existingIndex] = newFolder
            return updated
        }

        try validateNoDuplicateGuestPath(guestPath, resolvedHostPath: resolvedHostPath, in: updated.allowedFolders)
        try validateNoOverlappingHostFolders(resolvedHostPath, in: updated.allowedFolders)
        updated.allowedFolders.append(newFolder)
        return updated
    }

    public func removeFolder(from spec: SandboxSpec, displayHostPath: String) -> SandboxSpec {
        let resolvedHostPath = resolvePath(displayHostPath)
        var updated = spec
        updated.allowedFolders.removeAll { $0.resolvedHostPath == resolvedHostPath }
        return updated
    }

    private func validateNoDuplicateGuestPath(_ guestPath: GuestPath, resolvedHostPath: String, in existing: [AllowedFolder]) throws {
        if let duplicate = existing.first(where: { $0.guestPath == guestPath && $0.resolvedHostPath != resolvedHostPath }) {
            throw FolderPolicyError.duplicateGuestPath(duplicate.guestPath.rawValue)
        }
    }

    private func validateNoOverlappingHostFolders(_ resolvedHostPath: String, in existing: [AllowedFolder]) throws {
        for folder in existing {
            if pathsOverlap(resolvedHostPath, folder.resolvedHostPath) {
                throw FolderPolicyError.overlappingHostFolders(folder.resolvedHostPath, resolvedHostPath)
            }
        }
    }

    private func pathsOverlap(_ lhs: String, _ rhs: String) -> Bool {
        lhs == rhs || lhs.hasPrefix(rhs + "/") || rhs.hasPrefix(lhs + "/")
    }

    public static func defaultResolvePath(_ path: String) -> String {
        let expanded: String
        if path == "~" {
            expanded = FileManager.default.homeDirectoryForCurrentUser.path
        } else if path.hasPrefix("~/") {
            expanded = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(String(path.dropFirst(2))).path
        } else {
            expanded = path
        }
        return URL(fileURLWithPath: expanded).resolvingSymlinksInPath().standardizedFileURL.path
    }
}

public struct FolderListPresenter {
    public init() {}

    public func lines(for folders: [AllowedFolder]) -> [String] {
        var lines = ["Host Path\tGuest Path\tAccess Mode"]
        lines += folders.map { folder in
            "\(folder.displayHostPath)\t\(folder.guestPath.rawValue)\t\(folder.accessMode.rawValue)"
        }
        return lines
    }
}

public enum FolderPolicyError: Error, Equatable {
    case unsupportedAccessMode(String)
    case duplicateGuestPath(String)
    case overlappingHostFolders(String, String)
}
