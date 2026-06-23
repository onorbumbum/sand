import Foundation

/// Coordinates the lifecycle of sandbox VMs including creation, deletion,
/// starting, stopping, and shell access.
///
/// Orchestrates between the metadata store, backend, and user prompts.
/// Handles: create, apply, delete, start, stop, shell, run, gui, and status.
///
/// - Note: All mutations are protected by lifecycle locks.
public struct LifecycleCoordinator: SandboxApplication {
    private let metadataStore: any HostMetadataStore
    private let backendResolver: any BackendResolver
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
        self.backendResolver = SingleBackendResolver(backend: backend)
        self.workingDirectoryMapper = workingDirectoryMapper
        self.folderPolicy = folderPolicy
        self.prompt = prompt
        self.doctorPlatform = doctorPlatform
        self.writeOutput = writeOutput
        self.writeWarning = writeWarning
    }

    /// Initializes a new lifecycle coordinator with guest-OS backend routing.
    public init(
        metadataStore: any HostMetadataStore,
        backendResolver: any BackendResolver,
        workingDirectoryMapper: WorkingDirectoryMapper = WorkingDirectoryMapper(),
        folderPolicy: FolderPolicy = FolderPolicy(),
        prompt: any PromptConfirmation = AlwaysProceedPromptConfirmation(),
        doctorPlatform: any DoctorPlatform = HostDoctorPlatform(),
        writeOutput: @escaping (String) -> Void = { Swift.print($0) },
        writeWarning: @escaping (String) -> Void = { FileHandle.standardError.write(Data(($0 + "\n").utf8)) }
    ) {
        self.metadataStore = metadataStore
        self.backendResolver = backendResolver
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
        let report = try DoctorChecks(backend: backendResolver.doctorBackend(), metadataStore: metadataStore, platform: doctorPlatform).run()
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
        if let ipswSource = request.ipswSource {
            return try createFromIPSW(request, ipswSource: ipswSource)
        }
        writeOutput("Creating Sandbox VM \(request.sandboxName.rawValue)...")
        try metadataStore.withLifecycleMutationLock {
            let spec: SandboxSpec
            if let authoredSpecText = request.authoredSpecText {
                spec = try SandboxSpec.parseYAML(authoredSpecText)
            } else if let clone = try localCloneSource(for: request) {
                spec = clone.spec
                try spec.validateLocalClone(from: clone.sourceSpec)
                if try backend(for: clone.sourceSpec).status(clone.sourceSpec.name) != .stopped {
                    throw SandboxCreateError.localCloneSourceNotStopped(clone.sourceSpec.name.rawValue)
                }
            } else {
                spec = SandboxSpec.generated(name: request.sandboxName, image: request.image, guestOS: request.guestOS, resourceProfile: request.resourceProfile, diskSize: request.diskSize, displayResolution: request.displayResolution)
            }
            try spec.validateV1()
            try metadataStore.createSpec(spec)
            do {
                try backend(for: spec).provision(spec)
            } catch {
                try metadataStore.deleteSpec(named: spec.name)
                throw error
            }
        }
        writeOutput("Created Sandbox VM \(request.sandboxName.rawValue).")
        return .success
    }

    /// Builds a self-made macOS base from an IPSW.
    ///
    /// The raw IPSW install requires interactive first-boot macOS setup before
    /// SSH/key automation is available, so this records the sandbox as
    /// setup-required and guides the user to complete first boot in a GUI
    /// session before running `sand bootstrap`.
    private func createFromIPSW(_ request: CreateRequest, ipswSource: String) throws -> CommandResult {
        let name = request.sandboxName.rawValue
        writeOutput("Creating setup-required macOS Sandbox VM \(name) from IPSW...")
        try metadataStore.withLifecycleMutationLock {
            let spec = SandboxSpec.generated(
                name: request.sandboxName,
                image: request.image,
                guestOS: .macOS,
                resourceProfile: request.resourceProfile,
                diskSize: request.diskSize,
                displayResolution: request.displayResolution,
                bootstrapState: .setupRequired
            )
            try spec.validateV1()
            try metadataStore.createSpec(spec)
            do {
                try backend(for: spec).provisionFromIPSW(spec, ipswSource: ipswSource)
            } catch {
                try metadataStore.deleteSpec(named: spec.name)
                throw error
            }
        }
        writeOutput("Created setup-required macOS Sandbox VM '\(name)' from IPSW.")
        writeOutput("Complete one-time first boot, then bootstrap:")
        writeOutput("  1. Run `sand gui \(name)` and finish macOS Setup Assistant.")
        writeOutput("  2. Create/enable the Sandbox User (admin), enable Remote Login, and configure passwordless sudo.")
        writeOutput("  3. Run `sand bootstrap \(name)` to inject the Sand key and finish backend configuration.")
        return .success
    }

    /// Completes the second stage of the self-built macOS IPSW flow.
    ///
    /// After the user finishes interactive first-boot setup in a GUI session,
    /// this injects the Sand SSH key, verifies SSH reachability and passwordless
    /// sudo, runs post-create backend configuration, and transitions the
    /// sandbox from setup-required to ready for the frictionless shell/run path.
    public func bootstrap(_ request: NamedSandboxRequest) throws -> CommandResult {
        try metadataStore.withLifecycleMutationLock {
            let spec = try metadataStore.readSpec(named: request.sandboxName)
            guard spec.guestOS == .macOS else {
                throw SandboxBootstrapError.unsupportedGuestOS(spec.guestOS.rawValue)
            }
            guard spec.bootstrapState == .setupRequired else {
                throw SandboxBootstrapError.alreadyBootstrapped(spec.name.rawValue)
            }
            try backend(for: spec).bootstrap(spec)
            var ready = spec
            ready.bootstrapState = .ready
            try metadataStore.writeSpec(ready)
        }
        let name = request.sandboxName.rawValue
        writeOutput("Bootstrapped macOS Sandbox VM '\(name)'. It is ready — use `sand \(name) shell`.")
        return .success
    }

    /// Lists all known sandbox VMs with their current status.
    public func list() throws -> CommandResult {
        let presenter = StatusPresenter()
        for spec in try metadataStore.listSpecs() {
            let runtimeStatus = try backend(for: spec).status(spec.name)
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
            let backend = try backend(for: spec)
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
            let spec = try metadataStore.readSpec(named: request.sandboxName)
            try backend(for: spec).delete(request.sandboxName)
            try metadataStore.deleteSpec(named: request.sandboxName)
        }
        return .success
    }

    /// Displays detailed status information for a sandbox VM.
    public func status(_ request: NamedSandboxRequest) throws -> CommandResult {
        let spec = try metadataStore.readSpec(named: request.sandboxName)
        let runtimeStatus = try backend(for: spec).status(request.sandboxName)
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
            let spec = try metadataStore.readSpec(named: request.sandboxName)
            let backend = try backend(for: spec)
            if try backend.status(request.sandboxName) == .running {
                writeOutput("Sandbox VM \(request.sandboxName.rawValue) is already running.")
                return
            }
            writeOutput("Starting Sandbox VM \(request.sandboxName.rawValue)...")
            try backend.start(spec)
            writeOutput("Started Sandbox VM \(request.sandboxName.rawValue).")
        }
        return .success
    }

    /// Stops a running sandbox VM.
    public func stop(_ request: NamedSandboxRequest) throws -> CommandResult {
        try metadataStore.withLifecycleMutationLock {
            let spec = try metadataStore.readSpec(named: request.sandboxName)
            try backend(for: spec).stop(request.sandboxName)
        }
        return .success
    }

    /// Opens an interactive shell session in the sandbox VM.
    ///
    /// If the VM is stopped, starts it first. Maps the host's current
    /// working directory to the guest and opens a shell there.
    public func shell(_ request: ShellRequest) throws -> CommandResult {
        let spec = try metadataStore.readSpec(named: request.sandboxName)
        try requireBootstrapped(spec)
        let mapping = mappedWorkingDirectory(for: spec)
        emitWarningIfNeeded(mapping)

        let backend = try backend(for: spec)
        if try backend.status(request.sandboxName) == .stopped {
            writeOutput("Starting Sandbox VM \(request.sandboxName.rawValue)...")
            try backend.start(spec)
        }

        return try backend.shell(BackendShellRequest(sandboxName: request.sandboxName, workingDirectory: mapping.guestPath))
    }

    /// Executes a workload command in the sandbox VM.
    public func run(_ request: RunRequest) throws -> CommandResult {
        let spec = try metadataStore.readSpec(named: request.sandboxName)
        try requireBootstrapped(spec)
        let mapping = mappedWorkingDirectory(for: spec)
        emitWarningIfNeeded(mapping)

        let backend = try backend(for: spec)
        if try backend.status(request.sandboxName) == .stopped {
            writeOutput("Starting Sandbox VM \(request.sandboxName.rawValue)...")
            try backend.start(spec)
        }

        return try backend.run(
            BackendRunRequest(
                sandboxName: request.sandboxName,
                command: request.command,
                workingDirectory: mapping.guestPath
            )
        )
    }

    /// Opens a graphical desktop session for a macOS sandbox VM.
    public func gui(_ request: GUIRequest) throws -> CommandResult {
        let spec = try metadataStore.readSpec(named: request.sandboxName)
        guard spec.guestOS == .macOS else {
            throw SandboxGUIError.unsupportedGuestOS(spec.guestOS.rawValue)
        }
        return try backend(for: spec).gui(BackendGUIRequest(spec: spec))
    }

    /// Installs distribution-signing credentials as a macOS Sandbox Guest Secret.
    public func installSigningCredentials(_ request: SigningCredentialsRequest) throws -> CommandResult {
        try metadataStore.withLifecycleMutationLock {
            let spec = try metadataStore.readSpec(named: request.sandboxName)
            guard spec.guestOS == .macOS else {
                throw SandboxSigningError.unsupportedGuestOS(spec.guestOS.rawValue)
            }
            let backend = try backend(for: spec)
            if try backend.status(spec.name) == .stopped {
                try backend.start(spec)
            }
            return try backend.installSigningCredentials(
                BackendSigningCredentialsRequest(
                    sandboxName: spec.name,
                    certificateP12: request.certificateP12,
                    certificatePassword: request.certificatePassword,
                    provisioningProfile: request.provisioningProfile,
                    keychainName: request.keychainName,
                    keychainPassword: request.keychainPassword
                )
            )
        }
    }

    /// Retrieves and displays logs from the sandbox VM.
    public func logs(_ request: NamedSandboxRequest) throws -> CommandResult {
        let spec = try metadataStore.readSpec(named: request.sandboxName)
        let logs = try backend(for: spec).logs(request.sandboxName)
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

    /// Adds a host folder to the sandbox's shared folders list.
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

    /// Lists all shared folders for a sandbox.
    public func listFolders(_ request: NamedSandboxRequest) throws -> CommandResult {
        let folders = try metadataStore.readSpec(named: request.sandboxName).sharedFolders
        for line in FolderListPresenter().lines(for: folders) {
            writeOutput(line)
        }
        return .success
    }

    /// Removes a host folder from the sandbox's shared folders.
    public func removeFolder(_ request: RemoveFolderRequest) throws -> CommandResult {
        try metadataStore.withLifecycleMutationLock {
            let current = try metadataStore.readSpec(named: request.sandboxName)
            let updated = folderPolicy.removeFolder(from: current, displayHostPath: request.displayHostPath)
            return try applyConfigMutation(current: current, updated: updated) ? .success : .failure(exitCode: 1)
        }
    }

    private func localCloneSource(for request: CreateRequest) throws -> LocalCloneRequest? {
        guard let sourceReference = request.sourceReference, let sourceName = try? SandboxName(sourceReference) else { return nil }
        let sourceSpec: SandboxSpec
        do {
            sourceSpec = try metadataStore.readSpec(named: sourceName)
        } catch HostMetadataError.specNotFound(_) {
            return nil
        }
        let sourceDefaults = ResourceProfile.default(for: sourceSpec.guestOS)
        let requestDefaults = ResourceProfile.default(for: request.guestOS)
        let resourceProfile = request.resourceProfile == requestDefaults ? sourceDefaults : request.resourceProfile
        let spec = SandboxSpec.generated(
            name: request.sandboxName,
            image: SandboxImage(reference: sourceName.rawValue),
            guestOS: sourceSpec.guestOS,
            resourceProfile: resourceProfile,
            diskSize: request.diskSize ?? sourceSpec.diskSize,
            displayResolution: request.displayResolution ?? sourceSpec.displayResolution
        )
        return LocalCloneRequest(sourceSpec: sourceSpec, spec: spec)
    }

    // Blocks the frictionless shell/run path until a setup-required IPSW base
    // has been bootstrapped, pointing the user at the first-boot + bootstrap flow.
    private func requireBootstrapped(_ spec: SandboxSpec) throws {
        guard spec.bootstrapState == .setupRequired else { return }
        throw SandboxBootstrapError.setupRequired(spec.name.rawValue)
    }

    private func backend(for spec: SandboxSpec) throws -> any SandboxBackend {
        try backendResolver.backend(for: spec.guestOS)
    }

    private func mappedWorkingDirectory(for spec: SandboxSpec) -> WorkingDirectoryMapping {
        let mapping = workingDirectoryMapper.map(hostCurrentDirectory: metadataStore.currentHostDirectory(), spec: spec)
        guard spec.guestOS == .macOS, mapping.warning != nil, mapping.guestPath.rawValue == "/workspace" else {
            return mapping
        }
        return WorkingDirectoryMapping(
            guestPath: try! GuestPath("/Users/admin"),
            warning: "Current directory is not inside an Shared Folder; starting in /Users/admin."
        )
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
        let backend = try backend(for: updated)
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
private struct LocalCloneRequest {
    var sourceSpec: SandboxSpec
    var spec: SandboxSpec
}

public struct AlwaysProceedPromptConfirmation: PromptConfirmation {
    public init() {}

    public func confirm(_ request: ConfirmationRequest) throws -> ConfirmationDecision {
        .proceed
    }
}
