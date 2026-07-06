import XCTest

final class IconPaletteTests: XCTestCase {
    func testAppIconUsesDarkChatBubblePalette() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("scripts/gen-icon.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        XCTAssertTrue(source.contains("黑色圆角底 + 白色外框 + 蓝色聊天气泡"))
        XCTAssertTrue(source.contains("drawSpeechBubble"))
        XCTAssertTrue(source.contains("CGColor(srgbRed: 0.04, green: 0.05, blue: 0.08, alpha: 1.0)"))
        XCTAssertTrue(source.contains("CGColor(srgbRed: 0.22, green: 0.35, blue: 0.95, alpha: 1.0)"))
        XCTAssertTrue(source.contains("CGColor(srgbRed: 0.24, green: 0.62, blue: 0.95, alpha: 1.0)"))
        XCTAssertTrue(source.contains("let leftText = \"A\" as CFString"))
        XCTAssertTrue(source.contains("let rightText = \"译\" as CFString"))
    }
}
