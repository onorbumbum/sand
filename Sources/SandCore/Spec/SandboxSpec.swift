import Foundation

/// The specification for a sandbox VM.
///
/// Contains configuration including name, image, resources,
/// and shared host folders.
public struct SandboxSpec: Equatable, Sendable {
    public static let supportedSchemaVersion = 1

    public var schemaVersion: Int
    public var name: SandboxName
    public var image: SandboxImage
    public var guestOS: GuestOS
    public var resourceProfile: ResourceProfile
    public var diskSize: DiskSize?
    public var bootstrapState: BootstrapState
    public var sharedFolders: [SharedFolder]

    public init(
        schemaVersion: Int = SandboxSpec.supportedSchemaVersion,
        name: SandboxName,
        image: SandboxImage = .developerReadyDefault,
        guestOS: GuestOS = .linux,
        resourceProfile: ResourceProfile? = nil,
        diskSize: DiskSize? = nil,
        bootstrapState: BootstrapState = .ready,
        sharedFolders: [SharedFolder] = []
    ) {
        self.schemaVersion = schemaVersion
        self.name = name
        self.image = image
        self.guestOS = guestOS
        self.resourceProfile = resourceProfile ?? ResourceProfile.default(for: guestOS)
        self.diskSize = diskSize ?? DiskSize.default(for: guestOS)
        self.bootstrapState = bootstrapState
        self.sharedFolders = sharedFolders
    }

    /// Creates a spec with default settings.
    public static func generated(name: SandboxName, image: SandboxImage = .developerReadyDefault, guestOS: GuestOS = .linux, resourceProfile: ResourceProfile? = nil, diskSize: DiskSize? = nil, bootstrapState: BootstrapState = .ready) -> SandboxSpec {
        SandboxSpec(name: name, image: image, guestOS: guestOS, resourceProfile: resourceProfile ?? ResourceProfile.default(for: guestOS), diskSize: diskSize, bootstrapState: bootstrapState, sharedFolders: [])
    }

    public func validateV1() throws {
        guard schemaVersion == SandboxSpec.supportedSchemaVersion else {
            throw SandboxSpecError.unsupportedSchemaVersion(schemaVersion)
        }
        if guestOS == .linux, diskSize != nil {
            throw SandboxSpecError.diskUnsupportedForGuestOS(guestOS)
        }
    }

    public func validateUpdate(from existing: SandboxSpec) throws {
        if image != existing.image {
            throw SandboxSpecError.imageImmutable
        }
        if guestOS != existing.guestOS {
            throw SandboxSpecError.guestOSImmutable
        }
        if resourceProfile.cpus != existing.resourceProfile.cpus {
            throw SandboxSpecError.resourceProfileImmutable(field: "cpus")
        }
        if resourceProfile.memory != existing.resourceProfile.memory {
            throw SandboxSpecError.resourceProfileImmutable(field: "memory")
        }
        if diskSize != existing.diskSize {
            throw SandboxSpecError.diskSizeImmutable
        }
    }

    public func validateLocalClone(from source: SandboxSpec) throws {
        guard guestOS == .macOS, source.guestOS == .macOS else {
            throw SandboxSpecError.localCloneRequiresMacOS
        }
        if let requested = diskSize, let sourceDisk = source.diskSize, requested.gigabytes < sourceDisk.gigabytes {
            throw SandboxSpecError.cloneDiskTooSmall(source: sourceDisk, requested: requested)
        }
    }

