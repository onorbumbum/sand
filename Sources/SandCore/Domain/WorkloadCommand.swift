/// A command to execute inside a sandbox VM.
///
/// Contains the command arguments that will be run.
public struct WorkloadCommand: Equatable, Sendable {
    public let arguments: [String]

    /// Initializes a workload command with the given arguments.
    public init(arguments: [String]) throws {
        guard !arguments.isEmpty else {
            throw WorkloadCommandError.empty
        }
        self.arguments = arguments
    }
}

/// Errors that can occur when creating a WorkloadCommand.
public enum WorkloadCommandError: Error, Equatable {
    /// Raised when no arguments are provided.
    case empty
}