import XCTest

final class HomeViewDesignTests: XCTestCase {
    func testHomeViewUsesReferenceInspiredTranslationWorkbench() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/TranslatorApp/HomeView.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        XCTAssertTrue(source.contains("StarlineInspiredHome"))
        XCTAssertTrue(source.contains("translationWorkbench"))
        XCTAssertTrue(source.contains("stageBackdrop"))
        XCTAssertTrue(source.contains("TRANSLATE"))
        XCTAssertTrue(source.contains("themeAwareWorkbench"))
        XCTAssertTrue(source.contains("LanguagePane"))
        XCTAssertTrue(source.contains("workbenchFooter"))
        XCTAssertTrue(source.contains("Auto bilingual"))
        XCTAssertFalse(source.contains("To \\(settings.targetLanguage)"))
        XCTAssertTrue(source.contains("darkBrandPillFill"))
        XCTAssertTrue(source.contains("darkBrandPillStroke"))
        XCTAssertTrue(source.contains("Color.white.opacity(0.90)"))
        XCTAssertTrue(source.contains("Color.white.opacity(0.018)"))
        XCTAssertTrue(source.contains("decorativeFloatingMetricCard"))
        XCTAssertTrue(source.contains(".allowsHitTesting(false)"))
    }
}