    /// Renders the spec as YAML for storage.
    public func renderedYAML() -> String {
        var lines: [String] = []
        lines.append("schemaVersion: \(schemaVersion)")
        lines.append("name: \(name.rawValue)")
        lines.append("image: \(image.reference)")
        lines.append("os: \(guestOS.rawValue)")
        if bootstrapState != .ready {
            lines.append("bootstrap: \(bootstrapState.rawValue)")
        }
        if let diskSize {
            lines.append("disk: \(diskSize.description)")
        }
        lines.append("resources:")
        lines.append("  cpus: \(resourceProfile.cpus)")
        lines.append("  memory: \(resourceProfile.memory.description)")
        lines.append("sharedFolders:")
        if sharedFolders.isEmpty {
            lines.append("  []")
        } else {
            for folder in sharedFolders {
                lines.append("  - hostPath: \(folder.displayHostPath)")
                lines.append("    resolvedHostPath: \(folder.resolvedHostPath)")
                lines.append("    guestPath: \(folder.guestPath.rawValue)")
                lines.append("    accessMode: \(folder.accessMode.rawValue)")
            }
        }
        return lines.joined(separator: "\n") + "\n"
    }

    /// Parses a spec from YAML text.
    public static func parseYAML(_ text: String) throws -> SandboxSpec {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var schemaVersion: Int?
        var name: SandboxName?
        var image: SandboxImage?
        var guestOS: GuestOS?
        var cpus: Int?
        var memory: MemorySize?
        var diskSize: DiskSize?
        var bootstrapState: BootstrapState = .ready
        var sharedFolders: [SharedFolder] = []
        var inResources = false
        var inSharedFolders = false
        var currentFolder: PartialSharedFolder?

        func finishCurrentFolder() throws {
            if let folder = currentFolder {
                sharedFolders.append(try folder.build())
                currentFolder = nil
            }
        }

        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { continue }

            if !rawLine.hasPrefix(" ") {
                inResources = false
                inSharedFolders = false
            }

            if line.hasPrefix("- ") {
                guard inSharedFolders else { throw SandboxSpecError.malformedLine(rawLine) }
                try finishCurrentFolder()
                currentFolder = PartialSharedFolder()
                let remainder = String(line.dropFirst(2))
                if !remainder.isEmpty {
                    guard let (key, value) = parseKeyValue(remainder) else { throw SandboxSpecError.malformedLine(rawLine) }
                    try currentFolder?.set(key: key, value: value)
                }
                continue
            }

            guard let (key, value) = parseKeyValue(line) else {
                if line == "[]" && inSharedFolders { continue }
                throw SandboxSpecError.malformedLine(rawLine)
            }

            if inResources {
                switch key {
                case "cpus": cpus = Int(value)
                case "memory": memory = try MemorySize.parse(value)
                default: throw SandboxSpecError.unsupportedField("resources.\(key)")
                }
                continue
            }

            if inSharedFolders {
                try currentFolder?.set(key: key, value: value)
                continue
            }

            switch key {
            case "schemaVersion": schemaVersion = Int(value)
            case "name": name = try SandboxName(value)
            case "image": image = SandboxImage(reference: value)
            case "os": guestOS = try GuestOS.parse(value)
            case "bootstrap": bootstrapState = try BootstrapState.parse(value)
            case "disk": diskSize = try DiskSize.parse(value)
            case "resources":
                guard value.isEmpty else { throw SandboxSpecError.malformedLine(rawLine) }
                inResources = true
            case "sharedFolders", "allowedFolders":
                if value == "[]" {
                    inSharedFolders = false
                } else {
                    guard value.isEmpty else { throw SandboxSpecError.malformedLine(rawLine) }
                    inSharedFolders = true
                }
            case "inboundNetworking", "ports", "portPublishing":
                throw SandboxSpecError.unsupportedField(key)
            default:
                throw SandboxSpecError.unsupportedField(key)
            }
        }

        try finishCurrentFolder()

        let spec = SandboxSpec(
            schemaVersion: schemaVersion ?? SandboxSpec.supportedSchemaVersion,
            name: try required(name, "name"),
            image: image ?? .developerReadyDefault,
            guestOS: guestOS ?? .linux,
            resourceProfile: ResourceProfile(cpus: try required(cpus, "resources.cpus"), memory: try required(memory, "resources.memory")),
            diskSize: diskSize,
            bootstrapState: bootstrapState,
            sharedFolders: sharedFolders
        )
        try spec.validateV1()
        return spec
    }
}

