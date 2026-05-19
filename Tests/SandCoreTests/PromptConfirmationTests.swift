import XCTest
@testable import SandCore

final class PromptConfirmationTests: XCTestCase {
    func testDestructivePromptRequiresExplicitYes() throws {
        var prompts: [String] = []
        var responses = ["y", "yes"]
        let prompt = StandardInputPromptConfirmation(
            readResponse: { responses.removeFirst() },
            writePrompt: { prompts.append($0) }
        )
        let request = ConfirmationRequest(message: "Delete Sandbox VM mybox?", destructive: true)

        XCTAssertEqual(try prompt.confirm(request), .cancel)
        XCTAssertEqual(try prompt.confirm(request), .proceed)
        XCTAssertEqual(prompts, [
            "Delete Sandbox VM mybox? Type 'yes' to continue: ",
            "Delete Sandbox VM mybox? Type 'yes' to continue: "
        ])
    }
}
