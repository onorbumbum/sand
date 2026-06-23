import XCTest

final class ArchitectureBoundaryTests: XCTestCase {
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
            if relativePath != "Sources/SandCore/Backend/AppleContainerCLIBackend.swift" {
                XCTAssertFalse(text.contains("container"), relativePath)
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
