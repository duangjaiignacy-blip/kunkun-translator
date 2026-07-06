import XCTest

final class SelectionReaderTests: XCTestCase {
    func testSelectionReaderAcceptsAnyNonEmptyTextInsteadOfEnglishOnly() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/TranslatorApp/SelectionReader.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        XCTAssertFalse(source.contains("containsEnglishLetters"))
        XCTAssertTrue(source.contains("guard !trimmed.isEmpty else"))
        XCTAssertTrue(source.contains("AX 拿到空文字"))
        XCTAssertTrue(source.contains("Cmd+C: 内容为空"))
    }
}
