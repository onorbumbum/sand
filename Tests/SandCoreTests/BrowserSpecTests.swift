import XCTest
@testable import SandCore

final class BrowserSpecTests: XCTestCase {
    func testBrowserSandboxRendersAndParsesItsLoopbackViewPort() throws {
        let spec = SandboxSpec(
            name: try SandboxName("web"),
            image: .browserDefault,
            browser: BrowserSettings(viewPort: 6081)
        )

        let yaml = spec.renderedYAML()

        XCTAssertTrue(yaml.contains("browser:\n  viewPort: 6081\n"))
        XCTAssertEqual(try SandboxSpec.parseYAML(yaml), spec)
    }

    func testSpecsWithoutBrowserSectionStayByteStable() throws {
        let spec = SandboxSpec.generated(name: try SandboxName("mybox"))

        XCTAssertNil(spec.browser)
        XCTAssertFalse(spec.renderedYAML().contains("browser"))
    }

    func testBrowserIsLinuxOnly() throws {
        let spec = SandboxSpec(name: try SandboxName("macbox"), image: SandboxImage(reference: "ghcr.io/example/macos:latest"), guestOS: .macOS, browser: BrowserSettings(viewPort: 6080))

        XCTAssertThrowsError(try spec.validateV1()) { error in
            XCTAssertEqual(error as? SandboxSpecError, .browserUnsupportedForGuestOS(.macOS))
        }
    }

    func testBrowserViewPortMustBeUnprivileged() throws {
        let yaml = """
        schemaVersion: 1
        name: web
        image: sand/browser:ubuntu-lts
        browser:
          viewPort: 80
        resources:
          cpus: 2
          memory: 2GB
        sharedFolders:
          []
        """

        XCTAssertThrowsError(try SandboxSpec.parseYAML(yaml)) { error in
            XCTAssertEqual(error as? SandboxSpecError, .invalidBrowserViewPort(80))
        }
    }

    func testViewURLPointsAtNoVNCOnHostLoopback() {
        let settings = BrowserSettings(viewPort: 6082)

        XCTAssertEqual(settings.viewURL, "http://127.0.0.1:6082/vnc.html?autoconnect=1&resize=remote")
        XCTAssertEqual(BrowserSettings.guestViewPort, 6080)
    }

    func testFirstFreeViewPortSkipsPortsUsedByOtherBrowserSandboxes() {
        XCTAssertEqual(BrowserSettings.firstFreeViewPort(excluding: []), 6080)
        XCTAssertEqual(BrowserSettings.firstFreeViewPort(excluding: [6080, 6081, 6083]), 6082)
    }
}
