public struct SandboxSpec: Equatable, Sendable {
    public var name: SandboxName
    public var image: SandboxImage
    public var resourceProfile: ResourceProfile
    public var allowedFolders: [AllowedFolder]

    public init(
        name: SandboxName,
        image: SandboxImage = .developerReadyDefault,
        resourceProfile: ResourceProfile = .default,
        allowedFolders: [AllowedFolder] = []
    ) {
        self.name = name
        self.image = image
        self.resourceProfile = resourceProfile
        self.allowedFolders = allowedFolders
    }
}

public struct SandboxImage: Equatable, Sendable {
    public var reference: String

    public init(reference: String) {
        self.reference = reference
    }

    public static let developerReadyDefault = SandboxImage(reference: "sand/developer-ready:ubuntu-lts")
}

public struct ResourceProfile: Equatable, Sendable {
    public var cpus: Int
    public var memory: MemorySize

    public init(cpus: Int, memory: MemorySize) {
        self.cpus = cpus
        self.memory = memory
    }

    public static let `default` = ResourceProfile(cpus: 4, memory: MemorySize(gigabytes: 8))
}

public struct MemorySize: Equatable, Sendable {
    public var megabytes: Int

    public init(megabytes: Int) {
        self.megabytes = megabytes
    }

    public init(gigabytes: Int) {
        self.megabytes = gigabytes * 1024
    }
}

public struct AllowedFolder: Equatable, Sendable {
    public var displayHostPath: String
    public var resolvedHostPath: String
    public var guestPath: GuestPath
    public var accessMode: AccessMode

    public init(displayHostPath: String, resolvedHostPath: String, guestPath: GuestPath, accessMode: AccessMode) {
        self.displayHostPath = displayHostPath
        self.resolvedHostPath = resolvedHostPath
        self.guestPath = guestPath
        self.accessMode = accessMode
    }
}

public struct GuestPath: Equatable, Hashable, Sendable {
    public var rawValue: String

    public init(_ rawValue: String) throws {
        guard rawValue.hasPrefix("/") else {
            throw GuestPathError.mustBeAbsolute
        }
        self.rawValue = rawValue
    }
}

public enum GuestPathError: Error, Equatable {
    case mustBeAbsolute
}

public enum AccessMode: String, Equatable, Sendable {
    case readOnly = "read-only"
    case readWrite = "read-write"
}
