import XCTest
@testable import SandCore

final class DoctorChecksTests: XCTestCase {
    func testReportsUnsupportedHostPlatformBeforeProbingBackend() throws {
        let backend = RecordingSandboxBackend()
        let checks = DoctorChecks(
            backend: backend,
            metadataStore: MemoryMetadataStore(),
            platform: FixedDoctorPlatform(isSupported: false)
        )

        let report = try checks.run()

        XCTAssertFalse(report.isHealthy)
        XCTAssertEqual(report.findings, [
            DoctorFinding(
                kind: .unsupportedPlatform,
                message: "Sandbox VM requires Apple silicon macOS on this Host Mac. Run sand on an Apple silicon Mac before creating Sandbox VMs."
            )
        ])
        XCTAssertEqual(backend.calls, [])
    }

    func testReportsUnwritableHostMetadataAsSandboxVMPrerequisiteFailure() throws {
        let checks = DoctorChecks(
            backend: RecordingSandboxBackend(),
            metadataStore: MemoryMetadataStore(writable: false),
            platform: FixedDoctorPlatform(isSupported: true)
        )

        let report = try checks.run()

        XCTAssertFalse(report.isHealthy)
        XCTAssertEqual(report.findings, [
            DoctorFinding(
                kind: .unwritableHostMetadata,
                message: "Host Metadata under ~/.sand is not writable. Fix the ~/.sand permissions or free the disk before creating Sandbox VMs."
            )
        ])
    }
}

private struct FixedDoctorPlatform: DoctorPlatform {
    var isSupported: Bool
}
