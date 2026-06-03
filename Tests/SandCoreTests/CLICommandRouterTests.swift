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
        XCTAssertTrue(output[0].contains("<name> run"))
        XCTAssertEqual(output[1], "sand 0.1.0-dev")
        XCTAssertEqual(app.calls, [])
    }

    func testSupportedCommandHelpPrintsWithoutCallingApplication() throws {
        let app = RecordingSandboxApplication()
        var output: [String] = []
        let router = CLICommandRouter(application: app, writeOutput: { output.append($0) })

        XCTAssertEqual(try router.dispatch(arguments: ["create", "--help"]), .success)
        XCTAssertEqual(try router.dispatch(arguments: ["delete", "--help"]), .success)
        XCTAssertEqual(try router.dispatch(arguments: ["apply", "--help"]), .success)
        XCTAssertEqual(try router.dispatch(arguments: ["folders", "--help"]), .success)
        XCTAssertEqual(try router.dispatch(arguments: ["mybox", "--help"]), .success)

        XCTAssertTrue(output[0].contains("Usage: sand create <name>"))
        XCTAssertTrue(output[0].contains("--from <spec.yaml>"))
        XCTAssertTrue(output[1].contains("Usage: sand delete <name>"))
        XCTAssertTrue(output[1].contains("--force"))
        XCTAssertTrue(output[2].contains("Usage: sand apply <name>"))
        XCTAssertTrue(output[3].contains("Usage: sand folders <action>"))
        XCTAssertTrue(output[3].contains("folders add <name> <host-path> <rw|ro>"))
        XCTAssertTrue(output[4].contains("Usage: sand <name> <action>"))
        XCTAssertTrue(output[4].contains("run <command> [args...]"))
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
        allowedFolders:
          []
        """
        let cases: [(arguments: [String], expected: AppCall)] = [
            (["doctor"], .doctor),
            (["create", "mybox"], .create("mybox", nil, "sand/developer-ready:ubuntu-lts", 4, 8192)),
            (["create", "mybox", "--from", "spec.yaml"], .create("mybox", authoredSpecText, "sand/developer-ready:ubuntu-lts", 4, 8192)),
            (["create", "--from", "spec.yaml"], .create("mybox", authoredSpecText, "sand/developer-ready:ubuntu-lts", 4, 8192)),
            (["create", "mybox", "--cpus", "6", "--memory", "12GB", "--image", "custom:latest"], .create("mybox", nil, "custom:latest", 6, 12288)),
            (["list"], .list),
            (["apply", "mybox"], .apply("mybox")),
            (["delete", "mybox"], .delete("mybox", false)),
            (["delete", "mybox", "--force"], .delete("mybox", true)),
            (["mybox", "status"], .status("mybox")),
            (["mybox", "start"], .start("mybox")),
            (["mybox", "stop"], .stop("mybox")),
            (["mybox", "shell"], .shell("mybox")),
            (["mybox", "run", "echo", "hello"], .run("mybox", ["echo", "hello"])),
            (["mybox", "logs"], .logs("mybox")),
            (["mybox", "spec"], .spec("mybox")),
            (["folders", "add", "mybox", "~/Projects", "rw"], .addFolder("mybox", "~/Projects", "rw", nil)),
            (["folders", "add", "mybox", "~/Projects", "ro", "--as", "/code"], .addFolder("mybox", "~/Projects", "ro", "/code")),
            (["folders", "list", "mybox"], .listFolders("mybox")),
            (["folders", "remove", "mybox", "~/Projects"], .removeFolder("mybox", "~/Projects"))
        ]

        for testCase in cases {
            let app = RecordingSandboxApplication()
            let router = CLICommandRouter(application: app, readTextFile: { path in
                XCTAssertEqual(path, "spec.yaml")
                return authoredSpecText
            })

            XCTAssertEqual(try router.dispatch(arguments: testCase.arguments), .success, "\(testCase.arguments)")
            XCTAssertEqual(app.calls, [testCase.expected], "\(testCase.arguments)")
        }
    }

    func testRunCommandDispatchesOpaqueWorkloadThroughLifecycleBoundaryUnchangedAndDoesNotSpecialCasePi() throws {
        let app = RecordingSandboxApplication()
        let router = CLICommandRouter(application: app)

        let result = try router.dispatch(arguments: ["mybox", "run", "pi", "--model", "gpt-5", "--", "literal"])

        XCTAssertEqual(result, .success)
        XCTAssertEqual(app.calls, [.run("mybox", ["pi", "--model", "gpt-5", "--", "literal"])])
    }

    func testEphemeralFromSpecRoutesAsExplicitTopLevelCommand() throws {
        let specText = """
        schemaVersion: 1
        workload:
          command: echo
          workdir: /workspace
        """
        let app = RecordingSandboxApplication()
        let router = CLICommandRouter(application: app, readTextFile: { path in
            XCTAssertEqual(path, "ephemeral-spec.yaml")
            return specText
        })

        let result = try router.dispatch(arguments: ["ephemeral", "--from", "ephemeral-spec.yaml"])

        XCTAssertEqual(result, .success)
        XCTAssertEqual(app.calls, [.ephemeral(specText, "ephemeral-spec.yaml", nil)])
    }

    func testEphemeralDoubleDashRoutesOpaqueWorkloadOverride() throws {
        let specText = """
        schemaVersion: 1
        workload:
          command: echo
          workdir: /workspace
        """
        let app = RecordingSandboxApplication()
        let router = CLICommandRouter(application: app, readTextFile: { path in
            XCTAssertEqual(path, "ephemeral-spec.yaml")
            return specText
        })

        let result = try router.dispatch(
            arguments: [
                "ephemeral", "--from", "ephemeral-spec.yaml", "--",
                "python", "-m", "pytest", "--maxfail=1", "--", "literal", "--from", "not-a-sand-option"
            ]
        )

        XCTAssertEqual(result, .success)
        XCTAssertEqual(app.calls, [
            .ephemeral(
                specText,
                "ephemeral-spec.yaml",
                ["python", "-m", "pytest", "--maxfail=1", "--", "literal", "--from", "not-a-sand-option"]
            )
        ])
    }

    func testEphemeralTrailingDoubleDashWithoutWorkloadFailsBeforeReadingSpecOrCallingApplication() throws {
        let app = RecordingSandboxApplication()
        var readPaths: [String] = []
        let router = CLICommandRouter(application: app, readTextFile: { path in
            readPaths.append(path)
            return "schemaVersion: 1\n"
        })

        XCTAssertThrowsError(try router.dispatch(arguments: ["ephemeral", "--from", "ephemeral-spec.yaml", "--"])) { error in
            XCTAssertEqual(error as? CLICommandError, .missingArgument("ephemeral --from <ephemeral-spec.yaml> -- <command> [args...]"))
        }
        XCTAssertEqual(readPaths, [])
        XCTAssertEqual(app.calls, [])
    }

    func testEphemeralV1OmittedCommandSurfaceIsRejectedBeforeReadingSpecOrCallingApplication() throws {
        let cases: [([String], CLICommandError)] = [
            (["ephemeral", "--from", "ephemeral-spec.yaml", "--preserveOnFailure"], .unsupportedOption("--preserveOnFailure")),
            (["ephemeral", "--from", "ephemeral-spec.yaml", "--dry-run"], .unsupportedOption("--dry-run")),
            (["ephemeral", "--from", "ephemeral-spec.yaml", "--validate"], .unsupportedOption("--validate")),
            (["ephemeral", "dry-run", "--from", "ephemeral-spec.yaml"], .unsupportedOption("dry-run")),
            (["ephemeral", "validate", "--from", "ephemeral-spec.yaml"], .unsupportedOption("validate")),
            (["ephemeral", "pi", "--from", "ephemeral-spec.yaml"], .unsupportedOption("pi"))
        ]

        for (arguments, expectedError) in cases {
            let app = RecordingSandboxApplication()
            var readPaths: [String] = []
            let router = CLICommandRouter(application: app, readTextFile: { path in
                readPaths.append(path)
                return "schemaVersion: 1\n"
            })

            XCTAssertThrowsError(try router.dispatch(arguments: arguments), "\(arguments)") { error in
                XCTAssertEqual(error as? CLICommandError, expectedError, "\(arguments)")
            }
            XCTAssertEqual(readPaths, [], "\(arguments)")
            XCTAssertEqual(app.calls, [], "\(arguments)")
        }
    }

    func testEphemeralPiIsOnlyANormalWorkloadOverride() throws {
        let specText = "schemaVersion: 1\n"
        let app = RecordingSandboxApplication()
        let router = CLICommandRouter(application: app, readTextFile: { path in
            XCTAssertEqual(path, "ephemeral-spec.yaml")
            return specText
        })

        let result = try router.dispatch(arguments: ["ephemeral", "--from", "ephemeral-spec.yaml", "--", "pi", "login"])

        XCTAssertEqual(result, .success)
        XCTAssertEqual(app.calls, [.ephemeral(specText, "ephemeral-spec.yaml", ["pi", "login"])])
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
            allowedFolders:
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
        XCTAssertThrowsError(try router.dispatch(arguments: ["mybox", "pi"])) { error in
            XCTAssertEqual(error as? CLICommandError, .unsupportedAction("pi"))
        }
        XCTAssertThrowsError(try router.dispatch(arguments: ["mybox", "pi", "--help"])) { error in
            XCTAssertEqual(error as? CLICommandError, .unsupportedAction("pi"))
        }
        XCTAssertThrowsError(try router.dispatch(arguments: ["create", "mybox", "--inbound", "8080:8080"])) { error in
            XCTAssertEqual(error as? CLICommandError, .unsupportedOption("--inbound"))
        }
        XCTAssertThrowsError(try router.dispatch(arguments: ["run", "pi"])) { error in
            XCTAssertEqual(error as? CLICommandError, .unsupportedAction("pi"))
        }
        XCTAssertThrowsError(try router.dispatch(arguments: ["mybox", "edit"])) { error in
            XCTAssertEqual(error as? CLICommandError, .unsupportedAction("edit"))
        }
    }
}

private final class RecordingSandboxApplication: SandboxApplication {
    var calls: [AppCall] = []

    func doctor() throws -> CommandResult { calls.append(.doctor); return .success }
    func create(_ request: CreateRequest) throws -> CommandResult {
        calls.append(.create(request.sandboxName.rawValue, request.authoredSpecText, request.image.reference, request.resourceProfile.cpus, request.resourceProfile.memory.megabytes)); return .success
    }
    func list() throws -> CommandResult { calls.append(.list); return .success }
    func apply(_ request: NamedSandboxRequest) throws -> CommandResult { calls.append(.apply(request.sandboxName.rawValue)); return .success }
    func delete(_ request: DeleteRequest) throws -> CommandResult { calls.append(.delete(request.sandboxName.rawValue, request.force)); return .success }
    func status(_ request: NamedSandboxRequest) throws -> CommandResult { calls.append(.status(request.sandboxName.rawValue)); return .success }
    func start(_ request: NamedSandboxRequest) throws -> CommandResult { calls.append(.start(request.sandboxName.rawValue)); return .success }
    func stop(_ request: NamedSandboxRequest) throws -> CommandResult { calls.append(.stop(request.sandboxName.rawValue)); return .success }
    func shell(_ request: ShellRequest) throws -> CommandResult { calls.append(.shell(request.sandboxName.rawValue)); return .success }
    func run(_ request: RunRequest) throws -> CommandResult { calls.append(.run(request.sandboxName.rawValue, request.command.arguments)); return .success }
    func logs(_ request: NamedSandboxRequest) throws -> CommandResult { calls.append(.logs(request.sandboxName.rawValue)); return .success }
    func spec(_ request: NamedSandboxRequest) throws -> CommandResult { calls.append(.spec(request.sandboxName.rawValue)); return .success }
    func addFolder(_ request: AddFolderRequest) throws -> CommandResult { calls.append(.addFolder(request.sandboxName.rawValue, request.displayHostPath, request.accessMode, request.guestPath?.rawValue)); return .success }
    func listFolders(_ request: NamedSandboxRequest) throws -> CommandResult { calls.append(.listFolders(request.sandboxName.rawValue)); return .success }
    func removeFolder(_ request: RemoveFolderRequest) throws -> CommandResult { calls.append(.removeFolder(request.sandboxName.rawValue, request.displayHostPath)); return .success }
    func ephemeral(_ request: EphemeralRunRequest) throws -> CommandResult { calls.append(.ephemeral(request.authoredSpecText, request.sourcePath, request.workloadOverride?.arguments)); return .success }
}

private enum AppCall: Equatable {
    case doctor
    case create(String, String?, String, Int, Int)
    case list
    case apply(String)
    case delete(String, Bool)
    case status(String)
    case start(String)
    case stop(String)
    case shell(String)
    case run(String, [String])
    case logs(String)
    case spec(String)
    case addFolder(String, String, String, String?)
    case listFolders(String)
    case removeFolder(String, String)
    case ephemeral(String, String, [String]?)
}
