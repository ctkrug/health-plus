import XCTest
@testable import HealthAggregator

/// Validates the shipped app bundle's configuration. Because these tests are hosted in the app
/// (TEST_HOST), `Bundle.main` is the HealthAggregator app — so we catch broken Info.plist keys,
/// missing URL schemes, and failed build-time secret substitution before they reach TestFlight.
final class AppConfigTests: XCTestCase {

    private func info(_ key: String) -> Any? {
        Bundle.main.object(forInfoDictionaryKey: key)
    }

    func testDisplayNameIsHealthSync() {
        XCTAssertEqual(info("CFBundleDisplayName") as? String, "HealthSync")
    }

    func testBundleIdentifier() {
        XCTAssertEqual(Bundle.main.bundleIdentifier, "com.ctkrug.healthplus")
    }

    func testWhoopConfigPresent() {
        XCTAssertFalse((info("WhoopClientID") as? String ?? "").isEmpty, "WHOOP client ID missing")
        XCTAssertEqual(info("WhoopRedirectURI") as? String, "healthaggregator://whoop/callback")
        // Client secret is expected for the personal-app OAuth flow.
        XCTAssertFalse((info("WhoopClientSecret") as? String ?? "").isEmpty)
    }

    func testAnthropicKeyWasSubstituted() {
        // The Info.plist holds $(ANTHROPIC_API_KEY); after a build it must NOT still contain the
        // literal token (that would mean xcconfig substitution silently failed).
        let key = info("AnthropicAPIKey") as? String
        XCTAssertNotNil(key, "AnthropicAPIKey entry missing from Info.plist")
        XCTAssertNotEqual(key, "$(ANTHROPIC_API_KEY)", "Build-time substitution did not run")
    }

    func testBackgroundTaskIdentifiersRegistered() {
        let ids = info("BGTaskSchedulerPermittedIdentifiers") as? [String] ?? []
        XCTAssertTrue(ids.contains("com.ctkrug.healthplus.whoopRefresh"))
        XCTAssertTrue(ids.contains("com.ctkrug.healthplus.healthkitSync"))
    }

    func testCustomURLSchemeRegistered() {
        let urlTypes = info("CFBundleURLTypes") as? [[String: Any]] ?? []
        let schemes = urlTypes.flatMap { ($0["CFBundleURLSchemes"] as? [String]) ?? [] }
        XCTAssertTrue(schemes.contains("healthaggregator"), "OAuth callback scheme not registered")
    }

    func testEncryptionComplianceDeclared() {
        XCTAssertEqual(info("ITSAppUsesNonExemptEncryption") as? Bool, false)
    }

    func testHealthKitUsageStringsPresent() {
        XCTAssertFalse((info("NSHealthShareUsageDescription") as? String ?? "").isEmpty)
        XCTAssertFalse((info("NSHealthUpdateUsageDescription") as? String ?? "").isEmpty)
    }

    // MARK: - Service graph smoke test

    @MainActor
    func testAppStateInitializesAllServices() {
        // Constructing AppState wires up every service (HealthKit, WHOOP, Core Data, habits, etc.).
        // If any initializer crashes (e.g. a bad Core Data model), this fails loudly.
        let state = AppState()
        XCTAssertNotNil(state.healthKitService)
        XCTAssertNotNil(state.whoopService)
        XCTAssertNotNil(state.workoutStore)
        XCTAssertNotNil(state.habitStore)
        XCTAssertNotNil(state.notificationService)
        XCTAssertNotNil(state.authService)
    }

    func testClaudeServiceKeyPresenceMatchesBundle() {
        // hasKey should reflect whatever the build embedded; just assert it doesn't crash and is
        // consistent with the Info.plist value.
        let embedded = (info("AnthropicAPIKey") as? String ?? "")
        XCTAssertEqual(ClaudeService.shared.hasKey, !embedded.isEmpty)
    }
}
