import XCTest
@testable import SandCore

final class BackendErrorTranslationTests: XCTestCase {
    func testLogsTranslateRealAppleMissingRuntimeFixtureToUserFacingSandboxError() throws {
        let fixture = try readFixture("missing-runtime-logs.stderr")
        let runner = ErrorTranslationScriptedBackendCommandRunner(results: [
            ["logs", "sand-does-not-exist-011"]: .success(BackendCommandOutput(stdout: "", stderr: fixture, exitCode: 1))
        ])
        let backend = AppleContainerCLIBackend(runner: runner)

        XCTAssertThrowsError(try backend.logs(try SandboxName("sand-does-not-exist-011"))) { error in
            XCTAssertEqual(
                error as? BackendTranslatedError,
                .runtimeMissing("Sandbox VM `sand-does-not-exist-011` was not found. Create it with `sand create sand-does-not-exist-011` before reading logs.")
            )
            XCTAssertFalse(String(describing: error).contains("container"))
            XCTAssertFalse(String(describing: error).contains("internalError"))
        }
    }

    func testStartReportsBackendServiceFailureInUserFacingLanguage() throws {
        let fixture = try readFixture("service-unavailable-start.stderr")
        let runner = ErrorTranslationScriptedBackendCommandRunner(results: [
            ["start", "mybox"]: .success(BackendCommandOutput(stdout: "", stderr: fixture, exitCode: 1))
        ])
        let backend = AppleContainerCLIBackend(runner: runner)

        XCTAssertThrowsError(try backend.start(SandboxSpec.generated(name: try SandboxName("mybox")))) { error in
            XCTAssertEqual(
                error as? BackendTranslatedError,
                .serviceUnavailable("Sandbox backend service is not available. Run `sand doctor` to repair prerequisites, then retry.")
            )
            XCTAssertFalse(String(describing: error).contains("start mybox"))
        }
    }

    private func readFixture(_ name: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/apple-container")
        return try String(contentsOf: root.appendingPathComponent(name), encoding: .utf8)
    }
}

private final class ErrorTranslationScriptedBackendCommandRunner: BackendCommandRunner {
    enum Result {
        case success(BackendCommandOutput)
        case failure(any Error)
    }

    private let results: [[String]: Result]

    init(results: [[String]: Result]) {
        self.results = results
    }

    func run(arguments: [String], io: BackendCommandIO) throws -> BackendCommandOutput {
        guard let result = results[arguments] else {
            throw UnexpectedBackendCommand(arguments: arguments)
        }
        switch result {
        case .success(let output): return output
        case .failure(let error): throw error
        }
    }
}

private struct UnexpectedBackendCommand: Error, Equatable {
    var arguments: [String]
}
