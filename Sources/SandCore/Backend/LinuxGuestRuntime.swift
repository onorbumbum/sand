import Foundation

/// What every Linux Sandbox VM runtime needs, whatever the container engine:
/// the Guest State volume, Shared Folder mounts, the guest's main process,
/// and (for browser sandboxes) the loopback-only noVNC publish.
enum LinuxGuestRuntime {
    static let browserStartupScript = "/usr/local/bin/sand-browser-up"

    static func guestStateVolumeName(for sandboxName: SandboxName) -> String {
        "sand-state-\(sandboxName.rawValue)"
    }

    static func mountArgument(for folder: SharedFolder) -> String {
        var argument = "type=bind,source=\(folder.resolvedHostPath),target=\(folder.guestPath.rawValue)"
        if folder.accessMode == .readOnly {
            argument += ",readonly"
        }
        return argument
    }

    /// Publishes the guest noVNC view on the Host Mac loopback only. Chromium's
    /// DevTools port is never published: agents reach it from inside the guest.
    static func browserPublishArguments(for spec: SandboxSpec) -> [String] {
        guard let browser = spec.browser else { return [] }
        return ["--publish", "127.0.0.1:\(browser.viewPort):\(BrowserSettings.guestViewPort)"]
    }

    /// The guest's main process: prepare Guest State, then idle, or keep the
    /// browser stack running for browser sandboxes.
    static func mainCommand(for spec: SandboxSpec) -> [String] {
        let keepAlive = spec.browser == nil ? "exec sleep infinity" : "exec \(browserStartupScript)"
        return [
            "/bin/bash",
            "-lc",
            "sudo -n mkdir -p /state/sandbox/.pi /state/sandbox/secrets && sudo -n chown -R sandbox:sandbox /state/sandbox && \(keepAlive)"
        ]
    }
}

/// Which engine runs Linux Sandbox VMs on this Host Mac.
public enum LinuxBackendKind: String, Equatable {
    /// Apple `container` (Apple silicon, macOS 26).
    case appleContainer = "apple-container"
    /// Any Docker-compatible engine, e.g. colima on Intel Macs.
    case docker

    public static let environmentKey = "SAND_LINUX_BACKEND"

    public static func select(environment: [String: String], isAppleSilicon: Bool) -> LinuxBackendKind {
        if let override = environment[environmentKey], let kind = LinuxBackendKind(rawValue: override) {
            return kind
        }
        return isAppleSilicon ? .appleContainer : .docker
    }

    /// The engine for this Host Mac and process environment.
    public static var forThisHost: LinuxBackendKind {
        select(environment: ProcessInfo.processInfo.environment, isAppleSilicon: hostIsAppleSilicon)
    }

    public static var hostIsAppleSilicon: Bool {
        #if arch(arm64)
        return true
        #else
        return false
        #endif
    }
}
