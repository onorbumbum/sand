public struct DoctorChecks {
    private let backend: any SandboxBackend
    private let metadataStore: any HostMetadataStore

    public init(backend: any SandboxBackend, metadataStore: any HostMetadataStore) {
        self.backend = backend
        self.metadataStore = metadataStore
    }

    public func run() throws -> [DoctorFinding] {
        switch try backend.checkReadiness() {
        case .ready:
            return []
        case .notReady(let findings):
            return findings
        }
    }
}

public struct DoctorFinding: Equatable {
    public var kind: DoctorFindingKind
    public var message: String

    public init(kind: DoctorFindingKind, message: String) {
        self.kind = kind
        self.message = message
    }
}

public enum DoctorFindingKind: Equatable {
    case backendExecutableMissing
    case backendServiceStopped
    case unsupportedPlatform
    case defaultImageMissing
    case unwritableHostMetadata
}
