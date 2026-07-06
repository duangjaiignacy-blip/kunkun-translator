import XCTest

final class AppDelegateSelectionTests: XCTestCase {
    func testSelectionMissDoesNotShowWarningToast() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/TranslatorApp/AppDelegate.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        XCTAssertFalse(source.contains("未读到选中的英文"))
        XCTAssertTrue(source.contains("selection empty; keep quiet in bubble mode"))
    }
}
