import Foundation

public struct SandboxSpec: Equatable, Sendable {
    public static let supportedSchemaVersion = 1

    public var schemaVersion: Int
    public var name: SandboxName
    public var image: SandboxImage
    public var resourceProfile: ResourceProfile
    public var allowedFolders: [AllowedFolder]

    public init(
        schemaVersion: Int = SandboxSpec.supportedSchemaVersion,
        name: SandboxName,
        image: SandboxImage = .developerReadyDefault,
        resourceProfile: ResourceProfile = .default,
        allowedFolders: [AllowedFolder] = []
    ) {
        self.schemaVersion = schemaVersion
        self.name = name
        self.image = image
        self.resourceProfile = resourceProfile
        self.allowedFolders = allowedFolders
    }

    public static func generated(name: SandboxName, image: SandboxImage = .developerReadyDefault, resourceProfile: ResourceProfile = .default) -> SandboxSpec {
        SandboxSpec(name: name, image: image, resourceProfile: resourceProfile, allowedFolders: [])
    }

    public func validateV1() throws {
        guard schemaVersion == SandboxSpec.supportedSchemaVersion else {
            throw SandboxSpecError.unsupportedSchemaVersion(schemaVersion)
        }
    }

    public func validateUpdate(from existing: SandboxSpec) throws {
        if resourceProfile.cpus != existing.resourceProfile.cpus {
            throw SandboxSpecError.resourceProfileImmutable(field: "cpus")
        }
        if resourceProfile.memory != existing.resourceProfile.memory {
            throw SandboxSpecError.resourceProfileImmutable(field: "memory")
        }
    }

    public func renderedYAML() -> String {
        var lines: [String] = []
        lines.append("schemaVersion: \(schemaVersion)")
        lines.append("name: \(name.rawValue)")
        lines.append("image: \(image.reference)")
        lines.append("resources:")
        lines.append("  cpus: \(resourceProfile.cpus)")
        lines.append("  memory: \(resourceProfile.memory.description)")
        lines.append("allowedFolders:")
        if allowedFolders.isEmpty {
            lines.append("  []")
        } else {
            for folder in allowedFolders {
                lines.append("  - hostPath: \(folder.displayHostPath)")
                lines.append("    resolvedHostPath: \(folder.resolvedHostPath)")
                lines.append("    guestPath: \(folder.guestPath.rawValue)")
                lines.append("    accessMode: \(folder.accessMode.rawValue)")
            }
        }
        return lines.joined(separator: "\n") + "\n"
    }

    public static func parseYAML(_ text: String) throws -> SandboxSpec {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var schemaVersion: Int?
        var name: SandboxName?
        var image: SandboxImage?
        var cpus: Int?
        var memory: MemorySize?
        var allowedFolders: [AllowedFolder] = []
        var inResources = false
        var inAllowedFolders = false
        var currentFolder: PartialAllowedFolder?

        func finishCurrentFolder() throws {
            if let folder = currentFolder {
                allowedFolders.append(try folder.build())
                currentFolder = nil
            }
        }

        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { continue }

            if !rawLine.hasPrefix(" ") {
                inResources = false
                inAllowedFolders = false
            }

            if line.hasPrefix("- ") {
                guard inAllowedFolders else { throw SandboxSpecError.malformedLine(rawLine) }
                try finishCurrentFolder()
                currentFolder = PartialAllowedFolder()
                let remainder = String(line.dropFirst(2))
                if !remainder.isEmpty {
                    guard let (key, value) = parseKeyValue(remainder) else { throw SandboxSpecError.malformedLine(rawLine) }
                    try currentFolder?.set(key: key, value: value)
                }
                continue
            }

            guard let (key, value) = parseKeyValue(line) else {
                if line == "[]" && inAllowedFolders { continue }
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

            if inAllowedFolders {
                try currentFolder?.set(key: key, value: value)
                continue
            }

            switch key {
            case "schemaVersion": schemaVersion = Int(value)
            case "name": name = try SandboxName(value)
            case "image": image = SandboxImage(reference: value)
            case "resources":
                guard value.isEmpty else { throw SandboxSpecError.malformedLine(rawLine) }
                inResources = true
            case "allowedFolders":
                if value == "[]" {
                    inAllowedFolders = false
                } else {
                    guard value.isEmpty else { throw SandboxSpecError.malformedLine(rawLine) }
                    inAllowedFolders = true
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
            resourceProfile: ResourceProfile(cpus: try required(cpus, "resources.cpus"), memory: try required(memory, "resources.memory")),
            allowedFolders: allowedFolders
        )
        try spec.validateV1()
        return spec
    }
}

private struct PartialAllowedFolder {
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
        default: throw SandboxSpecError.unsupportedField("allowedFolders.\(key)")
        }
    }

    func build() throws -> AllowedFolder {
        AllowedFolder(
            displayHostPath: try required(displayHostPath, "allowedFolders.hostPath"),
            resolvedHostPath: try required(resolvedHostPath, "allowedFolders.resolvedHostPath"),
            guestPath: try GuestPath(try required(guestPath, "allowedFolders.guestPath")),
            accessMode: try AccessMode.parse(try required(accessMode, "allowedFolders.accessMode"))
        )
    }
}

private func parseKeyValue(_ line: String) -> (String, String)? {
    guard let colon = line.firstIndex(of: ":") else { return nil }
    let key = String(line[..<colon]).trimmingCharacters(in: .whitespaces)
    let value = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
    return (key, value)
}

private func required<T>(_ value: T?, _ field: String) throws -> T {
    guard let value else { throw SandboxSpecError.missingField(field) }
    return value
}

public enum SandboxSpecError: Error, Equatable, CustomStringConvertible {
    case unsupportedSchemaVersion(Int)
    case unsupportedField(String)
    case missingField(String)
    case malformedLine(String)
    case resourceProfileImmutable(field: String)

    public var description: String {
        switch self {
        case .unsupportedSchemaVersion(let version): return "unsupported schema version: \(version)"
        case .unsupportedField(let field): return "unsupported v1 sandbox spec field: \(field)"
        case .missingField(let field): return "missing sandbox spec field: \(field)"
        case .malformedLine(let line): return "malformed sandbox spec line: \(line)"
        case .resourceProfileImmutable(let field): return "resource profile field cannot be edited after creation: \(field)"
        }
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

    public static func parse(_ input: String) throws -> AccessMode {
        switch input {
        case "rw", "read-write": return .readWrite
        case "ro", "read-only": return .readOnly
        default: throw FolderPolicyError.unsupportedAccessMode(input)
        }
    }
}