private struct PartialSharedFolder {
    var displayHostPath: String?
    var resolvedHostPath: String?
    var guestPath: String?
    var accessMode: String?

    mutating func set(key: String, value: String) throws {
        switch key {
        case "hostPath", "displayHostPath": displayHostPath = value
        case "resolvedHostPath": resolvedHostPath = value
        case "guestPath": guestPath = value
        case "accessMode": accessMode = value
        default: throw SandboxSpecError.unsupportedField("sharedFolders.\(key)")
        }
    }

    func build() throws -> SharedFolder {
        SharedFolder(
            displayHostPath: try required(displayHostPath, "sharedFolders.hostPath"),
            resolvedHostPath: try required(resolvedHostPath, "sharedFolders.resolvedHostPath"),
            guestPath: try GuestPath(try required(guestPath, "sharedFolders.guestPath")),
            accessMode: try AccessMode.parse(try required(accessMode, "sharedFolders.accessMode"))
        )
    }
}

// Parses a "key: value" line into a tuple.
private func parseKeyValue(_ line: String) -> (String, String)? {
    guard let colon = line.firstIndex(of: ":") else { return nil }
    let key = String(line[..<colon]).trimmingCharacters(in: .whitespaces)
    let value = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
    return (key, value)
}

// Validates that a required field is present.
private func required<T>(_ value: T?, _ field: String) throws -> T {
    guard let value else { throw SandboxSpecError.missingField(field) }
    return value
}

/// Errors that can occur when parsing or validating a sandbox spec.
public enum SandboxSpecError: Error, Equatable, CustomStringConvertible {
    case unsupportedSchemaVersion(Int)
    case unsupportedField(String)
    case missingField(String)
    case malformedLine(String)
    case imageImmutable
    case guestOSImmutable
    case resourceProfileImmutable(field: String)
    case diskUnsupportedForGuestOS(GuestOS)
    case diskSizeImmutable
    case localCloneRequiresMacOS
    case cloneDiskTooSmall(source: DiskSize, requested: DiskSize)

    public var description: String {
        switch self {
        case .unsupportedSchemaVersion(let version): return "unsupported schema version: \(version)"
        case .unsupportedField(let field): return "unsupported v1 sandbox spec field: \(field)"
        case .missingField(let field): return "missing sandbox spec field: \(field)"
        case .malformedLine(let line): return "malformed sandbox spec line: \(line)"
        case .imageImmutable: return "image cannot be edited after creation"
        case .guestOSImmutable: return "guest OS cannot be edited after creation"
        case .resourceProfileImmutable(let field): return "resource profile field cannot be edited after creation: \(field)"
        case .diskUnsupportedForGuestOS(let guestOS): return "disk size is only supported for macOS sandboxes, not \(guestOS.rawValue)"
        case .diskSizeImmutable: return "disk size cannot be edited after creation"
        case .localCloneRequiresMacOS: return "local sandbox clone is only supported for macOS sandboxes"
        case .cloneDiskTooSmall(let source, let requested): return "clone disk size \(requested.description) is smaller than source disk size \(source.description)"
        }
    }
}

/// Guest operating systems supported by sandbox backends.
public enum GuestOS: String, Equatable, Sendable {
    case linux
    case macOS = "macos"

    public static func parse(_ rawValue: String) throws -> GuestOS {
        switch rawValue {
        case "linux": return .linux
        case "macos": return .macOS
        default: throw SandboxSpecError.unsupportedField("os: \(rawValue)")
        }
    }
}

/// Tracks whether a sandbox is ready for frictionless use or still needs
/// one-time first-boot setup followed by `sand bootstrap`.
///
/// Self-built macOS bases from IPSW start as `setupRequired`: the VM exists
/// but requires GUI first-boot Sandbox User setup before SSH/key automation
/// is available. `sand bootstrap` transitions it to `ready`.
public enum BootstrapState: String, Equatable, Sendable {
    case ready
    case setupRequired = "setup-required"

