import Foundation
import SandCore

let metadataStore = FileHostMetadataStore()
let backend = AppleContainerCLIBackend()
let application = LifecycleCoordinator(metadataStore: metadataStore, backend: backend)
let router = CLICommandRouter(application: application)

do {
    _ = try router.dispatch(arguments: Array(CommandLine.arguments.dropFirst()))
} catch {
    FileHandle.standardError.write(Data("sand: \(error)\n".utf8))
    Foundation.exit(1)
}
