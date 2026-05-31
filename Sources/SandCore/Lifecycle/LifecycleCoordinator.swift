import Foundation

/// Coordinates the lifecycle of sandbox VMs including creation, deletion,
/// starting, stopping, and shell access.
///
/// Orchestrates between the metadata store, backend, and user prompts.
/// Handles: create, apply, delete, start, stop, shell, run, and status.
///
/// - Note: All mutations are protected by lifecycle locks.
public struct LifecycleCoordinator: SandboxApplication {
    private let metadataStore: any HostMetadataStore
    private let backend: any SandboxBackend
    private let workingDirectoryMapper: WorkingDirectoryMapper
    private let folderPolicy: FolderPolicy
    private let prompt: any PromptConfirmation
    private let doctorPlatform: any DoctorPlatform
    private let writeOutput: (String) -> Void
    private let writeWarning: (String) -> Void

    /// Initializes a new lifecycle coordinator.
    public init(
        metadataStore: any HostMetadataStore,
        backend: any SandboxBackend,
        workingDirectoryMapper: WorkingDirectoryMapper = WorkingDirectoryMapper(),
        folderPolicy: FolderPolicy = FolderPolicy(),
        prompt: any PromptConfirmation = AlwaysProceedPromptConfirmation(),
        doctorPlatform: any DoctorPlatform = HostDoctorPlatform(),
        writeOutput: @escaping (String) -> Void = { Swift.print($0) },
        writeWarning: @escaping (String) -> Void = { FileHandle.standardError.write(Data(($0 + "\n").utf8)) }
    ) {
        self.metadataStore = metadataStore
        self.backend = backend
        self.workingDirectoryMapper = workingDirectoryMapper
        self.folderPolicy = folderPolicy
        self.prompt = prompt
        self.doctorPlatform = doctorPlatform
        self.writeOutput = writeOutput
        self.writeWarning = writeWarning
    }

    /// Runs diagnostic checks on the host environment.
    ///
    /// Verifies backend availability, image accessibility, and disk writability.
    public func doctor() throws -> CommandResult {
        let report = try DoctorChecks(backend: backend, metadataStore: metadataStore, platform: doctorPlatform).run()
        for line in DoctorPresenter().lines(for: report) {
            writeOutput(line)
        }
        return report.isHealthy ? .success : .failure(exitCode: 1)
    }

    /// Creates a new sandbox VM with the specified configuration.
    ///
    /// Either parses an authored spec from YAML or generates one from
    /// the provided parameters.
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

    /// Lists all known sandbox VMs with their current status.
    public func list() throws -> CommandResult {
        let presenter = StatusPresenter()
        for spec in try metadataStore.listSpecs() {
            let runtimeStatus = try backend.status(spec.name)
            let view = presenter.present(name: spec.name, spec: spec, runtimeStatus: runtimeStatus)
            writeOutput(presenter.listLine(for: view))
        }
        return .success
    }

    /// Applies configuration changes to an existing sandbox VM.
    public func apply(_ request: NamedSandboxRequest) throws -> CommandResult {
        try metadataStore.withLifecycleMutationLock {
            let spec = try metadataStore.readSpec(named: request.sandboxName)
            let createdSpec = try metadataStore.readCreatedSpec(named: request.sandboxName)
            try spec.validateUpdate(from: createdSpec)
            if try backend.status(request.sandboxName) == .running {
                let decision = try prompt.confirm(ConfirmationRequest(message: "Apply changes to running Sandbox VM \(request.sandboxName.rawValue)?", destructive: false))
                guard decision == .proceed else { return .failure(exitCode: 1) }
            }
            try backend.apply(spec)
            return .success
        }
    }

    /// Deletes a sandbox VM and its associated metadata.
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

    /// Displays detailed status information for a sandbox VM.
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

    /// Starts a stopped sandbox VM.
    public func start(_ request: NamedSandboxRequest) throws -> CommandResult {
        try metadataStore.withLifecycleMutationLock {
            try backend.start(request.sandboxName)
        }
        return .success
    }

    /// Stops a running sandbox VM.
    public func stop(_ request: NamedSandboxRequest) throws -> CommandResult {
        try metadataStore.withLifecycleMutationLock {
            try backend.stop(request.sandboxName)
        }
        return .success
    }

