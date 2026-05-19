public struct LifecycleCoordinator: SandboxApplication {
    private let metadataStore: any HostMetadataStore
    private let backend: any SandboxBackend
    private let workingDirectoryMapper: WorkingDirectoryMapper

    public init(
        metadataStore: any HostMetadataStore,
        backend: any SandboxBackend,
        workingDirectoryMapper: WorkingDirectoryMapper = WorkingDirectoryMapper()
    ) {
        self.metadataStore = metadataStore
        self.backend = backend
        self.workingDirectoryMapper = workingDirectoryMapper
    }

    public func run(_ request: RunRequest) throws -> CommandResult {
        let spec = try metadataStore.readSpec(named: request.sandboxName)
        let mapping = workingDirectoryMapper.map(hostCurrentDirectory: metadataStore.currentHostDirectory(), spec: spec)

        if try backend.status(request.sandboxName) == .stopped {
            try backend.start(request.sandboxName)
        }

        return try backend.run(
            BackendRunRequest(
                sandboxName: request.sandboxName,
                command: request.command,
                workingDirectory: mapping.guestPath
            )
        )
    }
}
