import XCTest
@testable import SandCore

final class SandboxSpecTests: XCTestCase {
    func testGeneratedSpecUsesV1DefaultsAndNoUnsupportedFutureFields() throws {
        let spec = SandboxSpec.generated(name: try SandboxName("mybox"))

        XCTAssertEqual(spec.schemaVersion, 1)
        XCTAssertEqual(spec.image, .developerReadyDefault)
        XCTAssertEqual(spec.resourceProfile, ResourceProfile(cpus: 4, memory: MemorySize(gigabytes: 8)))
        XCTAssertEqual(spec.sharedFolders, [])
        XCTAssertFalse(spec.renderedYAML().contains("inbound"))
        XCTAssertFalse(spec.renderedYAML().contains("ports"))
    }

    func testGeneratedSpecRendersAndParsesBackToSameContract() throws {
        let spec = SandboxSpec(
            name: try SandboxName("mybox"),
            sharedFolders: [
                SharedFolder(
                    displayHostPath: "~/Projects/sand",
                    resolvedHostPath: "/Users/onur/Projects/sand",
                    guestPath: try GuestPath("/workspace/sand"),
                    accessMode: .readWrite
                )
            ]
        )

        XCTAssertEqual(try SandboxSpec.parseYAML(spec.renderedYAML()), spec)
    }

    func testCreateFromUserAuthoredSpecParsesExplicitImageResourcesAndFolders() throws {
        let yaml = """
        schemaVersion: 1
        name: custom
        image: registry.example/sand:dev
        resources:
          cpus: 6
          memory: 12GB
        sharedFolders:
          - hostPath: ~/Downloads
            resolvedHostPath: /Users/onur/Downloads
            guestPath: /workspace/downloads
            accessMode: read-only
        """

        let spec = try SandboxSpec.parseYAML(yaml)

        XCTAssertEqual(spec.name, try SandboxName("custom"))
        XCTAssertEqual(spec.image, SandboxImage(reference: "registry.example/sand:dev"))
        XCTAssertEqual(spec.resourceProfile, ResourceProfile(cpus: 6, memory: MemorySize(gigabytes: 12)))
        XCTAssertEqual(spec.sharedFolders.first?.accessMode, .readOnly)
    }

    func testUnsupportedV1FieldsSuchAsInboundNetworkingAreRejected() throws {
        let yaml = """
        schemaVersion: 1
        name: mybox
        image: sand/developer-ready:ubuntu-lts
        resources:
          cpus: 4
          memory: 8GB
        inboundNetworking:
          - 8080:8080
        sharedFolders:
          []
        """

        XCTAssertThrowsError(try SandboxSpec.parseYAML(yaml)) { error in
            XCTAssertEqual(error as? SandboxSpecError, .unsupportedField("inboundNetworking"))
        }
    }

    func testCpuAndMemoryEditsAfterCreationAreRejectedAtSpecContractLevel() throws {
        let original = SandboxSpec.generated(name: try SandboxName("mybox"))
        let cpuEdited = SandboxSpec(name: original.name, resourceProfile: ResourceProfile(cpus: 8, memory: .init(gigabytes: 8)))
        let memoryEdited = SandboxSpec(name: original.name, resourceProfile: ResourceProfile(cpus: 4, memory: .init(gigabytes: 16)))

        XCTAssertThrowsError(try cpuEdited.validateUpdate(from: original)) { error in
            XCTAssertEqual(error as? SandboxSpecError, .resourceProfileImmutable(field: "cpus"))
        }
        XCTAssertThrowsError(try memoryEdited.validateUpdate(from: original)) { error in
            XCTAssertEqual(error as? SandboxSpecError, .resourceProfileImmutable(field: "memory"))
        }
    }

    func testSandboxNameValidation() throws {
        XCTAssertEqual(try SandboxName("box-1_ok").rawValue, "box-1_ok")
        XCTAssertThrowsError(try SandboxName("")) { error in
            XCTAssertEqual(error as? SandboxNameError, .empty)
        }
        XCTAssertThrowsError(try SandboxName("box with spaces")) { error in
            XCTAssertEqual(error as? SandboxNameError, .invalidCharacters("box with spaces"))
        }
    }
}
