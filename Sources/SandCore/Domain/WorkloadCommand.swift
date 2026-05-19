public struct WorkloadCommand: Equatable, Sendable {
    public let arguments: [String]

    public init(arguments: [String]) throws {
        guard !arguments.isEmpty else {
            throw WorkloadCommandError.empty
        }
        self.arguments = arguments
    }
}

public enum WorkloadCommandError: Error, Equatable {
    case empty
}
