public struct StatusPresenter {
    public init() {}

    public func present(name: SandboxName, spec: SandboxSpec, runtimeStatus: SandboxRuntimeStatus) -> SandboxStatusView {
        SandboxStatusView(
            name: name.rawValue,
            runtimeState: runtimeStatus.label,
            image: spec.image.reference,
            cpus: spec.resourceProfile.cpus,
            memory: spec.resourceProfile.memory.description,
            allowedFolderCount: spec.allowedFolders.count
        )
    }

    public func listLine(for view: SandboxStatusView) -> String {
        "\(view.name)\t\(view.runtimeState)\t\(view.image)\t\(view.allowedFolderCount) folders"
    }

    public func detailLines(for view: SandboxStatusView) -> [String] {
        [
            "name: \(view.name)",
            "state: \(view.runtimeState)",
            "image: \(view.image)",
            "resources: \(view.cpus) CPUs, \(view.memory) memory",
            "allowedFolders: \(view.allowedFolderCount)"
        ]
    }
}

public struct SandboxStatusView: Equatable {
    public var name: String
    public var runtimeState: String
    public var image: String
    public var cpus: Int
    public var memory: String
    public var allowedFolderCount: Int

    public init(name: String, runtimeState: String, image: String, cpus: Int, memory: String, allowedFolderCount: Int) {
        self.name = name
        self.runtimeState = runtimeState
        self.image = image
        self.cpus = cpus
        self.memory = memory
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
