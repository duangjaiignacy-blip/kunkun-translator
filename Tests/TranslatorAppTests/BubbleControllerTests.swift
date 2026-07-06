import XCTest

final class BubbleControllerTests: XCTestCase {
    func testResultPanelIsConfiguredForDraggingAndSubtleTransparency() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/TranslatorApp/BubbleController.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        XCTAssertTrue(source.contains("p.isMovableByWindowBackground = true"))
        XCTAssertTrue(source.contains("p.alphaValue = 0.96"))
    }
}
