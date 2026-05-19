public struct WorkingDirectoryMapper {
    private let fallbackGuestPath: GuestPath

    public init(fallbackGuestPath: GuestPath = try! GuestPath("/workspace")) {
        self.fallbackGuestPath = fallbackGuestPath
    }

    public func map(hostCurrentDirectory: String, spec: SandboxSpec) -> WorkingDirectoryMapping {
        for folder in spec.allowedFolders {
            if hostCurrentDirectory == folder.resolvedHostPath || hostCurrentDirectory.hasPrefix(folder.resolvedHostPath + "/") {
                let suffix = String(hostCurrentDirectory.dropFirst(folder.resolvedHostPath.count))
                return WorkingDirectoryMapping(
                    guestPath: try! GuestPath(folder.guestPath.rawValue + suffix),
                    warning: nil
                )
            }
        }

        return WorkingDirectoryMapping(
            guestPath: fallbackGuestPath,
            warning: "Current directory is not inside an Allowed Folder; starting in \(fallbackGuestPath.rawValue)."
        )
    }
}

public struct WorkingDirectoryMapping: Equatable {
    public var guestPath: GuestPath
    public var warning: String?

    public init(guestPath: GuestPath, warning: String?) {
        self.guestPath = guestPath
        self.warning = warning
    }
}
