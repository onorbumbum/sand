public struct BackendErrorTranslator {
    public init() {}

    public func message(for error: any Error) -> String {
        "Backend operation failed: \(String(describing: error))"
    }
}

public enum BackendTranslatedError: Error, Equatable {
    case serviceUnavailable(String)
    case runtimeMissing(String)
    case commandFailed(String)
}
