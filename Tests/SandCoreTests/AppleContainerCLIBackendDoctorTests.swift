import XCTest
@testable import SandCore

final class AppleContainerCLIBackendDoctorTests: XCTestCase {
    func testDoctorReportsBackendServiceFailureWithoutMisreportingImageWhenAutoStartFails() throws {
        let runner = ScriptedBackendCommandRunner(results: [
            ["--version"]: .success(BackendCommandOutput(stdout: "container 0.12.3\n", stderr: "", exitCode: 0)),
            ["system", "status"]: .success(BackendCommandOutput(stdout: "status             stopped\n", stderr: "", exitCode: 0)),
            ["system", "start"]: .success(BackendCommandOutput(stdout: "", stderr: "could not start\n", exitCode: 1))
        ])
        let backend = AppleContainerCLIBackend(runner: runner)

        let readiness = try backend.checkReadiness()

        XCTAssertEqual(readiness, .notReady([
            DoctorFinding(
                kind: .backendServiceStopped,
                message: "Backend Service is not running and sand could not auto-start it. Run `container system start` and retry `sand doctor`."
            )
        ]))
        XCTAssertEqual(runner.calls, [
            ["--version"],
            ["system", "status"],
            ["system", "start"],
            ["system", "status"]
        ])
    }

    func testDoctorReportsMissingDefaultSandboxImageAfterBackendServiceIsRunning() throws {
        let runner = ScriptedBackendCommandRunner(results: [
            ["--version"]: .success(BackendCommandOutput(stdout: "container 0.12.3\n", stderr: "", exitCode: 0)),
            ["system", "status"]: .success(BackendCommandOutput(stdout: "status             running\n", stderr: "", exitCode: 0)),
            ["image", "inspect", "sand/developer-ready:ubuntu-lts"]: .success(BackendCommandOutput(stdout: "", stderr: "image not found\n", exitCode: 1))
        ])
        let backend = AppleContainerCLIBackend(runner: runner)

        let readiness = try backend.checkReadiness()

        XCTAssertEqual(readiness, .notReady([
            DoctorFinding(
                kind: .defaultImageMissing,
                message: "Default Sandbox Image sand/developer-ready:ubuntu-lts is not available. Build it with scripts/build-developer-ready-image.sh before creating Sandbox VMs."
            )
        ]))
        XCTAssertEqual(runner.calls, [
            ["--version"],
            ["system", "status"],
            ["image", "inspect", "sand/developer-ready:ubuntu-lts"]
        ])
    }
}

private final class ScriptedBackendCommandRunner: BackendCommandRunner {
    enum Result {
        case success(BackendCommandOutput)
        case failure(any Error)
    }

    private let results: [[String]: Result]
    var calls: [[String]] = []

    init(results: [[String]: Result]) {
        self.results = results
    }

    func run(arguments: [String]) throws -> BackendCommandOutput {
        calls.append(arguments)
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
