import XCTest
@testable import SandCore

final class SandboxSpecTests: XCTestCase {
    func testGeneratedSpecUsesV1DefaultsAndNoUnsupportedFutureFields() throws {
        let spec = SandboxSpec.generated(name: try SandboxName("mybox"))

        XCTAssertEqual(spec.schemaVersion, 1)
        XCTAssertEqual(spec.image, .developerReadyDefault)
        XCTAssertEqual(spec.guestOS, .linux)
        XCTAssertEqual(spec.resourceProfile, ResourceProfile(cpus: 4, memory: MemorySize(gigabytes: 8)))
        XCTAssertEqual(spec.sharedFolders, [])
        XCTAssertFalse(spec.renderedYAML().contains("inbound"))
        XCTAssertFalse(spec.renderedYAML().contains("ports"))
    }

    func testMacOSSpecsDefaultToFourCPUsAndSixteenGBAndSixtyFourGBDisk() throws {
        let spec = SandboxSpec(name: try SandboxName("macbox"), guestOS: .macOS)

        XCTAssertEqual(spec.resourceProfile, ResourceProfile(cpus: 4, memory: MemorySize(gigabytes: 16)))
        XCTAssertEqual(spec.diskSize, DiskSize(gigabytes: 64))
    }

    func testReadySpecsOmitBootstrapLineForByteStableYAML() throws {
        let spec = SandboxSpec(name: try SandboxName("macbox"), image: SandboxImage(reference: "ghcr.io/example/macos:latest"), guestOS: .macOS)

        XCTAssertEqual(spec.bootstrapState, .ready)
        XCTAssertFalse(spec.renderedYAML().contains("bootstrap"))
    }

    func testSetupRequiredMacOSSpecRendersAndParsesBootstrapState() throws {
        let spec = SandboxSpec(name: try SandboxName("macbox"), image: SandboxImage(reference: "ipsw:latest"), guestOS: .macOS, bootstrapState: .setupRequired)

        XCTAssertTrue(spec.renderedYAML().contains("bootstrap: setup-required"))
        XCTAssertEqual(try SandboxSpec.parseYAML(spec.renderedYAML()), spec)
        XCTAssertEqual(try SandboxSpec.parseYAML(spec.renderedYAML()).bootstrapState, .setupRequired)
    }

    func testMacOSSpecParsesAndRendersDiskSize() throws {
        let yaml = """
        schemaVersion: 1
        name: macbox
        image: ghcr.io/example/macos:latest
        os: macos
        disk: 150GB
        resources:
          cpus: 4
          memory: 16GB
        sharedFolders:
          []
        """

        let spec = try SandboxSpec.parseYAML(yaml)

        XCTAssertEqual(spec.diskSize, DiskSize(gigabytes: 150))
        XCTAssertTrue(spec.renderedYAML().contains("disk: 150GB"))
    }

    func testMacOSSpecParsesAndRendersDisplayResolution() throws {
        let yaml = """
        schemaVersion: 1
        name: macbox
        image: ghcr.io/example/macos:latest
        os: macos
        display: 1920x1080px
        resources:
          cpus: 4
          memory: 16GB
        sharedFolders:
          []
        """

        let spec = try SandboxSpec.parseYAML(yaml)

        XCTAssertEqual(spec.displayResolution, DisplayResolution(width: 1920, height: 1080, unit: .pixels))
        XCTAssertTrue(spec.renderedYAML().contains("display: 1920x1080px"))
    }

    func testUnqualifiedDisplayResolutionDefaultsToPixels() throws {
        XCTAssertEqual(try DisplayResolution.parse("1920x1080"), DisplayResolution(width: 1920, height: 1080, unit: .pixels))
    }

    func testLinuxSpecRejectsMacOSOnlyDiskSize() throws {
        let yaml = """
        schemaVersion: 1
        name: linuxbox
        image: sand/developer-ready:ubuntu-lts
        os: linux
        disk: 150GB
        resources:
          cpus: 4
          memory: 8GB
        sharedFolders:
          []
        """

        XCTAssertThrowsError(try SandboxSpec.parseYAML(yaml)) { error in
            XCTAssertEqual(error as? SandboxSpecError, .diskUnsupportedForGuestOS(.linux))
        }
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
        os: macos
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
        XCTAssertEqual(spec.guestOS, .macOS)
        XCTAssertEqual(spec.resourceProfile, ResourceProfile(cpus: 6, memory: MemorySize(gigabytes: 12)))
        XCTAssertEqual(spec.sharedFolders.first?.accessMode, .readOnly)
    }

