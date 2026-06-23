import Foundation

/// Backend implementation using the tart CLI for macOS guests.
public struct TartCLIBackend: SandboxBackend {
    private let runner: any BackendCommandRunner
    private let sshRunner: any BackendCommandRunner
    private let starter: any TartVMStarter
    private let keyStore: any TartSSHKeyStore
    private let screenSharing: any TartScreenSharingOpener
    private let sleeper: (TimeInterval) -> Void
    private let maxIPAttempts: Int

    public init(
        runner: any BackendCommandRunner = ProcessBackendCommandRunner(executable: "tart"),
        sshRunner: any BackendCommandRunner = ProcessBackendCommandRunner(executable: "ssh"),
        starter: any TartVMStarter = ProcessTartVMStarter(),
        keyStore: any TartSSHKeyStore = FileTartSSHKeyStore(),
        screenSharing: any TartScreenSharingOpener = ProcessTartScreenSharingOpener(),
        sleeper: @escaping (TimeInterval) -> Void = { Thread.sleep(forTimeInterval: $0) },
        maxIPAttempts: Int = 60
    ) {
        self.runner = runner
        self.sshRunner = sshRunner
        self.starter = starter
        self.keyStore = keyStore
        self.screenSharing = screenSharing
        self.sleeper = sleeper
        self.maxIPAttempts = maxIPAttempts
    }

    public func checkReadiness() throws -> BackendReadiness {
        guard commandSucceeds(["--version"]) else {
            return .notReady([
                DoctorFinding(
                    kind: .backendExecutableMissing,
                    message: "tart executable is not available. Install it with `brew install cirruslabs/cli/tart` and retry."
                )
            ])
        }
        return .ready
    }

    public func provision(_ spec: SandboxSpec) throws {
        try ensureInstalled()
        try keyStore.createKeyPair(for: spec.name)
        try runRequiredLogged(["clone", spec.image.reference, spec.name.rawValue], sandboxName: spec.name, logKind: "clone")
        var setArguments = ["set", spec.name.rawValue, "--cpu", String(spec.resourceProfile.cpus), "--memory", String(spec.resourceProfile.memory.megabytes)]
        if let diskSize = spec.diskSize {
            setArguments += ["--disk-size", String(diskSize.gigabytes)]
        }
        _ = try runRequired(setArguments)
        try startVM(spec)
        _ = try waitForIPAddress(spec.name)
        try injectPublicKey(for: spec.name)
        try configureSharedFolderSymlinks(for: spec)
        try stop(spec.name)
    }

    public func apply(_ spec: SandboxSpec) throws {
        let wasRunning = try status(spec.name) == .running
        if wasRunning {
            try stop(spec.name)
            try start(spec)
        }
    }

    public func start(_ spec: SandboxSpec) throws {
        try ensureInstalled()
        try startVM(spec)
        if try ensureSyntheticRootLinks(for: spec) {
            try stop(spec.name)
            try startVM(spec)
        }
        try configureSharedFolderSymlinks(for: spec)
    }

    private func startVM(_ spec: SandboxSpec) throws {
        let logPath = try keyStore.logPath(for: spec.name, kind: "start")
        try starter.start(arguments: runArguments(for: spec), logPath: logPath)
    }

    private func runArguments(for spec: SandboxSpec) -> [String] {
        tartRunArguments(for: spec, graphicsMode: "--no-graphics")
    }

    private func vncRunArguments(for spec: SandboxSpec) -> [String] {
        tartRunArguments(for: spec, graphicsMode: "--vnc")
    }

    private func tartRunArguments(for spec: SandboxSpec, graphicsMode: String) -> [String] {
        var arguments = ["run", graphicsMode, "--root-disk-opts", "sync=full"]
        for folder in spec.sharedFolders {
            arguments += ["--dir", dirArgument(for: folder)]
        }
        arguments.append(spec.name.rawValue)
        return arguments
    }

    private func dirArgument(for folder: SharedFolder) -> String {
        var argument = "\(virtiofsTag(for: folder.guestPath)):\(folder.resolvedHostPath)"
        if folder.accessMode == .readOnly {
            argument += ":ro"
        }
        return argument
    }

    public func stop(_ sandboxName: SandboxName) throws {
        _ = try runRequired(stopArguments(for: sandboxName))
    }

