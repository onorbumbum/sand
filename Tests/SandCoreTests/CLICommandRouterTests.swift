import XCTest
@testable import SandCore

final class CLICommandRouterTests: XCTestCase {
    func testCommandResultCarriesProcessExitCode() {
        XCTAssertEqual(CommandResult.success.processExitCode, 0)
        XCTAssertEqual(CommandResult.failure(exitCode: 42).processExitCode, 42)
    }

    func testTopLevelHelpAndVersionPrintWithoutCallingApplication() throws {
        let app = RecordingSandboxApplication()
        var output: [String] = []
        let router = CLICommandRouter(application: app, writeOutput: { output.append($0) })

        XCTAssertEqual(try router.dispatch(arguments: ["--help"]), .success)
        XCTAssertEqual(try router.dispatch(arguments: ["--version"]), .success)

        XCTAssertTrue(output[0].contains("Usage: sand <command>"))
        XCTAssertTrue(output[0].contains("doctor"))
        XCTAssertTrue(output[0].contains("signing <action>"))
        XCTAssertTrue(output[0].contains("run <name>"))
        XCTAssertEqual(output[1], "sand 0.2.4-dev")
        XCTAssertEqual(app.calls, [])
    }

    func testSupportedCommandHelpPrintsWithoutCallingApplication() throws {
        let app = RecordingSandboxApplication()
        var output: [String] = []
        let router = CLICommandRouter(application: app, writeOutput: { output.append($0) })

        XCTAssertEqual(try router.dispatch(arguments: ["create", "--help"]), .success)
        XCTAssertEqual(try router.dispatch(arguments: ["bootstrap", "--help"]), .success)
        XCTAssertEqual(try router.dispatch(arguments: ["delete", "--help"]), .success)
        XCTAssertEqual(try router.dispatch(arguments: ["apply", "--help"]), .success)
        XCTAssertEqual(try router.dispatch(arguments: ["folders", "--help"]), .success)
        XCTAssertEqual(try router.dispatch(arguments: ["signing", "--help"]), .success)
        XCTAssertEqual(try router.dispatch(arguments: ["gui", "--help"]), .success)

        XCTAssertTrue(output[0].contains("Usage: sand create <name>"))
        XCTAssertTrue(output[0].contains("--os <linux|macos>"))
        XCTAssertTrue(output[0].contains("--disk <size>"))
        XCTAssertTrue(output[0].contains("macOS-only create-time Disk Size"))
        XCTAssertTrue(output[0].contains("sand gui <name>"))
        XCTAssertTrue(output[1].contains("Usage: sand bootstrap <name>"))
        XCTAssertTrue(output[1].contains("Prepares a self-built macOS Sandbox VM"))
        XCTAssertTrue(output[1].contains("Cloned Tart registry images"))
        XCTAssertTrue(output[2].contains("Usage: sand delete <name>"))
        XCTAssertTrue(output[2].contains("--force"))
        XCTAssertTrue(output[3].contains("Usage: sand apply <name>"))
        XCTAssertTrue(output[4].contains("Usage: sand folders <action>"))
        XCTAssertTrue(output[4].contains("folders add <name> <host-path> <rw|ro>"))
        XCTAssertTrue(output[5].contains("Usage: sand signing install <name>"))
        XCTAssertTrue(output[5].contains("Host Mac keychain is never mounted or shared"))
        XCTAssertTrue(output[6].contains("Usage: sand gui <name>"))
        XCTAssertEqual(app.calls, [])
    }

