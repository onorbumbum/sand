import Foundation

public struct SandboxName: Equatable, Hashable, Sendable {
    public let rawValue: String

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

public enum SandboxNameError: Error, Equatable {
    case empty
    case invalidCharacters(String)
}