    public func run(_ request: BackendRunRequest) throws -> CommandResult {
        let ipAddress = try waitForIPAddress(request.sandboxName)
        try waitForSSH(sandboxName: request.sandboxName, ipAddress: ipAddress)
        let output = try sshRunner.run(
            arguments: sshArguments(
                sandboxName: request.sandboxName,
                ipAddress: ipAddress,
                remoteCommand: "cd \(shellQuoted(request.workingDirectory.rawValue)) && exec \(request.command.arguments.map(shellQuoted).joined(separator: " "))"
            ),
            io: .inherited
        )
        return output.exitCode == 0 ? .success : .failure(exitCode: output.exitCode)
    }

    public func shell(_ request: BackendShellRequest) throws -> CommandResult {
        let ipAddress = try waitForIPAddress(request.sandboxName)
        try waitForSSH(sandboxName: request.sandboxName, ipAddress: ipAddress)
        let output = try sshRunner.run(
            arguments: sshArguments(
                sandboxName: request.sandboxName,
                ipAddress: ipAddress,
                remoteCommand: "cd \(shellQuoted(request.workingDirectory.rawValue)) && exec /bin/zsh -l"
            ),
            io: .inherited
        )
        return output.exitCode == 0 ? .success : .failure(exitCode: output.exitCode)
    }

    public func gui(_ request: BackendGUIRequest) throws -> CommandResult {
        let logPath = try keyStore.logPath(for: request.spec.name, kind: "gui")
        try starter.start(arguments: vncRunArguments(for: request.spec), logPath: logPath)
        let ipAddress = try waitForIPAddress(request.spec.name)
        try screenSharing.open(url: "vnc://admin@\(ipAddress)")
        return .success
    }

    public func status(_ sandboxName: SandboxName) throws -> SandboxRuntimeStatus {
        let output = try runRequired(["list", "--format", "json"])
        guard let rows = try JSONSerialization.jsonObject(with: Data(output.stdout.utf8)) as? [[String: Any]] else {
            return .missing
        }
        guard let row = rows.first(where: { stringValue($0, "name") == sandboxName.rawValue }) else {
            return .missing
        }
        if let running = boolValue(row, "running") {
            return running ? .running : .stopped
        }
        let status = (stringValue(row, "state") ?? stringValue(row, "status") ?? "").lowercased()
        return status == "running" ? .running : .stopped
    }

    public func logs(_ sandboxName: SandboxName) throws -> SandboxLogs {
        let cloneLog = (try? keyStore.readLog(for: sandboxName, kind: "clone")) ?? ""
        let startLog = (try? keyStore.readLog(for: sandboxName, kind: "start")) ?? ""
        let combined = [cloneLog, startLog].filter { !$0.isEmpty }.joined(separator: "\n")
        return SandboxLogs(text: combined)
    }

    public func delete(_ sandboxName: SandboxName) throws {
        if try status(sandboxName) != .missing {
            _ = try? runner.run(arguments: stopArguments(for: sandboxName))
            _ = try runRequired(["delete", sandboxName.rawValue])
        }
        try keyStore.deleteKeyPair(for: sandboxName)
    }

    private func ensureInstalled() throws {
        guard commandSucceeds(["--version"]) else {
            throw BackendTranslatedError.commandFailed("tart executable is not available. Install it with `brew install cirruslabs/cli/tart` and retry.")
        }
    }

    private func injectPublicKey(for sandboxName: SandboxName) throws {
        let publicKey = try keyStore.publicKey(for: sandboxName).trimmingCharacters(in: .whitespacesAndNewlines)
        let script = "mkdir -p ~/.ssh && chmod 700 ~/.ssh && grep -qxF \(shellQuoted(publicKey)) ~/.ssh/authorized_keys 2>/dev/null || printf '%s\\n' \(shellQuoted(publicKey)) >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && sync"
        _ = try runRequiredRetried(["exec", sandboxName.rawValue, "/bin/zsh", "-lc", script])
    }

    private func ensureSyntheticRootLinks(for spec: SandboxSpec) throws -> Bool {
        let roots = syntheticRootLinks(for: spec.sharedFolders)
        guard !roots.isEmpty else { return false }
        let output = try runRequiredRetried(["exec", spec.name.rawValue, "/bin/zsh", "-lc", syntheticRootLinkScript(for: roots)])
        return output.stdout.contains("SAND_SYNTHETIC_CHANGED")
    }

