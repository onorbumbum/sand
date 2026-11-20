import XCTest

final class ArchitectureBoundaryTests: XCTestCase {
    private let linuxContainerAdapters: Set<String> = [
        "Sources/SandCore/Backend/AppleContainerCLIBackend.swift",
        "Sources/SandCore/Backend/DockerCLIBackend.swift",
        "Sources/SandCore/Backend/LinuxGuestRuntime.swift"
    ]

    func testProductSourcesDoNotExposeFakeBackendsOrRawBackendCLIsOutsideAdapters() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sources = root.appendingPathComponent("Sources/SandCore")
        let swiftFiles = try allSwiftFiles(under: sources)

        for file in swiftFiles {
            let relativePath = file.path.replacingOccurrences(of: root.path + "/", with: "")
            let text = try String(contentsOf: file, encoding: .utf8)
            XCTAssertFalse(text.contains("FakeSandboxBackend"), relativePath)
            XCTAssertFalse(text.contains("RecordingSandboxBackend"), relativePath)
            if !linuxContainerAdapters.contains(relativePath) {
                XCTAssertFalse(text.contains("container"), relativePath)
            }
            if relativePath != "Sources/SandCore/Backend/DockerCLIBackend.swift" {
                XCTAssertFalse(text.contains("\"docker\""), relativePath)
            }
            if relativePath != "Sources/SandCore/Backend/TartCLIBackend.swift" {
                XCTAssertFalse(text.contains("\"tart\""), relativePath)
            }
        }
    }

    private func allSwiftFiles(under url: URL) throws -> [URL] {
        let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: nil)!
        return enumerator.compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
    }
}
