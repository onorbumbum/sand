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
        XCTAssertTrue(startup.contains("-localhost=1 -rfbport 5900"), "raw VNC must stay guest-local; only noVNC is published")
        XCTAssertTrue(startup.contains("-AcceptSetDesktopSize=1"), "the Live View sizes the screen to the viewer's window")
        XCTAssertTrue(startup.contains("openbox --config-file /etc/sand-browser/openbox.xml"), "Chromium must stay maximized as the screen resizes")
        let openbox = try read("images/browser/openbox.xml")
        XCTAssertTrue(openbox.contains("<maximized>yes</maximized>"))
        XCTAssertTrue(openbox.contains("<decor>no</decor>"))
        XCTAssertTrue(startup.contains("websockify --web /usr/share/novnc 6080"))
        XCTAssertTrue(startup.contains("trap shutdown TERM INT"), "stop must let Chromium flush its cookie store")
        XCTAssertTrue(startup.contains("--restore-last-session"), "an idle stop must not lose the page an agent left for Onur")
        XCTAssertTrue(startup.contains("--hide-crash-restore-bubble"), "tabs restore on their own; the bubble only covers the page")
        XCTAssertTrue(startup.contains("sand-browser quit"), "SIGTERM skips Chromium's cookie write; stop closes it over CDP")
        XCTAssertTrue(startup.contains("rm -f \"/tmp/.X${DISPLAY_NUMBER}-lock\""), "stop/start keeps /tmp; a stale X lock stops Xvfb from coming back")
    }

    func testBrowserImageBuildsOnDeveloperReadyAndShipsAgentCLI() throws {
        let dockerfile = try read("images/browser/Dockerfile")
        let buildScript = try read("scripts/build-browser-image.sh")
        let smokeScript = try read("scripts/smoke-browser-image.sh")

        XCTAssertTrue(dockerfile.contains("ARG BASE_IMAGE=sand/developer-ready:ubuntu-lts"))
        XCTAssertTrue(dockerfile.contains("COPY sand-browser-up sand-browser sand-browser-fill-login xdg-open /usr/local/bin/"))
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
        XCTAssertTrue(try read("images/browser/Dockerfile").contains("ln -s /state/sandbox/Downloads /home/sandbox/Downloads"), "downloads live in Guest State, so they survive a recreate")
        XCTAssertTrue(agentCLI.contains("download.saveAs"), "agent downloads are kept, not left in Playwright's temporary folder")
        for command in ["'downloads'", "'download-get'", "'download-delete'"] {
            XCTAssertTrue(agentCLI.contains(command), "sand-browser owns the downloads folder: \(command)")
        }
        XCTAssertTrue(smokeScript.contains("agent downloads are kept -> ok"))
        let opener = try read("images/browser/xdg-open")
        XCTAssertTrue(opener.contains("chromium --user-data-dir="), "opening a file in the sandbox shows it in the same Chromium")
        XCTAssertTrue(try read("images/browser/Dockerfile").contains("COPY sand-browser-up sand-browser sand-browser-fill-login xdg-open /usr/local/bin/"))
        XCTAssertTrue(agentCLI.contains("'download-open'"))
        for command in ["'uploads'", "'upload-put'", "'upload'"] {
            XCTAssertTrue(agentCLI.contains(command), "sand-browser owns the uploads folder: \(command)")
        }
        XCTAssertTrue(agentCLI.contains("filechooser"), "buttons that open a file picker (Facebook-style) must work")
        XCTAssertTrue(agentCLI.contains("connectOverCDP(endpoint, { timeout: 10000, isLocal })"), "uploads pass staged paths to the guest-loopback Chromium; Playwright refuses to transfer files of 50 MiB or more otherwise")
        XCTAssertTrue(try read("scripts/test-browser-upload.cjs").contains("80 * 1024 * 1024"), "an 80 MiB upload regression test exists")
        XCTAssertTrue(try read("images/browser/Dockerfile").contains("ln -s /state/sandbox/Uploads /home/sandbox/Uploads"))
        XCTAssertTrue(smokeScript.contains("uploads reach the page -> ok"))
        XCTAssertTrue(try read("images/browser/Dockerfile").contains("libgtk-3-0t64"), "Chromium on Linux draws its file picker with GTK; without it, clicking Choose File does nothing")
        XCTAssertTrue(smokeScript.contains("file picker available -> ok"))
        let dockerfileText = try read("images/browser/Dockerfile")
        XCTAssertTrue(dockerfileText.contains("google-chrome-stable"), "Chrome for Testing loses files activated in its GTK picker (double-click, Enter); Google Chrome does not")
        XCTAssertTrue(dockerfileText.contains("dpkg --print-architecture"), "Google Chrome ships amd64 only; arm64 keeps Playwright's Chromium")
        XCTAssertTrue(smokeScript.contains("browser build -> ok"))
        XCTAssertTrue(smokeScript.contains("downloads open in the sandbox Chromium -> ok"))
        XCTAssertTrue(smokeScript.contains("downloads survive a restart -> ok"))
    }

    // Aslan Browser parity (issues 033-035): the commands Aslan playbooks use.
    func testAgentCLIReadsPagesAsAnAccessibilityTreeWithRefs() throws {
        let agentCLI = try read("images/browser/sand-browser")
        let smokeScript = try read("scripts/smoke-browser-image.sh")

        XCTAssertTrue(agentCLI.contains("ariaSnapshot({ mode: 'ai' })"), "only AI mode prints [ref=eN]")
        XCTAssertTrue(agentCLI.contains("data-sand-ref"), "refs must outlive the CLI's CDP connection, so tree tags the elements")
        XCTAssertTrue(agentCLI.contains("run sand-browser tree again"), "a stale ref tells the agent what to do")
        XCTAssertTrue(agentCLI.contains("const LOOKING = new Set(['status', 'tabs', 'tree',"), "tree is looking, allowed while Onur has control")
        XCTAssertTrue(smokeScript.contains("tree, click and fill by ref -> ok"))
        XCTAssertTrue(smokeScript.contains("stale ref refused -> ok"))
        XCTAssertTrue(smokeScript.contains("refs on a big page -> ok"), "resolving refs one by one took seconds on Google Maps")
        XCTAssertTrue(agentCLI.contains("__playwright_utility_world_"), "refs are tagged in one pass inside Playwright's isolated world")
    }

    func testAgentCLIHasAslanInteractionParity() throws {
        let agentCLI = try read("images/browser/sand-browser")
        let smokeScript = try read("scripts/smoke-browser-image.sh")

        for command in ["'type'", "'select'", "'key'", "'scroll'", "'wait'", "'back'", "'forward'", "'reload'"] {
            XCTAssertTrue(agentCLI.contains("case \(command)"), "sand-browser \(command)")
        }
        XCTAssertTrue(agentCLI.contains("keyboard.insertText"), "type works on contenteditable editors (LinkedIn, Facebook)")
        XCTAssertTrue(agentCLI.contains("selectOption"))
        XCTAssertTrue(smokeScript.contains("type into contenteditable -> ok"))
        XCTAssertTrue(smokeScript.contains("select, key chords, scroll, wait, history -> ok"))
        for command in ["'title'", "'url'"] {
            XCTAssertTrue(agentCLI.contains("case \(command)"), "sand-browser \(command)")
        }
        XCTAssertTrue(agentCLI.contains("Illegal return"), "Aslan playbooks' eval snippets are function bodies with return")
        XCTAssertTrue(agentCLI.contains("flags.raw"), "eval --raw prints strings as Aslan did, for scripts that read the output")
        XCTAssertTrue(smokeScript.contains("eval bodies, title, url, wait for an element -> ok"))
    }

    func testAgentCLIHasNamedTabsInGuestState() throws {
        let agentCLI = try read("images/browser/sand-browser")
        let smokeScript = try read("scripts/smoke-browser-image.sh")

        for command in ["'tab-new'", "'tab-use'", "'tab-close'"] {
            XCTAssertTrue(agentCLI.contains("case \(command)"), "sand-browser \(command)")
        }
        XCTAssertTrue(agentCLI.contains("/state/sandbox/sand-browser-tabs.json"), "tab names live in Guest State")
        XCTAssertTrue(agentCLI.contains("Target.getTargetInfo"), "names are keyed by CDP target id")
        XCTAssertTrue(smokeScript.contains("named tabs -> ok"))
    }

    // Fill login (issue 038): Ops types a Bitwarden login into the page Onur is on.
    func testFillLoginTypesOnTheDisplayOnlyWhileOnurHasControl() throws {
        let fill = try read("images/browser/sand-browser-fill-login")
        let dockerfile = try read("images/browser/Dockerfile")
        let smokeScript = try read("scripts/smoke-browser-image.sh")

        XCTAssertTrue(dockerfile.contains("xdotool"))
        XCTAssertTrue(fill.contains("/tmp/sand-browser-held"), "only while Onur has control")
        XCTAssertTrue(try read("images/browser/sand-browser-up").contains("rm -f /tmp/sand-browser-held"), "a fresh start has no viewer, so nobody holds control")
        XCTAssertTrue(fill.contains("--file -"), "secrets go to xdotool on stdin, never as arguments")
        XCTAssertFalse(fill.contains("Return"), "Fill login never submits")
        XCTAssertTrue(smokeScript.contains("fill login types into the focused field -> ok"))
        XCTAssertTrue(smokeScript.contains("fill login one step at a time (two-step sign-ins) -> ok"))
        XCTAssertTrue(try read("images/browser/sand-browser").contains("case 'focus'"), "Ops asks what field is focused on the tab on screen")
    }
}