    /// Opens an interactive shell session in the sandbox VM.
    ///
    /// If the VM is stopped, starts it first. Maps the host's current
    /// working directory to the guest and opens a shell there.
    public func shell(_ request: ShellRequest) throws -> CommandResult {
        let spec = try metadataStore.readSpec(named: request.sandboxName)
        let mapping = workingDirectoryMapper.map(hostCurrentDirectory: metadataStore.currentHostDirectory(), spec: spec)
        emitWarningIfNeeded(mapping)

        if try backend.status(request.sandboxName) == .stopped {
            try backend.start(request.sandboxName)
        }

        return try backend.shell(BackendShellRequest(sandboxName: request.sandboxName, workingDirectory: mapping.guestPath))
    }

    /// Executes a workload command in the sandbox VM.
    public func run(_ request: RunRequest) throws -> CommandResult {
        let spec = try metadataStore.readSpec(named: request.sandboxName)
        let mapping = workingDirectoryMapper.map(hostCurrentDirectory: metadataStore.currentHostDirectory(), spec: spec)
        emitWarningIfNeeded(mapping)

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

    /// Retrieves and displays logs from the sandbox VM.
    public func logs(_ request: NamedSandboxRequest) throws -> CommandResult {
        let logs = try backend.logs(request.sandboxName)
        let lines = logs.text.split(whereSeparator: \.isNewline).map(String.init)
        if lines.isEmpty {
            writeOutput("No logs available for Sandbox VM \(request.sandboxName.rawValue).")
        } else {
            for line in lines {
                writeOutput(line)
            }
        }
        return .success
    }

    /// Prints the sandbox specification as YAML.
    public func spec(_ request: NamedSandboxRequest) throws -> CommandResult {
        let yaml = try metadataStore.readSpec(named: request.sandboxName).renderedYAML()
        writeOutput(yaml.trimmingCharacters(in: .newlines))
        return .success
    }

    /// Adds a host folder to the sandbox's allowed folders list.
    public func addFolder(_ request: AddFolderRequest) throws -> CommandResult {
        try metadataStore.withLifecycleMutationLock {
            let current = try metadataStore.readSpec(named: request.sandboxName)
            let updated = try folderPolicy.addFolder(
                to: current,
                displayHostPath: request.displayHostPath,
                accessMode: request.accessMode,
                guestPath: request.guestPath
            )
            return try applyConfigMutation(current: current, updated: updated) ? .success : .failure(exitCode: 1)
        }
    }

    /// Lists all allowed folders for a sandbox.
    public func listFolders(_ request: NamedSandboxRequest) throws -> CommandResult {
        let folders = try metadataStore.readSpec(named: request.sandboxName).allowedFolders
        for line in FolderListPresenter().lines(for: folders) {
            writeOutput(line)
        }
        return .success
    }

    /// Removes a host folder from the sandbox's allowed folders.
    public func removeFolder(_ request: RemoveFolderRequest) throws -> CommandResult {
        try metadataStore.withLifecycleMutationLock {
            let current = try metadataStore.readSpec(named: request.sandboxName)
            let updated = folderPolicy.removeFolder(from: current, displayHostPath: request.displayHostPath)
            return try applyConfigMutation(current: current, updated: updated) ? .success : .failure(exitCode: 1)
        }
    }

    private func emitWarningIfNeeded(_ mapping: WorkingDirectoryMapping) {
        if let warning = mapping.warning {
            writeWarning(warning)
        }
    }

    // Validates and applies a configuration mutation, prompting if VM is running.
    private func applyConfigMutation(current: SandboxSpec, updated: SandboxSpec) throws -> Bool {
        try updated.validateUpdate(from: current)
        let createdSpec = try metadataStore.readCreatedSpec(named: current.name)
        try updated.validateUpdate(from: createdSpec)
        if try backend.status(current.name) == .running {
            let decision = try prompt.confirm(ConfirmationRequest(message: "Apply changes to running Sandbox VM \(current.name.rawValue)?", destructive: false))
            guard decision == .proceed else { return false }
        }
        try metadataStore.writeSpec(updated)
        try backend.apply(updated)
        return true
    }
}

/// Always-approve prompt for non-interactive use.
public struct AlwaysProceedPromptConfirmation: PromptConfirmation {
    public init() {}

    public func confirm(_ request: ConfirmationRequest) throws -> ConfirmationDecision {
        .proceed
    }
}