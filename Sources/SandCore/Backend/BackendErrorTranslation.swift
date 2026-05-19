public struct BackendErrorTranslator {
    public init() {}

    public func translate(_ error: any Error) -> BackendTranslatedError {
        if let translated = error as? BackendTranslatedError {
            return translated
        }
        if let backendError = error as? AppleContainerCLIBackendError {
            return translate(backendError)
        }
        return .commandFailed("Sandbox backend operation failed. Run `sand doctor` and retry.")
    }

    public func translate(_ error: AppleContainerCLIBackendError) -> BackendTranslatedError {
        switch error {
        case .commandFailed(let arguments, _, let stderr):
            return translateCommandFailure(arguments: arguments, stderr: stderr)
        }
    }

    public func message(for error: any Error) -> String {
        String(describing: translate(error))
    }

    private func translateCommandFailure(arguments: [String], stderr: String) -> BackendTranslatedError {
        let lowercasedDetail = stderr.lowercased()

        if backendServiceLooksUnavailable(lowercasedDetail) {
            return .serviceUnavailable("Sandbox backend service is not available. Run `sand doctor` to repair prerequisites, then retry.")
        }

        if runtimeLooksMissing(arguments: arguments, lowercasedDetail: lowercasedDetail), let name = sandboxName(from: arguments) {
            return .runtimeMissing(missingRuntimeMessage(for: name, arguments: arguments))
        }

        if imageLooksMissing(arguments: arguments, lowercasedDetail: lowercasedDetail), let image = imageReference(fromCreateArguments: arguments) {
            return .commandFailed("Sandbox image `\(image)` is not available. Build or pull the image, then retry.")
        }

        return .commandFailed("Could not \(operationDescription(for: arguments)). Run `sand doctor` and retry.")
    }

    private func backendServiceLooksUnavailable(_ lowercasedDetail: String) -> Bool {
        (lowercasedDetail.contains("service") || lowercasedDetail.contains("daemon") || lowercasedDetail.contains("apiserver"))
            && (lowercasedDetail.contains("not running") || lowercasedDetail.contains("unavailable") || lowercasedDetail.contains("connect") || lowercasedDetail.contains("refused"))
    }

    private func runtimeLooksMissing(arguments: [String], lowercasedDetail: String) -> Bool {
        guard ["logs", "start", "stop", "inspect", "delete"].contains(arguments.first ?? "") else { return false }
        return lowercasedDetail.contains("notfound") || lowercasedDetail.contains("not found") || lowercasedDetail.contains("no such")
    }

    private func imageLooksMissing(arguments: [String], lowercasedDetail: String) -> Bool {
        arguments.first == "create" && lowercasedDetail.contains("image") && lowercasedDetail.contains("not found")
    }

    private func sandboxName(from arguments: [String]) -> String? {
        switch arguments.first {
        case "logs", "start", "stop", "inspect":
            return arguments.dropFirst().first
        case "delete":
            return arguments.last
        default:
            return nil
        }
    }

    private func missingRuntimeMessage(for name: String, arguments: [String]) -> String {
        switch arguments.first {
        case "logs":
            return "Sandbox VM `\(name)` was not found. Create it with `sand create \(name)` before reading logs."
        case "start":
            return "Sandbox VM `\(name)` was not found. Create it with `sand create \(name)` before starting it."
        case "stop":
            return "Sandbox VM `\(name)` was not found. Nothing was stopped."
        case "delete":
            return "Sandbox VM `\(name)` was not found. Nothing was deleted."
        default:
            return "Sandbox VM `\(name)` was not found. Create it with `sand create \(name)` first."
        }
    }

    private func imageReference(fromCreateArguments arguments: [String]) -> String? {
        guard arguments.count >= 4, arguments.first == "create" else { return nil }
        return arguments.dropLast(2).last
    }

    private func operationDescription(for arguments: [String]) -> String {
        switch arguments.first {
        case "logs":
            return "read Sandbox VM logs"
        case "start":
            return "start the Sandbox VM"
        case "stop":
            return "stop the Sandbox VM"
        case "inspect":
            return "read Sandbox VM status"
        case "delete":
            return "delete the Sandbox VM"
        case "create":
            return "create the Sandbox VM"
        case "volume":
            return "prepare Sandbox VM persistent state"
        default:
            return "complete the Sandbox backend operation"
        }
    }
}

public enum BackendTranslatedError: Error, Equatable, CustomStringConvertible {
    case serviceUnavailable(String)
    case runtimeMissing(String)
    case commandFailed(String)

    public var description: String {
        switch self {
        case .serviceUnavailable(let message), .runtimeMissing(let message), .commandFailed(let message):
            return message
        }
    }
}
