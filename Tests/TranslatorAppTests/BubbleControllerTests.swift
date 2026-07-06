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

    func testSelectionBubbleIsPinkDotWithTranslationText() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/TranslatorApp/BubbleController.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        XCTAssertTrue(source.contains("Color(red: 0.88, green: 0.22, blue: 0.45)"))
        XCTAssertTrue(source.contains(".frame(width: 14, height: 14)"))
        XCTAssertTrue(source.contains("Text(\"译\")"))
        XCTAssertTrue(source.contains(".font(.system(size: 8, weight: .bold))"))
    }
}
