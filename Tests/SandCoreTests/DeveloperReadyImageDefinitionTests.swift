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
        XCTAssertFalse(smokeScript.contains("Fake"))
    }
}
