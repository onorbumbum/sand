import Foundation

public struct FolderPolicy {
    public init() {}

    public func canonicalAccessMode(from input: String) throws -> AccessMode {
        switch input {
        case "rw", "read-write":
            return .readWrite
        case "ro", "read-only":
            return .readOnly
        default:
            throw FolderPolicyError.unsupportedAccessMode(input)
        }
    }

    public func defaultGuestPath(forDisplayHostPath displayHostPath: String) throws -> GuestPath {
        let name = URL(fileURLWithPath: displayHostPath).lastPathComponent
        return try GuestPath("/workspace/\(name)")
    }
}

public enum FolderPolicyError: Error, Equatable {
    case unsupportedAccessMode(String)
    case duplicateGuestPath(String)
    case overlappingHostFolders(String, String)
}
