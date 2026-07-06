import XCTest

final class HomeViewDesignTests: XCTestCase {
    func testHomeViewUsesReferenceInspiredTranslationWorkbench() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/TranslatorApp/HomeView.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        XCTAssertTrue(source.contains("PinsgoInspiredHome"))
        XCTAssertTrue(source.contains("translationWorkbench"))
        XCTAssertTrue(source.contains("meshBackdrop"))
        XCTAssertTrue(source.contains("LanguagePane"))
        XCTAssertTrue(source.contains("workbenchFooter"))
        XCTAssertTrue(source.contains("Mac-style menu bar translation"))
    }
}