    public static func parse(_ rawValue: String) throws -> BootstrapState {
        switch rawValue {
        case "ready": return .ready
        case "setup-required": return .setupRequired
        default: throw SandboxSpecError.unsupportedField("bootstrap: \(rawValue)")
        }
    }
}

/// A sandbox VM image reference.
public struct SandboxImage: Equatable, Sendable {
    public var reference: String

    public init(reference: String) {
        self.reference = reference
    }

    public static let developerReadyDefault = SandboxImage(reference: "sand/developer-ready:ubuntu-lts")
}

/// CPU and memory allocation for a sandbox.
public struct ResourceProfile: Equatable, Sendable {
    public var cpus: Int
    public var memory: MemorySize

    public init(cpus: Int, memory: MemorySize) {
        self.cpus = cpus
        self.memory = memory
    }

    public static let `default` = ResourceProfile(cpus: 4, memory: MemorySize(gigabytes: 8))
    public static let macOSDefault = ResourceProfile(cpus: 4, memory: MemorySize(gigabytes: 16))

    public static func `default`(for guestOS: GuestOS) -> ResourceProfile {
        switch guestOS {
        case .linux: return .default
        case .macOS: return .macOSDefault
        }
    }
}

/// A disk size value.
public struct DiskSize: Equatable, Sendable, CustomStringConvertible {
    public var gigabytes: Int

    public init(gigabytes: Int) {
        self.gigabytes = gigabytes
    }

    public var description: String {
        "\(gigabytes)GB"
    }

    public static func `default`(for guestOS: GuestOS) -> DiskSize? {
        switch guestOS {
        case .linux: return nil
        case .macOS: return DiskSize(gigabytes: 64)
        }
    }

    public static func parse(_ rawValue: String) throws -> DiskSize {
        let upper = rawValue.uppercased()
        if upper.hasSuffix("GB"), let value = Int(upper.dropLast(2)) {
            return DiskSize(gigabytes: value)
        }
        if let value = Int(rawValue) {
            return DiskSize(gigabytes: value)
        }
        throw SandboxSpecError.malformedLine("disk: \(rawValue)")
    }
}

/// A memory size value.
public struct MemorySize: Equatable, Sendable, CustomStringConvertible {
    public var megabytes: Int

    public init(megabytes: Int) {
        self.megabytes = megabytes
    }

    public init(gigabytes: Int) {
        self.megabytes = gigabytes * 1024
    }

    public var description: String {
        if megabytes % 1024 == 0 { return "\(megabytes / 1024)GB" }
        return "\(megabytes)MB"
    }

    public static func parse(_ rawValue: String) throws -> MemorySize {
        let upper = rawValue.uppercased()
        if upper.hasSuffix("GB"), let value = Int(upper.dropLast(2)) {
            return MemorySize(gigabytes: value)
        }
        if upper.hasSuffix("MB"), let value = Int(upper.dropLast(2)) {
            return MemorySize(megabytes: value)
        }
        if let value = Int(rawValue) {
            return MemorySize(megabytes: value)
        }
        throw SandboxSpecError.malformedLine("memory: \(rawValue)")
    }
}

/// An shared host folder mapping.
public struct SharedFolder: Equatable, Sendable {
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

/// An absolute path inside the sandbox guest.
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

/// Access mode for a folder mapping.
public enum AccessMode: String, Equatable, Sendable {
    case readOnly = "read-only"
    case readWrite = "read-write"

    public static func parse(_ input: String) throws -> AccessMode {
        switch input {
        case "rw", "read-write": return .readWrite
        case "ro", "read-only": return .readOnly
        default: throw FolderPolicyError.unsupportedAccessMode(input)
        }
    }
}
