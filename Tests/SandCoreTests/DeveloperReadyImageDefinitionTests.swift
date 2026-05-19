import XCTest
@testable import SandCore

final class DeveloperReadyImageDefinitionTests: XCTestCase {
    func testDeveloperReadyImageDefinitionDeclaresDefaultSandboxContract() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let dockerfileURL = root.appendingPathComponent("images/developer-ready/Dockerfile")
        let dockerfile = try String(contentsOf: dockerfileURL, encoding: .utf8)

        XCTAssertTrue(dockerfile.contains("FROM docker.io/library/ubuntu:24.04"))
        for package in [
            "build-essential",
            "ca-certificates",
            "curl",
            "git",
            "openssh-client",
            "python3",
            "python3-pip",
            "python3-venv",
            "ripgrep",
            "sudo",
            "tmux"
        ] {
            XCTAssertTrue(dockerfile.contains(package), "missing package: \(package)")
        }
        XCTAssertTrue(dockerfile.contains("node_22.x"), "Pi CLI requires Node >=20.6; image should install current Node, not Ubuntu's Node 18 package")
        XCTAssertTrue(dockerfile.contains("@mariozechner/pi-coding-agent@${PI_CLI_VERSION}"))
        XCTAssertTrue(dockerfile.contains("useradd --create-home --shell /bin/bash sandbox"))
        XCTAssertTrue(dockerfile.contains("sandbox ALL=(ALL) NOPASSWD:ALL"))
        XCTAssertTrue(dockerfile.contains("/state/sandbox/.pi"), "Pi identity must be stored in Guest State, not in a host-mounted ~/.pi")
        XCTAssertTrue(dockerfile.contains("/home/sandbox/.pi"), "Sandbox user's Pi config path should point at Guest State")
        XCTAssertTrue(dockerfile.contains("/state/sandbox/secrets"), "Guest Secrets should be sandbox-local state in v1")
        XCTAssertTrue(dockerfile.contains("/home/sandbox/.sand-secrets"), "Sandbox-local secrets should have a stable guest path")
        XCTAssertFalse(dockerfile.contains("/Users/"), "image definition must not bake host paths into the Sandbox Guest")
        XCTAssertTrue(dockerfile.contains("USER sandbox"))
        XCTAssertTrue(dockerfile.contains("WORKDIR /workspace"))
    }

    func testDeveloperReadyImageBuildAndSmokeCommandsAreScripted() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let buildScript = try String(contentsOf: root.appendingPathComponent("scripts/build-developer-ready-image.sh"), encoding: .utf8)
        let smokeScript = try String(contentsOf: root.appendingPathComponent("scripts/smoke-developer-ready-image.sh"), encoding: .utf8)

        XCTAssertTrue(buildScript.contains("container build"))
        XCTAssertTrue(buildScript.contains("sand/developer-ready:ubuntu-lts"))
        XCTAssertTrue(smokeScript.contains("container run"))
        XCTAssertTrue(smokeScript.contains("--user sandbox"))
        for command in ["git", "curl", "sudo", "ssh", "python3", "python3 -m venv", "pip3", "node", "npm", "tmux", "rg", "gcc", "make", "pi"] {
            XCTAssertTrue(smokeScript.contains(command), "smoke script must check \(command)")
        }
        XCTAssertTrue(smokeScript.contains("readlink \"$HOME/.pi\""), "smoke script must prove Pi identity points to Guest State")
        XCTAssertTrue(smokeScript.contains("readlink \"$HOME/.sand-secrets\""), "smoke script must prove Guest Secrets point to sandbox-local state")
        XCTAssertTrue(smokeScript.contains("test ! -e /Users"), "smoke script must prove host home paths are not present by default")
        XCTAssertTrue(smokeScript.contains("test -z \"${SSH_AUTH_SOCK:-}\""), "smoke script must prove host SSH agent is not forwarded by default")
        XCTAssertFalse(smokeScript.contains("Fake"))
    }
}
