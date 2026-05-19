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