    func testParsesEveryV1CommandShape() throws {
        let authoredSpecText = """
        schemaVersion: 1
        name: mybox
        image: sand/developer-ready:ubuntu-lts
        resources:
          cpus: 4
          memory: 8GB
        sharedFolders:
          []
        """
        let cases: [(arguments: [String], expected: AppCall)] = [
            (["doctor"], .doctor),
            (["create", "mybox"], .create("mybox", nil, "sand/developer-ready:ubuntu-lts", "linux", 4, 8192, nil, nil, nil)),
            (["create", "mybox", "--from", "spec.yaml"], .create("mybox", authoredSpecText, "sand/developer-ready:ubuntu-lts", "linux", 4, 8192, nil, nil, nil)),
            (["create", "--from", "spec.yaml"], .create("mybox", authoredSpecText, "sand/developer-ready:ubuntu-lts", "linux", 4, 8192, nil, nil, nil)),
            (["create", "mybox", "--cpus", "6", "--memory", "12GB", "--image", "custom:latest"], .create("mybox", nil, "custom:latest", "linux", 6, 12288, nil, nil, nil)),
            (["create", "mybox", "--os", "macos", "--from", "ghcr.io/cirruslabs/macos-sequoia-xcode:latest"], .create("mybox", nil, "ghcr.io/cirruslabs/macos-sequoia-xcode:latest", "macos", 4, 16384, nil, "ghcr.io/cirruslabs/macos-sequoia-xcode:latest", nil)),
            (["create", "mybox", "--os", "macos", "--memory", "8GB", "--disk", "150GB", "--from", "ghcr.io/cirruslabs/macos-sequoia-xcode:latest"], .create("mybox", nil, "ghcr.io/cirruslabs/macos-sequoia-xcode:latest", "macos", 4, 8192, "150GB", "ghcr.io/cirruslabs/macos-sequoia-xcode:latest", nil)),
            (["create", "mybox", "--from", "cleanbox"], .create("mybox", nil, "cleanbox", "linux", 4, 8192, nil, "cleanbox", nil)),
            (["create", "mybox", "--from-ipsw", "latest"], .create("mybox", nil, "ipsw:latest", "macos", 4, 16384, nil, nil, "latest")),
            (["create", "mybox", "--os", "macos", "--from-ipsw", "/images/macos.ipsw"], .create("mybox", nil, "ipsw:/images/macos.ipsw", "macos", 4, 16384, nil, nil, "/images/macos.ipsw")),
            (["bootstrap", "mybox"], .bootstrap("mybox")),
            (["list"], .list),
            (["apply", "mybox"], .apply("mybox")),
            (["delete", "mybox"], .delete("mybox", false)),
            (["delete", "mybox", "--force"], .delete("mybox", true)),
            (["status", "mybox"], .status("mybox")),
            (["start", "mybox"], .start("mybox")),
            (["stop", "mybox"], .stop("mybox")),
            (["shell", "mybox"], .shell("mybox")),
            (["run", "mybox", "echo", "hello"], .run("mybox", ["echo", "hello"])),
            (["gui", "mybox"], .gui("mybox")),
            (["logs", "mybox"], .logs("mybox")),
            (["spec", "mybox"], .spec("mybox")),
            (["folders", "add", "mybox", "~/Projects", "rw"], .addFolder("mybox", "~/Projects", "rw", nil)),
            (["folders", "add", "mybox", "~/Projects", "ro", "--as", "/code"], .addFolder("mybox", "~/Projects", "ro", "/code")),
            (["folders", "list", "mybox"], .listFolders("mybox")),
            (["folders", "remove", "mybox", "~/Projects"], .removeFolder("mybox", "~/Projects")),
            (["signing", "install", "mybox", "--certificate", "cert.p12", "--certificate-password", "cert-pass", "--profile", "app.mobileprovision", "--keychain-password", "kc-pass"], .installSigningCredentials("mybox", "CERT", "cert-pass", "PROFILE", "sand-signing", "kc-pass")),
            (["signing", "install", "mybox", "--certificate", "cert.p12", "--certificate-password", "cert-pass", "--profile", "app.mobileprovision", "--keychain", "ci-signing", "--keychain-password", "kc-pass"], .installSigningCredentials("mybox", "CERT", "cert-pass", "PROFILE", "ci-signing", "kc-pass"))
        ]

        for testCase in cases {
            let app = RecordingSandboxApplication()
            let router = CLICommandRouter(application: app, readTextFile: { path in
                XCTAssertEqual(path, "spec.yaml")
                return authoredSpecText
            }, readBinaryFile: { path in
                switch path {
                case "cert.p12": return Data("CERT".utf8)
                case "app.mobileprovision": return Data("PROFILE".utf8)
                default: XCTFail("unexpected binary path: \(path)"); return Data()
                }
            })

            XCTAssertEqual(try router.dispatch(arguments: testCase.arguments), .success, "\(testCase.arguments)")
            XCTAssertEqual(app.calls, [testCase.expected], "\(testCase.arguments)")
        }
    }

