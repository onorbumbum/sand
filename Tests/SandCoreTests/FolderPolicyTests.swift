import XCTest
@testable import SandCore

final class FolderPolicyTests: XCTestCase {
    func testAccessModeAliasesNormalizeToCanonicalStorage() throws {
        let policy = FolderPolicy(resolvePath: { $0 })

        XCTAssertEqual(try policy.canonicalAccessMode(from: "rw"), .readWrite)
        XCTAssertEqual(try policy.canonicalAccessMode(from: "ro"), .readOnly)
        XCTAssertEqual(try policy.canonicalAccessMode(from: "read-write"), .readWrite)
        XCTAssertEqual(try policy.canonicalAccessMode(from: "read-only"), .readOnly)
    }

    func testDefaultGuestPathDerivesFromHostFolderNameUnderWorkspace() throws {
        let policy = FolderPolicy(resolvePath: { $0 })

        XCTAssertEqual(try policy.defaultGuestPath(forDisplayHostPath: "~/Projects/sand"), try GuestPath("/workspace/sand"))
    }

    func testAddFolderStoresCanonicalModeResolvedPathGuestPathAndPreservesDisplayPath() throws {
        let policy = FolderPolicy(resolvePath: { path in path == "~/Projects/sand" ? "/Users/onur/Projects/sand" : path })
        let spec = SandboxSpec.generated(name: try SandboxName("mybox"))

        let updated = try policy.addFolder(to: spec, displayHostPath: "~/Projects/sand", accessMode: "rw")

        XCTAssertEqual(updated.allowedFolders, [
            AllowedFolder(displayHostPath: "~/Projects/sand", resolvedHostPath: "/Users/onur/Projects/sand", guestPath: try GuestPath("/workspace/sand"), accessMode: .readWrite)
        ])
    }

    func testExplicitAsGuestPathOverrideIsStored() throws {
        let policy = FolderPolicy(resolvePath: { $0 })
        let spec = SandboxSpec.generated(name: try SandboxName("mybox"))

        let updated = try policy.addFolder(to: spec, displayHostPath: "/Users/onur/Projects/sand", accessMode: "ro", guestPath: try GuestPath("/code"))

        XCTAssertEqual(updated.allowedFolders.first?.guestPath, try GuestPath("/code"))
        XCTAssertEqual(updated.allowedFolders.first?.accessMode, .readOnly)
    }

    func testAddingDuplicateHostFolderUpdatesExistingFolder() throws {
        let policy = FolderPolicy(resolvePath: { $0 })
        let original = try policy.addFolder(to: SandboxSpec.generated(name: try SandboxName("mybox")), displayHostPath: "/Users/onur/Projects/sand", accessMode: "ro")

        let updated = try policy.addFolder(to: original, displayHostPath: "/Users/onur/Projects/sand", accessMode: "rw", guestPath: try GuestPath("/code"))

        XCTAssertEqual(updated.allowedFolders.count, 1)
        XCTAssertEqual(updated.allowedFolders.first?.accessMode, .readWrite)
        XCTAssertEqual(updated.allowedFolders.first?.guestPath, try GuestPath("/code"))
    }

    func testDuplicateGuestPathIsRejected() throws {
        let policy = FolderPolicy(resolvePath: { $0 })
        let original = try policy.addFolder(to: SandboxSpec.generated(name: try SandboxName("mybox")), displayHostPath: "/Users/onur/A", accessMode: "rw", guestPath: try GuestPath("/workspace/project"))

        XCTAssertThrowsError(try policy.addFolder(to: original, displayHostPath: "/Users/onur/B", accessMode: "rw", guestPath: try GuestPath("/workspace/project"))) { error in
            XCTAssertEqual(error as? FolderPolicyError, .duplicateGuestPath("/workspace/project"))
        }
    }

    func testOverlappingHostFoldersAreRejected() throws {
        let policy = FolderPolicy(resolvePath: { $0 })
        let original = try policy.addFolder(to: SandboxSpec.generated(name: try SandboxName("mybox")), displayHostPath: "/Users/onur/Projects", accessMode: "rw")

        XCTAssertThrowsError(try policy.addFolder(to: original, displayHostPath: "/Users/onur/Projects/sand", accessMode: "rw")) { error in
            XCTAssertEqual(error as? FolderPolicyError, .overlappingHostFolders("/Users/onur/Projects", "/Users/onur/Projects/sand"))
        }
    }

    func testSymlinkRealpathIsUsedForDuplicateAndOverlapChecks() throws {
        let policy = FolderPolicy(resolvePath: { path in
            switch path {
            case "/link/project": return "/real/project"
            case "/another-link/project/src": return "/real/project/src"
            default: return path
            }
        })
        let original = try policy.addFolder(to: SandboxSpec.generated(name: try SandboxName("mybox")), displayHostPath: "/link/project", accessMode: "rw")

        XCTAssertThrowsError(try policy.addFolder(to: original, displayHostPath: "/another-link/project/src", accessMode: "ro")) { error in
            XCTAssertEqual(error as? FolderPolicyError, .overlappingHostFolders("/real/project", "/real/project/src"))
        }
    }
}
