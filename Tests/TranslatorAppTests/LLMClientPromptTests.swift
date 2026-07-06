import XCTest

final class LLMClientPromptTests: XCTestCase {
    func testTranslationPromptSupportsChineseAndEnglish() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/TranslatorApp/LLMClient.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        XCTAssertTrue(source.contains("translationTargetInstruction"))
        XCTAssertTrue(source.contains("如果输入主要是中文"))
        XCTAssertTrue(source.contains("翻译成英文"))
        XCTAssertTrue(source.contains("如果输入主要不是中文"))
        XCTAssertTrue(source.contains("翻译成中文"))
        XCTAssertFalse(source.contains("翻译成\\(preferredTarget)"))
        XCTAssertTrue(source.contains("containsCJK"))
        XCTAssertTrue(source.contains("中文词语/短语及其英文译文"))
        XCTAssertTrue(source.contains("text.count <= 8"))
        XCTAssertFalse(source.contains("用户给你一个英文单词/短语及其中文译文。请补充信息"))
    }
}