    func testSpecsWithoutOSParseAsLinuxForAdditiveCompatibility() throws {
        let yaml = """
        schemaVersion: 1
        name: legacy
        image: sand/developer-ready:ubuntu-lts
        resources:
          cpus: 4
          memory: 8GB
        sharedFolders:
          []
        """

        XCTAssertEqual(try SandboxSpec.parseYAML(yaml).guestOS, .linux)
    }

    func testLegacyAllowedFoldersSpecsStillParseAsSharedFolders() throws {
        let yaml = """
        schemaVersion: 1
        name: legacy
        image: sand/developer-ready:ubuntu-lts
        resources:
          cpus: 2
          memory: 4GB
        allowedFolders:
          - hostPath: ~/Projects
            resolvedHostPath: /Users/onur/Projects
            guestPath: /workspace
            accessMode: read-write
        """

        let spec = try SandboxSpec.parseYAML(yaml)

        XCTAssertEqual(spec.guestOS, .linux)
        XCTAssertEqual(spec.sharedFolders, [
            SharedFolder(displayHostPath: "~/Projects", resolvedHostPath: "/Users/onur/Projects", guestPath: try GuestPath("/workspace"), accessMode: .readWrite)
        ])
    }

    func testLinuxSpecRejectsMacOSOnlyDisplayResolution() throws {
        let yaml = """
        schemaVersion: 1
        name: linuxbox
        image: sand/developer-ready:ubuntu-lts
        os: linux
        display: 1920x1080px
        resources:
          cpus: 4
          memory: 8GB
        sharedFolders:
          []
        """

        XCTAssertThrowsError(try SandboxSpec.parseYAML(yaml)) { error in
            XCTAssertEqual(error as? SandboxSpecError, .displayUnsupportedForGuestOS(.linux))
        }
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

    func testImmutableFieldsAfterCreationAreRejectedAtSpecContractLevel() throws {
        let original = SandboxSpec.generated(name: try SandboxName("mybox"))
        let imageEdited = SandboxSpec(name: original.name, image: SandboxImage(reference: "custom:latest"))
        let osEdited = SandboxSpec(name: original.name, guestOS: .macOS)
        let cpuEdited = SandboxSpec(name: original.name, resourceProfile: ResourceProfile(cpus: 8, memory: .init(gigabytes: 8)))
        let memoryEdited = SandboxSpec(name: original.name, resourceProfile: ResourceProfile(cpus: 4, memory: .init(gigabytes: 16)))
        let macOriginal = SandboxSpec(name: try SandboxName("macbox"), guestOS: .macOS, diskSize: DiskSize(gigabytes: 100))
        let diskEdited = SandboxSpec(name: macOriginal.name, guestOS: .macOS, diskSize: DiskSize(gigabytes: 150))
        let displayEdited = SandboxSpec(name: macOriginal.name, guestOS: .macOS, diskSize: DiskSize(gigabytes: 100), displayResolution: DisplayResolution(width: 1920, height: 1080, unit: .pixels))

        XCTAssertThrowsError(try imageEdited.validateUpdate(from: original)) { error in
            XCTAssertEqual(error as? SandboxSpecError, .imageImmutable)
        }
        XCTAssertThrowsError(try osEdited.validateUpdate(from: original)) { error in
            XCTAssertEqual(error as? SandboxSpecError, .guestOSImmutable)
        }
        XCTAssertThrowsError(try cpuEdited.validateUpdate(from: original)) { error in
            XCTAssertEqual(error as? SandboxSpecError, .resourceProfileImmutable(field: "cpus"))
        }
        XCTAssertThrowsError(try memoryEdited.validateUpdate(from: original)) { error in
            XCTAssertEqual(error as? SandboxSpecError, .resourceProfileImmutable(field: "memory"))
        }
        XCTAssertThrowsError(try diskEdited.validateUpdate(from: macOriginal)) { error in
            XCTAssertEqual(error as? SandboxSpecError, .diskSizeImmutable)
        }
        XCTAssertNoThrow(try displayEdited.validateUpdate(from: macOriginal))
    }

    func testLocalMacOSCloneRejectsSmallerDiskThanSource() throws {
        let source = SandboxSpec(name: try SandboxName("clean"), guestOS: .macOS, diskSize: DiskSize(gigabytes: 150))
        let clone = SandboxSpec(name: try SandboxName("work"), image: SandboxImage(reference: "clean"), guestOS: .macOS, diskSize: DiskSize(gigabytes: 100))

        XCTAssertThrowsError(try clone.validateLocalClone(from: source)) { error in
            XCTAssertEqual(error as? SandboxSpecError, .cloneDiskTooSmall(source: DiskSize(gigabytes: 150), requested: DiskSize(gigabytes: 100)))
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
