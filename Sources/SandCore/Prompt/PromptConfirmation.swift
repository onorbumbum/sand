import Foundation

public protocol PromptConfirmation {
    func confirm(_ request: ConfirmationRequest) throws -> ConfirmationDecision
}

public struct ConfirmationRequest: Equatable {
    public var message: String
    public var destructive: Bool

    public init(message: String, destructive: Bool) {
        self.message = message
        self.destructive = destructive
    }
}

public enum ConfirmationDecision: Equatable {
    case proceed
    case cancel
}

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

    private func normalizedResponse() -> String {
        (readResponse() ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
