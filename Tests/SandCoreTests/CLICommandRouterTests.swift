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
        XCTAssertTrue(output[0].contains("sand ephemeral --from <ephemeral-spec.yaml> [-- <workload override...>]"))
        XCTAssertTrue(output[0].contains("sand ephemeral init <path> [--force]"))
        XCTAssertTrue(output[0].contains("sand ephemeral init --stdout"))
        XCTAssertTrue(output[0].contains("<name> run"))
        XCTAssertEqual(output[1], "sand 0.2.1-dev")
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
        XCTAssertEqual(try router.dispatch(arguments: ["ephemeral", "--help"]), .success)
        XCTAssertEqual(try router.dispatch(arguments: ["mybox", "--help"]), .success)

        XCTAssertTrue(output[0].contains("Usage: sand create <name>"))
        XCTAssertTrue(output[0].contains("--from <spec.yaml>"))
        XCTAssertTrue(output[1].contains("Usage: sand delete <name>"))
        XCTAssertTrue(output[1].contains("--force"))
        XCTAssertTrue(output[2].contains("Usage: sand apply <name>"))
        XCTAssertTrue(output[3].contains("Usage: sand folders <action>"))
        XCTAssertTrue(output[3].contains("folders add <name> <host-path> <rw|ro>"))
        XCTAssertTrue(output[4].contains("Usage: sand ephemeral --from <ephemeral-spec.yaml> [-- <workload override...>]"))
        XCTAssertTrue(output[4].contains("sand ephemeral init <path> [--force]"))
        XCTAssertTrue(output[4].contains("sand ephemeral init --stdout"))
        XCTAssertTrue(output[4].contains("writes a starter Ephemeral Spec YAML file"))
        XCTAssertTrue(output[4].contains("does not create a Sandbox VM"))
        XCTAssertTrue(output[5].contains("Usage: sand <name> <action>"))
        XCTAssertTrue(output[5].contains("run <command> [args...]"))
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

    func testEphemeralInitWritesStarterSpecThatParsesAndDoesNotCallApplication() throws {
        let tempDirectory = try makeTemporaryDirectory()
        let specPath = tempDirectory.appendingPathComponent("ephemeral-spec.yaml").path
        let app = RecordingSandboxApplication()
        let router = CLICommandRouter(application: app)

        let result = try router.dispatch(arguments: ["ephemeral", "init", specPath])

        XCTAssertEqual(result, .success)
        XCTAssertEqual(app.calls, [])
        let template = try String(contentsOfFile: specPath, encoding: .utf8)
        let spec = try EphemeralSpec.parseYAML(template)
        let plan = try EphemeralRunPlan.build(from: spec)
        XCTAssertEqual(spec.schemaVersion, 1)
        XCTAssertEqual(spec.description, "Easy ephemeral smoke test")
        XCTAssertEqual(spec.namePrefix, "smoke")
        XCTAssertEqual(spec.beforeProvisionHooks.map(\.command.arguments), [[
            "sh",
            "-lc",
            "mkdir -p work && echo \"beforeProvision prepared work\" > work/output.txt"
        ]])
        XCTAssertEqual(spec.allowedFolders.map(\.hostPath), ["./work"])
        XCTAssertEqual(spec.allowedFolders.map(\.guestPath?.rawValue), ["/workspace"])
        XCTAssertEqual(spec.allowedFolders.map(\.accessMode), [.readWrite])
        XCTAssertEqual(plan.workload.command.arguments, [
            "sh",
            "-lc",
            "echo \"workload wrote from Sandbox Guest\" >> /workspace/output.txt && ls -la /workspace >> /workspace/output.txt"
        ])
        XCTAssertEqual(plan.workload.workdir.rawValue, "/workspace")
        XCTAssertEqual(spec.afterStopHooks.map(\.command.arguments), [[
            "sh",
            "-lc",
            "echo \"afterStop processed host-visible output\" >> work/output.txt && cp work/output.txt work/after-stop.txt && cat work/after-stop.txt"
        ]])
    }

    func testEphemeralInitRefusesOverwriteUnlessForce() throws {
        let tempDirectory = try makeTemporaryDirectory()
        let specPath = tempDirectory.appendingPathComponent("ephemeral-spec.yaml").path
        try "original\n".write(toFile: specPath, atomically: true, encoding: .utf8)
        let app = RecordingSandboxApplication()
        let router = CLICommandRouter(application: app)

        XCTAssertThrowsError(try router.dispatch(arguments: ["ephemeral", "init", specPath])) { error in
            XCTAssertTrue(String(describing: error).contains("refusing to overwrite existing file"), "got \(error)")
            XCTAssertTrue(String(describing: error).contains("--force"), "got \(error)")
        }
        XCTAssertEqual(try String(contentsOfFile: specPath, encoding: .utf8), "original\n")

        XCTAssertEqual(try router.dispatch(arguments: ["ephemeral", "init", specPath, "--force"]), .success)
        XCTAssertNotEqual(try String(contentsOfFile: specPath, encoding: .utf8), "original\n")
        XCTAssertEqual(app.calls, [])
    }

    func testEphemeralInitStdoutPrintsTemplateWithoutPathOrSideEffects() throws {
        let app = RecordingSandboxApplication()
        var output: [String] = []
        let router = CLICommandRouter(application: app, writeOutput: { output.append($0) })

        XCTAssertEqual(try router.dispatch(arguments: ["ephemeral", "init", "--stdout"]), .success)

        XCTAssertEqual(output.count, 1)
        guard let template = output.first else { return }
        XCTAssertNoThrow(try EphemeralRunPlan.build(from: EphemeralSpec.parseYAML(template)))
        XCTAssertEqual(app.calls, [])
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

private func makeTemporaryDirectory() throws -> URL {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("sand-cli-router-tests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
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
