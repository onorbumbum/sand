public struct SandboxName: Equatable, Hashable, Sendable {
    public let rawValue: String

    public init(_ rawValue: String) throws {
        guard !rawValue.isEmpty else {
            throw SandboxNameError.empty
        }
        self.rawValue = rawValue
    }
}

public enum SandboxNameError: Error, Equatable {
    case empty
}
