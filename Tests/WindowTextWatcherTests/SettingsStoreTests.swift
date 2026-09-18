import XCTest
@testable import WindowTextWatcher

final class SettingsStoreTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "WindowTextWatcherTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testFirstLaunchUsesExistingDefaults() {
        let settings = SettingsStore(defaults: defaults).load()

        XCTAssertEqual(settings, WatcherSettings())
        XCTAssertFalse(settings.ignoreWhitespace)
        XCTAssertEqual(settings.cooldownSeconds, 3)
        XCTAssertEqual(settings.region, CGRect(x: 0, y: 0, width: 1, height: 1))
    }

    func testAllPreferencesSurviveStoreRecreation() {
        let settings = WatcherSettings(
            keywords: ["낚시금지", "작업 완료"],
            caseSensitive: true,
            ignoreWhitespace: true,
            cooldownSeconds: 17,
            region: CGRect(x: 0.1, y: 0.2, width: 0.6, height: 0.5)
        )
        SettingsStore(defaults: defaults).save(settings)
        let reopenedDefaults = UserDefaults(suiteName: suiteName)!

        XCTAssertEqual(SettingsStore(defaults: reopenedDefaults).load(), settings)
    }

    func testLatestChangesAndRemovalOfAllKeywordsAreSaved() {
        let store = SettingsStore(defaults: defaults)
        store.save(WatcherSettings(keywords: ["첫 번째", "마지막"], ignoreWhitespace: true))
        store.save(WatcherSettings(keywords: ["마지막"], cooldownSeconds: 0))

        XCTAssertEqual(store.load().keywords, ["마지막"])
        XCTAssertFalse(store.load().ignoreWhitespace)
        XCTAssertEqual(store.load().cooldownSeconds, 0)

        store.save(WatcherSettings())

        XCTAssertTrue(SettingsStore(defaults: defaults).load().keywords.isEmpty)
    }

    func testInvalidSavedDataFallsBackToDefaults() {
        defaults.set(Data("invalid".utf8), forKey: SettingsStore.storageKey)

        XCTAssertEqual(SettingsStore(defaults: defaults).load(), WatcherSettings())
    }

    func testMissingNewFieldsUseDefaults() {
        defaults.set(Data("{\"keywords\":[\"낚시금지\"],\"caseSensitive\":true}".utf8), forKey: SettingsStore.storageKey)

        let settings = SettingsStore(defaults: defaults).load()

        XCTAssertEqual(settings.keywords, ["낚시금지"])
        XCTAssertTrue(settings.caseSensitive)
        XCTAssertFalse(settings.ignoreWhitespace)
        XCTAssertEqual(settings.cooldownSeconds, 3)
    }
}