    func testSigningInstallReadsCertificatePasswordFromEnvironment() throws {
        let app = RecordingSandboxApplication()
        let router = CLICommandRouter(
            application: app,
            readBinaryFile: { path in
                switch path {
                case "cert.p12": return Data("CERT".utf8)
                case "app.mobileprovision": return Data("PROFILE".utf8)
                default: XCTFail("unexpected binary path: \(path)"); return Data()
                }
            },
            readEnvironment: { ["CERT_PW": "cert-pass"][$0] }
        )

        let result = try router.dispatch(arguments: [
            "signing", "install", "mybox",
            "--certificate", "cert.p12",
            "--certificate-password-env", "CERT_PW",
            "--profile", "app.mobileprovision",
            "--keychain-password", "kc-pass"
        ])

        XCTAssertEqual(result, .success)
        XCTAssertEqual(app.calls, [.installSigningCredentials("mybox", "CERT", "cert-pass", "PROFILE", "sand-signing", "kc-pass")])
    }

    func testSigningInstallReadsBothPasswordsFromEnvironment() throws {
        let app = RecordingSandboxApplication()
        let router = CLICommandRouter(
            application: app,
            readBinaryFile: { path in
                switch path {
                case "cert.p12": return Data("CERT".utf8)
                case "app.mobileprovision": return Data("PROFILE".utf8)
                default: XCTFail("unexpected binary path: \(path)"); return Data()
                }
            },
            readEnvironment: { ["CERT_PW": "cert-pass", "KC_PW": "kc-pass"][$0] }
        )

        let result = try router.dispatch(arguments: [
            "signing", "install", "mybox",
            "--certificate", "cert.p12",
            "--certificate-password-env", "CERT_PW",
            "--profile", "app.mobileprovision",
            "--keychain-password-env", "KC_PW"
        ])

        XCTAssertEqual(result, .success)
        XCTAssertEqual(app.calls, [.installSigningCredentials("mybox", "CERT", "cert-pass", "PROFILE", "sand-signing", "kc-pass")])
    }

    func testSigningInstallRejectsBothLiteralAndEnvironmentPassword() throws {
        let app = RecordingSandboxApplication()
        let router = CLICommandRouter(
            application: app,
            readBinaryFile: { _ in Data("X".utf8) },
            readEnvironment: { ["CERT_PW": "cert-pass"][$0] }
        )

        XCTAssertThrowsError(try router.dispatch(arguments: [
            "signing", "install", "mybox",
            "--certificate", "cert.p12",
            "--certificate-password", "cert-pass",
            "--certificate-password-env", "CERT_PW",
            "--profile", "app.mobileprovision",
            "--keychain-password", "kc-pass"
        ])) { error in
            XCTAssertEqual(error as? CLICommandError, .conflictingOptions("--certificate-password", "--certificate-password-env"))
        }
        XCTAssertEqual(app.calls, [])
    }

