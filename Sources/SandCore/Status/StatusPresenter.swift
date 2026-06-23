/// Formats sandbox status information for display.
public struct StatusPresenter {
    public init() {}

    /// Creates a status view from the given parameters.
    public func present(name: SandboxName, spec: SandboxSpec, runtimeStatus: SandboxRuntimeStatus) -> SandboxStatusView {
        SandboxStatusView(
            name: name.rawValue,
            runtimeState: runtimeStatus.label,
            guestOS: spec.guestOS.rawValue,
            image: spec.image.reference,
            cpus: spec.resourceProfile.cpus,
            memory: spec.resourceProfile.memory.description,
            diskSize: spec.diskSize?.description,
            displayResolution: spec.displayResolution?.description,
            sharedFolderCount: spec.sharedFolders.count
        )
    }

    /// Formats a view as a single-line list entry.
    public func listLine(for view: SandboxStatusView) -> String {
        "\(view.name)\t\(view.runtimeState)\t\(view.guestOS)\t\(view.image)\t\(view.sharedFolderCount) folders"
    }

    /// Formats a view as multiple detail lines.
    public func detailLines(for view: SandboxStatusView) -> [String] {
        var lines = [
            "name: \(view.name)",
            "state: \(view.runtimeState)",
            "os: \(view.guestOS)",
            "image: \(view.image)",
            "resources: \(view.cpus) CPUs, \(view.memory) memory"
        ]
        if let diskSize = view.diskSize {
            lines.append("disk: \(diskSize)")
        }
        if let displayResolution = view.displayResolution {
            lines.append("display: \(displayResolution)")
        }
        lines.append("sharedFolders: \(view.sharedFolderCount)")
        return lines
    }
}

/// A formatted view of sandbox status.
public struct SandboxStatusView: Equatable {
    public var name: String
    public var runtimeState: String
    public var guestOS: String
    public var image: String
    public var cpus: Int
    public var memory: String
    public var diskSize: String?
    public var displayResolution: String?
    public var sharedFolderCount: Int

    public init(name: String, runtimeState: String, guestOS: String, image: String, cpus: Int, memory: String, diskSize: String? = nil, displayResolution: String? = nil, sharedFolderCount: Int) {
        self.name = name
        self.runtimeState = runtimeState
        self.guestOS = guestOS
        self.image = image
        self.cpus = cpus
        self.memory = memory
        self.diskSize = diskSize
        self.displayResolution = displayResolution
        self.sharedFolderCount = sharedFolderCount
    }
}

// Provides human-readable labels for runtime status.
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
