import XCTest
@testable import SandCore

final class WorkingDirectoryMapperTests: XCTestCase {
    func testMapsCwdInsideAllowedFolderToGuestPath() throws {
        let mapper = WorkingDirectoryMapper(resolvePath: { $0 })
        let spec = try sandboxSpecWithFolder(host: "/Users/onur/Projects/sand", guest: "/workspace/sand")

        let mapping = mapper.map(hostCurrentDirectory: "/Users/onur/Projects/sand", spec: spec)

        XCTAssertEqual(mapping, WorkingDirectoryMapping(guestPath: try GuestPath("/workspace/sand"), warning: nil))
    }

    func testMapsNestedCwdInsideAllowedFolderToNestedGuestPath() throws {
        let mapper = WorkingDirectoryMapper(resolvePath: { $0 })
        let spec = try sandboxSpecWithFolder(host: "/Users/onur/Projects/sand", guest: "/workspace/sand")

        let mapping = mapper.map(hostCurrentDirectory: "/Users/onur/Projects/sand/Sources/SandCore", spec: spec)

        XCTAssertEqual(mapping, WorkingDirectoryMapping(guestPath: try GuestPath("/workspace/sand/Sources/SandCore"), warning: nil))
    }

    func testMapsSymlinkedCwdUsingResolvedPath() throws {
        let mapper = WorkingDirectoryMapper(resolvePath: { path in path == "/link/sand/Sources" ? "/Users/onur/Projects/sand/Sources" : path })
        let spec = try sandboxSpecWithFolder(host: "/Users/onur/Projects/sand", guest: "/workspace/sand")

        let mapping = mapper.map(hostCurrentDirectory: "/link/sand/Sources", spec: spec)

        XCTAssertEqual(mapping.guestPath, try GuestPath("/workspace/sand/Sources"))
        XCTAssertNil(mapping.warning)
    }

    func testCwdOutsideAllowedFoldersUsesFallbackWithWarning() throws {
        let mapper = WorkingDirectoryMapper(resolvePath: { $0 })
        let spec = try sandboxSpecWithFolder(host: "/Users/onur/Projects/sand", guest: "/workspace/sand")

        let mapping = mapper.map(hostCurrentDirectory: "/Users/onur/Downloads", spec: spec)

        XCTAssertEqual(mapping.guestPath, try GuestPath("/workspace"))
        XCTAssertEqual(mapping.warning, "Current directory is not inside an Allowed Folder; starting in /workspace.")
    }

    private func sandboxSpecWithFolder(host: String, guest: String) throws -> SandboxSpec {
        SandboxSpec(
            name: try SandboxName("mybox"),
            allowedFolders: [AllowedFolder(displayHostPath: host, resolvedHostPath: host, guestPath: try GuestPath(guest), accessMode: .readWrite)]
        )
    }
}
