public struct StatusPresenter {
    public init() {}

    public func present(name: SandboxName, spec: SandboxSpec, runtimeStatus: SandboxRuntimeStatus) -> SandboxStatusView {
        SandboxStatusView(
            name: name.rawValue,
            runtimeState: runtimeStatus.label,
            image: spec.image.reference,
            allowedFolderCount: spec.allowedFolders.count
        )
    }
}

public struct SandboxStatusView: Equatable {
    public var name: String
    public var runtimeState: String
    public var image: String
    public var allowedFolderCount: Int

    public init(name: String, runtimeState: String, image: String, allowedFolderCount: Int) {
        self.name = name
        self.runtimeState = runtimeState
        self.image = image
        self.allowedFolderCount = allowedFolderCount
    }
}

private extension SandboxRuntimeStatus {
    var label: String {
        switch self {
        case .missing:
            return "missing"
        case .stopped:
            return "stopped"
        case .running:
            return "running"
        }
    }
}