    private func syntheticRootLinks(for folders: [SharedFolder]) -> [SyntheticRootLink] {
        let existingWritableRoots: Set<String> = ["Users", "Volumes", "tmp", "private", "var"]
        var links: [SyntheticRootLink] = []
        var seen: Set<String> = []
        for folder in folders {
            let components = folder.guestPath.rawValue.split(separator: "/").map(String.init)
            guard let root = components.first, !existingWritableRoots.contains(root), seen.insert(root).inserted else { continue }
            links.append(SyntheticRootLink(name: root, target: "Users/admin/.sand/synthetic/\(root)"))
        }
        return links
    }

    private func syntheticRootLinkScript(for links: [SyntheticRootLink]) -> String {
        var lines = ["set -e", "sudo -n mkdir -p /etc/synthetic.d"]
        for link in links {
            lines.append("mkdir -p \(shellQuoted("/\(link.target)"))")
        }
        let manifest = links.map { "\($0.name)\t\($0.target)" }.joined(separator: "\n") + "\n"
        lines.append("current=$(cat /etc/synthetic.d/sand 2>/dev/null || true)")
        lines.append("desired=\(shellQuoted(manifest))")
        lines.append("needs_restart=0")
        lines.append("if [ \"$current\" != \"$desired\" ]; then printf '%s' \"$desired\" | sudo -n tee /etc/synthetic.d/sand >/dev/null; needs_restart=1; fi")
        for link in links {
            lines.append("if [ ! -e \(shellQuoted("/\(link.name)")) ]; then needs_restart=1; fi")
        }
        lines.append("if [ \"$needs_restart\" = 1 ]; then sync; echo SAND_SYNTHETIC_CHANGED; fi")
        return lines.joined(separator: "\n")
    }

    private func configureSharedFolderSymlinks(for spec: SandboxSpec) throws {
        guard !spec.sharedFolders.isEmpty else { return }
        _ = try runRequiredRetried(["exec", spec.name.rawValue, "/bin/zsh", "-lc", sharedFolderSymlinkScript(for: spec.sharedFolders)])
    }

    private func sharedFolderSymlinkScript(for folders: [SharedFolder]) -> String {
        var lines = ["set -e"]
        for folder in folders {
            let guestPath = folder.guestPath.rawValue
            let parent = parentDirectory(of: guestPath)
            let mountedPath = "/Volumes/My Shared Files/\(virtiofsTag(for: folder.guestPath))"
            lines.append("sudo -n mkdir -p \(shellQuoted(parent))")
            lines.append("if [ -e \(shellQuoted(guestPath)) ] && [ ! -L \(shellQuoted(guestPath)) ]; then echo \(shellQuoted("Guest Path exists and is not a symlink: \(guestPath)")) >&2; exit 1; fi")
            lines.append("sudo -n rm -f \(shellQuoted(guestPath))")
            lines.append("sudo -n ln -s \(shellQuoted(mountedPath)) \(shellQuoted(guestPath))")
        }
        return lines.joined(separator: "\n")
    }

    private func parentDirectory(of path: String) -> String {
        let url = URL(fileURLWithPath: path)
        let parent = url.deletingLastPathComponent().path
        return parent.isEmpty ? "/" : parent
    }

    private func virtiofsTag(for guestPath: GuestPath) -> String {
        let encoded = Data(guestPath.rawValue.utf8)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .trimmingCharacters(in: CharacterSet(charactersIn: "="))
        return "sand-\(encoded)"
    }

    private func waitForIPAddress(_ sandboxName: SandboxName) throws -> String {
        var lastError: (any Error)?
        for attempt in 0..<maxIPAttempts {
            do {
                let output = try runner.run(arguments: ["ip", sandboxName.rawValue])
                let ipAddress = output.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
                if output.exitCode == 0 && !ipAddress.isEmpty { return ipAddress }
                lastError = TartCLIBackendError.commandFailed(arguments: ["ip", sandboxName.rawValue], exitCode: output.exitCode, stderr: output.stderr)
            } catch {
                lastError = error
            }
            if attempt < maxIPAttempts - 1 { sleeper(1) }
        }
        if let lastError { throw translate(lastError, arguments: ["ip", sandboxName.rawValue]) }
        throw BackendTranslatedError.commandFailed("Could not find the macOS Sandbox VM IP address. Run `sand logs \(sandboxName.rawValue)` and retry.")
    }

