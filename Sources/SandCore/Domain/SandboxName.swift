import Foundation

/// A validated sandbox identifier.
///
/// Ensures names match the pattern: alphanumeric first character,
/// followed by alphanumeric, underscores, or hyphens.
public struct SandboxName: Equatable, Hashable, Sendable {
    public let rawValue: String

    /// Initializes a sandbox name after validating the format.
    public init(_ rawValue: String) throws {
        guard !rawValue.isEmpty else {
            throw SandboxNameError.empty
        }
        guard rawValue.range(of: #"^[A-Za-z0-9][A-Za-z0-9_-]*$"#, options: .regularExpression) != nil else {
            throw SandboxNameError.invalidCharacters(rawValue)
        }
        self.rawValue = rawValue
    }
}

/// Errors that can occur when creating a SandboxName.
public enum SandboxNameError: Error, Equatable {
    /// Raised when the name is an empty string.
    case empty

    /// Raised when the name contains invalid characters.
    case invalidCharacters(String)
}