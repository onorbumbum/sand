import Foundation
import SandCore

/// Entry point for the `sand` CLI application.
///
/// Initializes the application components and dispatches command-line
/// arguments to the appropriate handler. Sets up:
///
/// - `FileHostMetadataStore` for persisting sandbox specifications
/// - Guest OS backend resolver for VM operations
/// - `LifecycleCoordinator` to orchestrate commands
/// - `CLICommandRouter` to parse and dispatch arguments
///
/// # Exit Codes
/// - `0`: Successful execution
/// - `1`: Error occurred during processing
let metadataStore = FileHostMetadataStore()
let writeProgress: (String) -> Void = { FileHandle.standardError.write(Data($0.utf8)) }
let backendResolver = GuestOSBackendResolver(
    linuxBackend: AppleContainerCLIBackend(),
    macOSBackend: TartCLIBackend(writeProgress: writeProgress)
)
let application = LifecycleCoordinator(metadataStore: metadataStore, backendResolver: backendResolver, prompt: StandardInputPromptConfirmation())
let router = CLICommandRouter(application: application)

// Dispatches the command-line arguments and exits with the result code.
do {
    let result = try router.dispatch(arguments: Array(CommandLine.arguments.dropFirst()))
    Foundation.exit(result.processExitCode)
} catch {
    FileHandle.standardError.write(Data("sand: \(error)\n".utf8))
    Foundation.exit(1)
}