    func testSigningInstallRejectsUnsetEnvironmentPassword() throws {
        let app = RecordingSandboxApplication()
        let router = CLICommandRouter(
            application: app,
            readBinaryFile: { _ in Data("X".utf8) },
            readEnvironment: { _ in nil }
        )

        XCTAssertThrowsError(try router.dispatch(arguments: [
            "signing", "install", "mybox",
            "--certificate", "cert.p12",
            "--certificate-password-env", "CERT_PW",
            "--profile", "app.mobileprovision",
            "--keychain-password", "kc-pass"
        ])) { error in
            XCTAssertEqual(error as? CLICommandError, .missingEnvironmentValue("--certificate-password-env", "CERT_PW"))
        }
        XCTAssertEqual(app.calls, [])
    }

    func testRunCommandDispatchesOpaqueWorkloadThroughLifecycleBoundaryUnchangedAndDoesNotSpecialCasePi() throws {
        let app = RecordingSandboxApplication()
        let router = CLICommandRouter(application: app)

        let result = try router.dispatch(arguments: ["run", "mybox", "pi", "--model", "gpt-5", "--", "literal"])

        XCTAssertEqual(result, .success)
        XCTAssertEqual(app.calls, [.run("mybox", ["pi", "--model", "gpt-5", "--", "literal"])])
    }

    func testCreateFromSpecRejectsExplicitNameThatDoesNotMatchSpecName() throws {
        let router = CLICommandRouter(application: RecordingSandboxApplication(), readTextFile: { _ in
            """
            schemaVersion: 1
            name: declared
            image: sand/developer-ready:ubuntu-lts
            resources:
              cpus: 4
              memory: 8GB
            sharedFolders:
              []
            """
        })

        XCTAssertThrowsError(try router.dispatch(arguments: ["create", "requested", "--from", "spec.yaml"])) { error in
            XCTAssertEqual(error as? CLICommandError, .specNameMismatch(expected: "requested", actual: "declared"))
        }
    }

    func testAbsentV1CommandSurfaceIsRejected() throws {
        let router = CLICommandRouter(application: RecordingSandboxApplication())

        XCTAssertThrowsError(try router.dispatch(arguments: ["reset", "mybox"])) { error in
            XCTAssertEqual(error as? CLICommandError, .unsupportedCommand("reset"))
        }
        XCTAssertThrowsError(try router.dispatch(arguments: ["reset", "--help"])) { error in
            XCTAssertEqual(error as? CLICommandError, .unsupportedCommand("reset"))
        }
        XCTAssertThrowsError(try router.dispatch(arguments: ["status", "mybox", "pi"])) { error in
            XCTAssertEqual(error as? CLICommandError, .missingArgument("status <name>"))
        }
        XCTAssertThrowsError(try router.dispatch(arguments: ["create", "mybox", "--inbound", "8080:8080"])) { error in
            XCTAssertEqual(error as? CLICommandError, .unsupportedOption("--inbound"))
        }
        XCTAssertThrowsError(try router.dispatch(arguments: ["mybox", "status"])) { error in
            XCTAssertEqual(error as? CLICommandError, .unsupportedCommand("mybox"))
        }
        XCTAssertThrowsError(try router.dispatch(arguments: ["mybox", "gui"])) { error in
            XCTAssertEqual(error as? CLICommandError, .unsupportedCommand("mybox"))
        }
    }

    func testCreateMacOSWithoutSourceRejectsWithSourceChoices() throws {
        let app = RecordingSandboxApplication()
        let router = CLICommandRouter(application: app)

        XCTAssertThrowsError(try router.dispatch(arguments: ["create", "mybox", "--os", "macos"])) { error in
            XCTAssertEqual(error as? CLICommandError, .macOSSourceRequired)
            let message = String(describing: error)
            XCTAssertTrue(message.contains("--from <image-or-local-sandbox>"))
            XCTAssertTrue(message.contains("--from-ipsw <latest|path|url>"))
        }
        XCTAssertEqual(app.calls, [])
    }

