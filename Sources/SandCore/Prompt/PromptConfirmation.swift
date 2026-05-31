import Foundation

/// Prompts the user for confirmation before proceeding.
public protocol PromptConfirmation {
    func confirm(_ request: ConfirmationRequest) throws -> ConfirmationDecision
}

/// A request for user confirmation.
public struct ConfirmationRequest: Equatable {
    public var message: String
    public var destructive: Bool

    public init(message: String, destructive: Bool) {
        self.message = message
        self.destructive = destructive
    }
}

/// The user's response to a confirmation request.
public enum ConfirmationDecision: Equatable {
    case proceed
    case cancel
}

/// Prompts for confirmation via standard input.
///
/// Reads user input from stdin. Requires "yes" for destructive actions,
/// or "y"/"yes" for non-destructive ones.
public struct StandardInputPromptConfirmation: PromptConfirmation {
    private let readResponse: () -> String?
    private let writePrompt: (String) -> Void

    public init(
        readResponse: @escaping () -> String? = { Swift.readLine() },
        writePrompt: @escaping (String) -> Void = { text in
            FileHandle.standardError.write(Data(text.utf8))
        }
    ) {
        self.readResponse = readResponse
        self.writePrompt = writePrompt
    }

    public func confirm(_ request: ConfirmationRequest) throws -> ConfirmationDecision {
        if request.destructive {
            writePrompt("\(request.message) Type 'yes' to continue: ")
            return normalizedResponse() == "yes" ? .proceed : .cancel
        }

        writePrompt("\(request.message) Proceed? [y/N] ")
        let response = normalizedResponse()
        return response == "y" || response == "yes" ? .proceed : .cancel
    }

    // Normalizes user input for comparison.
    private func normalizedResponse() -> String {
        (readResponse() ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}