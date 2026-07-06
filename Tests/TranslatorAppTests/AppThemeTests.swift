import XCTest

final class AppThemeTests: XCTestCase {
    func testMainViewSupportsUserSelectableLightAndDarkThemes() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let mainView = try String(contentsOf: root.appendingPathComponent("Sources/TranslatorApp/MainView.swift"), encoding: .utf8)
        let settingsStore = try String(contentsOf: root.appendingPathComponent("Sources/TranslatorApp/SettingsStore.swift"), encoding: .utf8)

        XCTAssertTrue(settingsStore.contains("enum AppThemeMode"))
        XCTAssertTrue(settingsStore.contains("@Published var themeMode"))
        XCTAssertTrue(settingsStore.contains("static let themeMode"))
        XCTAssertTrue(mainView.contains("themeToggle"))
        XCTAssertTrue(mainView.contains("preferredColorScheme(settings.themeMode.colorScheme)"))
        XCTAssertTrue(mainView.contains("AppStageBackground()"))
        XCTAssertTrue(mainView.contains(".allowsHitTesting(false)"))
        XCTAssertTrue(mainView.contains(".padding(.top, 36)"))
        XCTAssertTrue(mainView.contains(".zIndex(1)"))
        XCTAssertTrue(mainView.contains("navButtonHitArea"))
        XCTAssertTrue(mainView.contains("private func navButton"))
        XCTAssertTrue(mainView.contains(".contentShape(Capsule(style: .continuous))"))
        XCTAssertTrue(mainView.contains(".zIndex(10)"))
        XCTAssertFalse(mainView.contains(".preferredColorScheme(.light)"))
    }
}
