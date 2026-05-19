import Foundation

public struct WorkingDirectoryMapper {
    private let fallbackGuestPath: GuestPath
    private let resolvePath: @Sendable (String) -> String

    public init(
        fallbackGuestPath: GuestPath = try! GuestPath("/workspace"),
        resolvePath: @escaping @Sendable (String) -> String = WorkingDirectoryMapper.defaultResolvePath
    ) {
        self.fallbackGuestPath = fallbackGuestPath
        self.resolvePath = resolvePath
    }

    public func map(hostCurrentDirectory: String, spec: SandboxSpec) -> WorkingDirectoryMapping {
        let resolvedCurrentDirectory = resolvePath(hostCurrentDirectory)
        for folder in spec.allowedFolders {
            if resolvedCurrentDirectory == folder.resolvedHostPath || resolvedCurrentDirectory.hasPrefix(folder.resolvedHostPath + "/") {
                let suffix = String(resolvedCurrentDirectory.dropFirst(folder.resolvedHostPath.count))
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

    public static func defaultResolvePath(_ path: String) -> String {
        URL(fileURLWithPath: path).resolvingSymlinksInPath().standardizedFileURL.path
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
