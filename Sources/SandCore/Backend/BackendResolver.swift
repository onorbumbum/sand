/// Resolves the sandbox backend from the guest operating system.
public protocol BackendResolver {
    func backend(for guestOS: GuestOS) throws -> any SandboxBackend
    func doctorBackend() throws -> any SandboxBackend
}

/// Uses one backend for all guest operating systems.
public struct SingleBackendResolver: BackendResolver {
    private let backend: any SandboxBackend

    public init(backend: any SandboxBackend) {
        self.backend = backend
    }

    public func backend(for guestOS: GuestOS) throws -> any SandboxBackend {
        backend
    }

    public func doctorBackend() throws -> any SandboxBackend {
        backend
    }
}

/// Production guest-OS routing.
public struct GuestOSBackendResolver: BackendResolver {
    private let linuxBackend: any SandboxBackend
    private let macOSBackend: any SandboxBackend

    public init(linuxBackend: any SandboxBackend, macOSBackend: any SandboxBackend) {
        self.linuxBackend = linuxBackend
        self.macOSBackend = macOSBackend
    }

    public func backend(for guestOS: GuestOS) throws -> any SandboxBackend {
        switch guestOS {
        case .linux:
            return linuxBackend
        case .macOS:
            return macOSBackend
        }
    }

    public func doctorBackend() throws -> any SandboxBackend {
        linuxBackend
    }
}
