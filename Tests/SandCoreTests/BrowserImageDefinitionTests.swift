import XCTest

final class BrowserImageDefinitionTests: XCTestCase {
    private let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    private func read(_ path: String) throws -> String {
        try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }

    func testBrowserImageKeepsDevToolsGuestOnlyAndProfileInGuestState() throws {
        let startup = try read("images/browser/sand-browser-up")

        XCTAssertTrue(startup.contains("--remote-debugging-address=127.0.0.1"), "CDP must bind guest loopback only")
        XCTAssertTrue(startup.contains("--remote-debugging-port=9222"))
        XCTAssertTrue(startup.contains("/state/sandbox/chromium"), "profile must live in Guest State so sign-ins persist")
        XCTAssertTrue(startup.contains("-localhost -rfbport 5900"), "raw VNC must stay guest-local; only noVNC is published")
        XCTAssertTrue(startup.contains("websockify --web /usr/share/novnc 6080"))
        XCTAssertTrue(startup.contains("trap shutdown TERM INT"), "stop must let Chromium flush its cookie store")
        XCTAssertTrue(startup.contains("--restore-last-session"), "an idle stop must not lose the page an agent left for Onur")
        XCTAssertTrue(startup.contains("sand-browser quit"), "SIGTERM skips Chromium's cookie write; stop closes it over CDP")
        XCTAssertTrue(startup.contains("rm -f \"/tmp/.X${DISPLAY_NUMBER}-lock\""), "stop/start keeps /tmp; a stale X lock stops Xvfb from coming back")
    }

    func testBrowserImageBuildsOnDeveloperReadyAndShipsAgentCLI() throws {
        let dockerfile = try read("images/browser/Dockerfile")
        let buildScript = try read("scripts/build-browser-image.sh")
        let smokeScript = try read("scripts/smoke-browser-image.sh")

        XCTAssertTrue(dockerfile.contains("ARG BASE_IMAGE=sand/developer-ready:ubuntu-lts"))
        XCTAssertTrue(dockerfile.contains("COPY sand-browser-up sand-browser /usr/local/bin/"))
        XCTAssertTrue(dockerfile.contains("USER sandbox"))
        XCTAssertTrue(buildScript.contains("sand/browser:ubuntu-lts"))
        XCTAssertTrue(smokeScript.contains("--publish \"127.0.0.1:${VIEW_PORT}:6080\""))
        XCTAssertTrue(smokeScript.contains("must stay guest-only"), "smoke must prove CDP is not reachable from the host")
        XCTAssertTrue(smokeScript.contains("live view after restart -> ok"), "smoke must prove the browser comes back after stop/start")
        XCTAssertTrue(smokeScript.contains("cookies survive stop/start -> ok"), "smoke must prove sign-ins persist")
        XCTAssertTrue(smokeScript.contains("tabs come back after restart -> ok"))
        XCTAssertTrue(smokeScript.contains("held browser refuses agent actions -> ok"), "smoke must prove Take control pauses the agent")
        let agentCLI = try read("images/browser/sand-browser")
        XCTAssertTrue(agentCLI.contains("/tmp/sand-browser-held"), "the flag Ops writes when Onur takes control")
        XCTAssertTrue(agentCLI.contains("/tmp/sand-browser-last.json"), "agent actions are recorded so Ops can show who is using a browser")
        XCTAssertTrue(smokeScript.contains("activity reports the last agent action -> ok"))
    }
}
