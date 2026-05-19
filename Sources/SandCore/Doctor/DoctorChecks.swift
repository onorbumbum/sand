public struct DoctorChecks {
    private let backend: any SandboxBackend
    private let metadataStore: any HostMetadataStore
    private let platform: any DoctorPlatform

    public init(
        backend: any SandboxBackend,
        metadataStore: any HostMetadataStore,
        platform: any DoctorPlatform = HostDoctorPlatform()
    ) {
        self.backend = backend
        self.metadataStore = metadataStore
        self.platform = platform
    }

    public func run() throws -> DoctorReport {
        guard platform.isSupported else {
            return DoctorReport(findings: [
                DoctorFinding(
                    kind: .unsupportedPlatform,
                    message: "Sandbox VM requires Apple silicon macOS on this Host Mac. Run sand on an Apple silicon Mac before creating Sandbox VMs."
                )
            ])
        }

        var findings: [DoctorFinding] = []

        switch try backend.checkReadiness() {
        case .ready:
            break
        case .notReady(let backendFindings):
            findings.append(contentsOf: backendFindings)
        }

        do {
            try metadataStore.checkWritability()
        } catch {
            findings.append(
                DoctorFinding(
                    kind: .unwritableHostMetadata,
                    message: "Host Metadata under ~/.sand is not writable. Fix the ~/.sand permissions or free the disk before creating Sandbox VMs."
                )
            )
        }

        return DoctorReport(findings: findings)
    }
}

public protocol DoctorPlatform {
    var isSupported: Bool { get }
}

public struct HostDoctorPlatform: DoctorPlatform {
    public init() {}

    public var isSupported: Bool {
        #if os(macOS) && arch(arm64)
        return true
        #else
        return false
        #endif
    }
}

public struct DoctorReport: Equatable {
    public var findings: [DoctorFinding]

    public init(findings: [DoctorFinding]) {
        self.findings = findings
    }

    public var isHealthy: Bool {
        findings.isEmpty
    }
}

public struct DoctorPresenter {
    public init() {}

    public func lines(for report: DoctorReport) -> [String] {
        if report.isHealthy {
            return ["sand doctor: all Sandbox VM prerequisites OK"]
        }
        return report.findings.map { "sand doctor: \($0.message)" }
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