    private func waitForSSH(sandboxName: SandboxName, ipAddress: String) throws {
        for attempt in 0..<maxIPAttempts {
            do {
                let output = try sshRunner.run(arguments: sshArguments(sandboxName: sandboxName, ipAddress: ipAddress, remoteCommand: "true"))
                if output.exitCode == 0 { return }
            } catch {
                if attempt == maxIPAttempts - 1 { throw translate(error, arguments: ["ssh", sandboxName.rawValue]) }
            }
            if attempt < maxIPAttempts - 1 { sleeper(1) }
        }
        throw BackendTranslatedError.serviceUnavailable("Could not reach the macOS Sandbox VM over SSH yet. Run `sand logs \(sandboxName.rawValue)` and retry.")
    }

    private func commandSucceeds(_ arguments: [String]) -> Bool {
        do { return try runner.run(arguments: arguments).exitCode == 0 } catch { return false }
    }

    private func stringValue(_ row: [String: Any], _ key: String) -> String? {
        (row[key] as? String) ?? (row[key.capitalized] as? String)
    }

    private func boolValue(_ row: [String: Any], _ key: String) -> Bool? {
        (row[key] as? Bool) ?? (row[key.capitalized] as? Bool)
    }

    private func stopArguments(for sandboxName: SandboxName) -> [String] {
        ["stop", sandboxName.rawValue, "--timeout", "120"]
    }

    private func runRequiredLogged(_ arguments: [String], sandboxName: SandboxName, logKind: String) throws {
        do {
            let output = try runner.run(arguments: arguments)
            try keyStore.writeLog("$ tart \(arguments.joined(separator: " "))\n\(output.stdout)\(output.stderr)", for: sandboxName, kind: logKind)
            guard output.exitCode == 0 else {
                throw TartCLIBackendError.commandFailed(arguments: arguments, exitCode: output.exitCode, stderr: output.stderr)
            }
        } catch let error as BackendTranslatedError {
            throw error
        } catch {
            throw translate(error, arguments: arguments)
        }
    }

    private func runRequired(_ arguments: [String]) throws -> BackendCommandOutput {
        do {
            let output = try runner.run(arguments: arguments)
            guard output.exitCode == 0 else {
                throw TartCLIBackendError.commandFailed(arguments: arguments, exitCode: output.exitCode, stderr: output.stderr)
            }
            return output
        } catch let error as BackendTranslatedError {
            throw error
        } catch {
            throw translate(error, arguments: arguments)
        }
    }

    private func runRequiredRetried(_ arguments: [String]) throws -> BackendCommandOutput {
        var lastError: (any Error)?
        for attempt in 0..<maxIPAttempts {
            do {
                return try runRequired(arguments)
            } catch {
                lastError = error
            }
            if attempt < maxIPAttempts - 1 { sleeper(1) }
        }
        if let lastError { throw translate(lastError, arguments: arguments) }
        throw BackendTranslatedError.commandFailed("Could not complete the macOS Sandbox backend operation. Run `sand doctor` and retry.")
    }

    private func translate(_ error: any Error, arguments: [String]) -> BackendTranslatedError {
        if let translated = error as? BackendTranslatedError { return translated }
        if let tartError = error as? TartCLIBackendError { return translate(tartError) }
        return .commandFailed("Could not complete the macOS Sandbox backend operation. Run `sand doctor` and retry.")
    }

    private func translate(_ error: TartCLIBackendError) -> BackendTranslatedError {
        switch error {
        case .commandFailed(let arguments, _, let stderr):
            let detail = stderr.lowercased()
            if arguments.first == "clone" {
                return .commandFailed("Could not clone the macOS Sandbox VM image. Check the image reference and run `sand logs \(arguments.last ?? "")` for details.")
            }
            if detail.contains("env: tart") || detail.contains("tart: no such file") {
                return .commandFailed("tart executable is not available. Install it with `brew install cirruslabs/cli/tart` and retry.")
            }
            if arguments.first == "run" || detail.contains("system limit") {
                return .serviceUnavailable("Could not start the macOS Sandbox VM. Stop another macOS Sandbox VM or run `sand logs \(arguments.last ?? "")` for details.")
            }
            if arguments.first == "ip" {
                return .serviceUnavailable("Could not reach the macOS Sandbox VM over SSH yet. Run `sand logs \(arguments.last ?? "")` and retry.")
            }
            return .commandFailed("Could not complete the macOS Sandbox backend operation. Run `sand doctor` and retry.")
        }
    }

