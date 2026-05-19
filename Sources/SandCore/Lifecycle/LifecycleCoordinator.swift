public struct LifecycleCoordinator: SandboxApplication {
    private let metadataStore: any HostMetadataStore
    private let backend: any SandboxBackend
    private let workingDirectoryMapper: WorkingDirectoryMapper
    private let folderPolicy: FolderPolicy
    private let prompt: any PromptConfirmation
    private let doctorPlatform: any DoctorPlatform
    private let writeOutput: (String) -> Void

    public init(
        metadataStore: any HostMetadataStore,
        backend: any SandboxBackend,
        workingDirectoryMapper: WorkingDirectoryMapper = WorkingDirectoryMapper(),
        folderPolicy: FolderPolicy = FolderPolicy(),
        prompt: any PromptConfirmation = AlwaysProceedPromptConfirmation(),
        doctorPlatform: any DoctorPlatform = HostDoctorPlatform(),
        writeOutput: @escaping (String) -> Void = { Swift.print($0) }
    ) {
        self.metadataStore = metadataStore
        self.backend = backend
        self.workingDirectoryMapper = workingDirectoryMapper
        self.folderPolicy = folderPolicy
        self.prompt = prompt
        self.doctorPlatform = doctorPlatform
        self.writeOutput = writeOutput
    }

    public func doctor() throws -> CommandResult {
        let report = try DoctorChecks(backend: backend, metadataStore: metadataStore, platform: doctorPlatform).run()
        for line in DoctorPresenter().lines(for: report) {
            writeOutput(line)
        }
        return report.isHealthy ? .success : .failure(exitCode: 1)
    }

    public func create(_ request: CreateRequest) throws -> CommandResult {
        try metadataStore.withLifecycleMutationLock {
            let spec: SandboxSpec
            if let authoredSpecText = request.authoredSpecText {
                spec = try SandboxSpec.parseYAML(authoredSpecText)
            } else {
                spec = SandboxSpec.generated(name: request.sandboxName, image: request.image, resourceProfile: request.resourceProfile)
            }
            try metadataStore.createSpec(spec)
            do {
                try backend.provision(spec)
            } catch {
                try metadataStore.deleteSpec(named: spec.name)
                throw error
            }
        }
        return .success
    }

    public func list() throws -> CommandResult {
        let presenter = StatusPresenter()
        for spec in try metadataStore.listSpecs() {
            let runtimeStatus = try backend.status(spec.name)
            let view = presenter.present(name: spec.name, spec: spec, runtimeStatus: runtimeStatus)
            writeOutput(presenter.listLine(for: view))
        }
        return .success
    }

    public func apply(_ request: NamedSandboxRequest) throws -> CommandResult {
        try metadataStore.withLifecycleMutationLock {
            let spec = try metadataStore.readSpec(named: request.sandboxName)
            try backend.apply(spec)
        }
        return .success
    }

    public func delete(_ request: DeleteRequest) throws -> CommandResult {
        if !request.force {
            let decision = try prompt.confirm(ConfirmationRequest(message: "Delete Sandbox VM \(request.sandboxName.rawValue)?", destructive: true))
            guard decision == .proceed else { return .failure(exitCode: 1) }
        }

        try metadataStore.withLifecycleMutationLock {
            try backend.delete(request.sandboxName)
            try metadataStore.deleteSpec(named: request.sandboxName)
        }
        return .success
    }

    public func status(_ request: NamedSandboxRequest) throws -> CommandResult {
        let spec = try metadataStore.readSpec(named: request.sandboxName)
        let runtimeStatus = try backend.status(request.sandboxName)
        let presenter = StatusPresenter()
        let view = presenter.present(name: spec.name, spec: spec, runtimeStatus: runtimeStatus)
        for line in presenter.detailLines(for: view) {
            writeOutput(line)
        }
        return .success
    }

    public func start(_ request: NamedSandboxRequest) throws -> CommandResult {
        try metadataStore.withLifecycleMutationLock {
            try backend.start(request.sandboxName)
        }
        return .success
    }

    public func stop(_ request: NamedSandboxRequest) throws -> CommandResult {
        try metadataStore.withLifecycleMutationLock {
            try backend.stop(request.sandboxName)
        }
        return .success
    }

    public func shell(_ request: ShellRequest) throws -> CommandResult {
        let spec = try metadataStore.readSpec(named: request.sandboxName)
        let mapping = workingDirectoryMapper.map(hostCurrentDirectory: metadataStore.currentHostDirectory(), spec: spec)

        if try backend.status(request.sandboxName) == .stopped {
            try backend.start(request.sandboxName)
        }

        return try backend.shell(BackendShellRequest(sandboxName: request.sandboxName, workingDirectory: mapping.guestPath))
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

    public func logs(_ request: NamedSandboxRequest) throws -> CommandResult {
        _ = try backend.logs(request.sandboxName)
        return .success
    }

    public func spec(_ request: NamedSandboxRequest) throws -> CommandResult {
        let yaml = try metadataStore.readSpec(named: request.sandboxName).renderedYAML()
        writeOutput(yaml.trimmingCharacters(in: .newlines))
        return .success
    }

    public func addFolder(_ request: AddFolderRequest) throws -> CommandResult {
        try metadataStore.withLifecycleMutationLock {
            let current = try metadataStore.readSpec(named: request.sandboxName)
            let updated = try folderPolicy.addFolder(
                to: current,
                displayHostPath: request.displayHostPath,
                accessMode: request.accessMode,
                guestPath: request.guestPath
            )
            try applyConfigMutation(current: current, updated: updated)
        }
        return .success
    }

    public func listFolders(_ request: NamedSandboxRequest) throws -> CommandResult {
        _ = try metadataStore.readSpec(named: request.sandboxName).allowedFolders
        return .success
    }

    public func removeFolder(_ request: RemoveFolderRequest) throws -> CommandResult {
        try metadataStore.withLifecycleMutationLock {
            let current = try metadataStore.readSpec(named: request.sandboxName)
            let updated = folderPolicy.removeFolder(from: current, displayHostPath: request.displayHostPath)
            try applyConfigMutation(current: current, updated: updated)
        }
        return .success
    }

    private func applyConfigMutation(current: SandboxSpec, updated: SandboxSpec) throws {
        try updated.validateUpdate(from: current)
        if try backend.status(current.name) == .running {
            let decision = try prompt.confirm(ConfirmationRequest(message: "Apply changes to running Sandbox VM \(current.name.rawValue)?", destructive: false))
            guard decision == .proceed else { return }
        }
        try metadataStore.writeSpec(updated)
        try backend.apply(updated)
    }
}

public struct AlwaysProceedPromptConfirmation: PromptConfirmation {
    public init() {}

    public func confirm(_ request: ConfirmationRequest) throws -> ConfirmationDecision {
        .proceed
    }
}