    func testCreateRejectsConflictingFromAndFromIPSWSources() throws {
        let router = CLICommandRouter(application: RecordingSandboxApplication())

        XCTAssertThrowsError(try router.dispatch(arguments: ["create", "mybox", "--from", "cleanbox", "--from-ipsw", "latest"])) { error in
            XCTAssertEqual(error as? CLICommandError, .conflictingOptions("--from", "--from-ipsw"))
        }
    }
}

private final class RecordingSandboxApplication: SandboxApplication {
    var calls: [AppCall] = []

    func doctor() throws -> CommandResult { calls.append(.doctor); return .success }
    func create(_ request: CreateRequest) throws -> CommandResult {
        calls.append(.create(request.sandboxName.rawValue, request.authoredSpecText, request.image.reference, request.guestOS.rawValue, request.resourceProfile.cpus, request.resourceProfile.memory.megabytes, request.diskSize?.description, request.sourceReference, request.ipswSource)); return .success
    }
    func bootstrap(_ request: NamedSandboxRequest) throws -> CommandResult { calls.append(.bootstrap(request.sandboxName.rawValue)); return .success }
    func list() throws -> CommandResult { calls.append(.list); return .success }
    func apply(_ request: NamedSandboxRequest) throws -> CommandResult { calls.append(.apply(request.sandboxName.rawValue)); return .success }
    func delete(_ request: DeleteRequest) throws -> CommandResult { calls.append(.delete(request.sandboxName.rawValue, request.force)); return .success }
    func status(_ request: NamedSandboxRequest) throws -> CommandResult { calls.append(.status(request.sandboxName.rawValue)); return .success }
    func start(_ request: NamedSandboxRequest) throws -> CommandResult { calls.append(.start(request.sandboxName.rawValue)); return .success }
    func stop(_ request: NamedSandboxRequest) throws -> CommandResult { calls.append(.stop(request.sandboxName.rawValue)); return .success }
    func shell(_ request: ShellRequest) throws -> CommandResult { calls.append(.shell(request.sandboxName.rawValue)); return .success }
    func run(_ request: RunRequest) throws -> CommandResult { calls.append(.run(request.sandboxName.rawValue, request.command.arguments)); return .success }
    func gui(_ request: GUIRequest) throws -> CommandResult { calls.append(.gui(request.sandboxName.rawValue)); return .success }
    func logs(_ request: NamedSandboxRequest) throws -> CommandResult { calls.append(.logs(request.sandboxName.rawValue)); return .success }
    func spec(_ request: NamedSandboxRequest) throws -> CommandResult { calls.append(.spec(request.sandboxName.rawValue)); return .success }
    func addFolder(_ request: AddFolderRequest) throws -> CommandResult { calls.append(.addFolder(request.sandboxName.rawValue, request.displayHostPath, request.accessMode, request.guestPath?.rawValue)); return .success }
    func listFolders(_ request: NamedSandboxRequest) throws -> CommandResult { calls.append(.listFolders(request.sandboxName.rawValue)); return .success }
    func removeFolder(_ request: RemoveFolderRequest) throws -> CommandResult { calls.append(.removeFolder(request.sandboxName.rawValue, request.displayHostPath)); return .success }
    func installSigningCredentials(_ request: SigningCredentialsRequest) throws -> CommandResult {
        calls.append(.installSigningCredentials(request.sandboxName.rawValue, String(decoding: request.certificateP12, as: UTF8.self), request.certificatePassword, String(decoding: request.provisioningProfile, as: UTF8.self), request.keychainName, request.keychainPassword)); return .success
    }
}

private enum AppCall: Equatable {
    case doctor
    case create(String, String?, String, String, Int, Int, String?, String?, String?)
    case bootstrap(String)
    case list
    case apply(String)
    case delete(String, Bool)
    case status(String)
    case start(String)
    case stop(String)
    case shell(String)
    case run(String, [String])
    case gui(String)
    case logs(String)
    case spec(String)
    case addFolder(String, String, String, String?)
    case listFolders(String)
    case removeFolder(String, String)
    case installSigningCredentials(String, String, String, String, String, String)
}