    private func sshArguments(sandboxName: SandboxName, ipAddress: String, remoteCommand: String) throws -> [String] {
        [
            "-i", try keyStore.privateKeyPath(for: sandboxName),
            "-o", "BatchMode=yes",
            "-o", "PasswordAuthentication=no",
            "-o", "StrictHostKeyChecking=no",
            "-o", "UserKnownHostsFile=/dev/null",
            "-o", "ConnectTimeout=5",
            "admin@\(ipAddress)",
            remoteCommand
        ]
    }

    private func shellQuoted(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}

private struct SyntheticRootLink: Equatable {
    var name: String
    var target: String
}

public enum TartCLIBackendError: Error, Equatable, CustomStringConvertible {
    case commandFailed(arguments: [String], exitCode: Int, stderr: String)

    public var description: String {
        switch self {
        case .commandFailed(let arguments, let exitCode, let stderr):
            let detail = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            return "macOS backend command failed (exit \(exitCode)): \(arguments.joined(separator: " "))\(detail.isEmpty ? "" : " — \(detail)")"
        }
    }
}

public protocol TartVMStarter {
    func start(arguments: [String], logPath: String) throws
}

public struct ProcessTartVMStarter: TartVMStarter {
    public init() {}

    public func start(arguments: [String], logPath: String) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["tart"] + arguments
        FileManager.default.createFile(atPath: logPath, contents: nil)
        let logHandle = try FileHandle(forWritingTo: URL(fileURLWithPath: logPath))
        process.standardOutput = logHandle
        process.standardError = logHandle
        try process.run()
    }
}

public protocol TartScreenSharingOpener {
    func open(url: String) throws
}

public struct ProcessTartScreenSharingOpener: TartScreenSharingOpener {
    public init() {}

    public func open(url: String) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = [url]
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw BackendTranslatedError.commandFailed("Could not open the host Screen Sharing app for the macOS Sandbox VM.")
        }
    }
}

public protocol TartSSHKeyStore {
    func createKeyPair(for sandboxName: SandboxName) throws
    func privateKeyPath(for sandboxName: SandboxName) throws -> String
    func publicKey(for sandboxName: SandboxName) throws -> String
    func deleteKeyPair(for sandboxName: SandboxName) throws
    func logPath(for sandboxName: SandboxName, kind: String) throws -> String
    func readLog(for sandboxName: SandboxName, kind: String) throws -> String
    func writeLog(_ text: String, for sandboxName: SandboxName, kind: String) throws
}

public struct FileTartSSHKeyStore: TartSSHKeyStore {
    private let root: URL

    public init(root: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".sand/tart")) {
        self.root = root
    }

    public func createKeyPair(for sandboxName: SandboxName) throws {
        try FileManager.default.createDirectory(at: directory(for: sandboxName), withIntermediateDirectories: true)
        let privateKey = try privateKeyPath(for: sandboxName)
        guard !FileManager.default.fileExists(atPath: privateKey) else { return }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["ssh-keygen", "-q", "-t", "ed25519", "-N", "", "-f", privateKey, "-C", "sand-\(sandboxName.rawValue)"]
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw BackendTranslatedError.commandFailed("Could not generate the macOS Sandbox VM SSH keypair under ~/.sand.")
        }
    }

    public func privateKeyPath(for sandboxName: SandboxName) throws -> String {
        directory(for: sandboxName).appendingPathComponent("id_ed25519").path
    }

    public func publicKey(for sandboxName: SandboxName) throws -> String {
        try String(contentsOf: directory(for: sandboxName).appendingPathComponent("id_ed25519.pub"), encoding: .utf8)
    }

    public func deleteKeyPair(for sandboxName: SandboxName) throws {
        let directory = directory(for: sandboxName)
        if FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.removeItem(at: directory)
        }
    }

    public func logPath(for sandboxName: SandboxName, kind: String) throws -> String {
        try FileManager.default.createDirectory(at: directory(for: sandboxName), withIntermediateDirectories: true)
        return directory(for: sandboxName).appendingPathComponent("\(kind).log").path
    }

    public func readLog(for sandboxName: SandboxName, kind: String) throws -> String {
        try String(contentsOf: URL(fileURLWithPath: logPath(for: sandboxName, kind: kind)), encoding: .utf8)
    }

    public func writeLog(_ text: String, for sandboxName: SandboxName, kind: String) throws {
        try text.write(toFile: logPath(for: sandboxName, kind: kind), atomically: true, encoding: .utf8)
    }

    private func directory(for sandboxName: SandboxName) -> URL {
        root.appendingPathComponent(sandboxName.rawValue, isDirectory: true)
    }
}
