import XCTest
@testable import SandCore

final class CLICommandRouterTests: XCTestCase {
    func testRunCommandDispatchesOpaqueWorkloadThroughLifecycleBoundary() throws {
        let app = RecordingSandboxApplication()
        let router = CLICommandRouter(application: app)

        let result = try router.dispatch(arguments: ["mybox", "run", "pi", "--model", "gpt-5"])

        XCTAssertEqual(result, .success)
        XCTAssertEqual(app.recordedRuns, [
            RunInvocation(sandboxName: "mybox", command: ["pi", "--model", "gpt-5"])
        ])
    }
}

private final class RecordingSandboxApplication: SandboxApplication {
    var recordedRuns: [RunInvocation] = []

    func run(_ request: RunRequest) throws -> CommandResult {
        recordedRuns.append(RunInvocation(sandboxName: request.sandboxName.rawValue, command: request.command.arguments))
        return .success
    }
}

private struct RunInvocation: Equatable {
    var sandboxName: String
    var command: [String]
}
