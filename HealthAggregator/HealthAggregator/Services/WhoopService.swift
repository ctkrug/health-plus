import Foundation
import AuthenticationServices
import SwiftUI

@Observable
final class WhoopService {
    var snapshot = WhoopSnapshot()
    var isConnected = false
    var isLoading = false
    var authError: String? = nil

    private var accessToken: String? { KeychainService.load(.whoopAccessToken) }
    private var refreshToken: String? { KeychainService.load(.whoopRefreshToken) }
    private var tokenExpiry: Date? {
        guard let s = KeychainService.load(.whoopTokenExpiry),
              let t = Double(s) else { return nil }
        return Date(timeIntervalSince1970: t)
    }

    private let baseURL = "https://api.prod.whoop.com/developer/v1"
    private let authBaseURL = "https://api.prod.whoop.com/oauth/oauth2"

    // Strong reference prevents ASWebAuthenticationSession from being deallocated mid-flow
    private var authSession: ASWebAuthenticationSession?

    private var clientID: String {
        Bundle.main.object(forInfoDictionaryKey: "WhoopClientID") as? String ?? ""
    }
    private var clientSecret: String {
        Bundle.main.object(forInfoDictionaryKey: "WhoopClientSecret") as? String ?? ""
    }
    private var redirectURI: String {
        Bundle.main.object(forInfoDictionaryKey: "WhoopRedirectURI") as? String ?? "healthaggregator://whoop/callback"
    }

    init() {
        isConnected = accessToken != nil
        if isConnected { Task { await loadCached() } }
    }

    // MARK: - OAuth

    func startOAuthFlow(presenting anchor: ASPresentationAnchor) async {
        let scopes = "offline read:recovery read:sleep read:workout read:cycle read:body_measurement"
        let state = UUID().uuidString
        var comps = URLComponents(string: "\(authBaseURL)/auth")!
        comps.queryItems = [
            .init(name: "response_type", value: "code"),
            .init(name: "client_id", value: clientID),
            .init(name: "redirect_uri", value: redirectURI),
            .init(name: "scope", value: scopes),
            .init(name: "state", value: state),
        ]
        guard let url = comps.url else { return }
        let callbackScheme = "healthaggregator"

        do {
            let result = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<URL, Error>) in
                let session = ASWebAuthenticationSession(url: url, callbackURLScheme: callbackScheme) { url, error in
                    if let error { cont.resume(throwing: error) }
                    else if let url { cont.resume(returning: url) }
                    else { cont.resume(throwing: WhoopError.invalidCallback) }
                }
                session.prefersEphemeralWebBrowserSession = true
                session.presentationContextProvider = AnchorProvider(anchor: anchor)
                authSession = session   // retain until callback fires
                session.start()
            }
            authSession = nil
            try await handleCallback(url: result)
        } catch {
            authError = error.localizedDescription
        }
    }

    func handleCallback(url: URL) async throws {
        guard let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let code = comps.queryItems?.first(where: { $0.name == "code" })?.value
        else { throw WhoopError.invalidCallback }
        try await exchangeCode(code)
        isConnected = true
        await refresh()
    }

    private func exchangeCode(_ code: String) async throws {
        var request = URLRequest(url: URL(string: "\(authBaseURL)/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = "grant_type=authorization_code&code=\(code)&redirect_uri=\(redirectURI)&client_id=\(clientID)&client_secret=\(clientSecret)"
        request.httpBody = body.data(using: .utf8)

        let (data, _) = try await URLSession.shared.data(for: request)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let tokens = try decoder.decode(WhoopTokenResponse.self, from: data)
        storeTokens(tokens)
    }

    private func refreshAccessToken() async throws {
        guard let rt = refreshToken else { throw WhoopError.notAuthenticated }
        var request = URLRequest(url: URL(string: "\(authBaseURL)/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = "grant_type=refresh_token&refresh_token=\(rt)&client_id=\(clientID)&client_secret=\(clientSecret)"
        request.httpBody = body.data(using: .utf8)

        let (data, _) = try await URLSession.shared.data(for: request)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let tokens = try decoder.decode(WhoopTokenResponse.self, from: data)
        storeTokens(tokens)
    }

    private func storeTokens(_ tokens: WhoopTokenResponse) {
        KeychainService.save(tokens.accessToken, for: .whoopAccessToken)
        KeychainService.save(tokens.refreshToken, for: .whoopRefreshToken)
        let expiry = Date().addingTimeInterval(Double(tokens.expiresIn))
        KeychainService.save(String(expiry.timeIntervalSince1970), for: .whoopTokenExpiry)
    }

    func disconnect() {
        KeychainService.deleteAll()
        isConnected = false
        snapshot = .empty
    }

    // MARK: - Data fetching

    func refresh() async {
        guard isConnected else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            if let expiry = tokenExpiry, expiry < Date() { try await refreshAccessToken() }
            async let recovery = fetchLatestRecovery()
            async let cycle = fetchLatestCycle()
            async let sleep = fetchLatestSleep()
            let (rec, cyc, slp) = try await (recovery, cycle, sleep)
            await MainActor.run {
                snapshot.recoveryScore = rec?.score?.recoveryScore
                snapshot.hrv = rec?.score?.hrvRmssdMilli
                snapshot.restingHR = rec?.score?.restingHeartRate
                snapshot.strain = cyc?.score?.strain
                snapshot.sleepPerformance = slp?.score?.sleepPerformancePercentage
                snapshot.lastUpdated = Date()
                saveToCache()
            }
        } catch {
            print("WHOOP refresh error: \(error)")
        }
    }

    func refreshIfNeeded() async throws {
        guard let last = snapshot.lastUpdated,
              Date().timeIntervalSince(last) < 30 * 60 else {
            await refresh()
            return
        }
    }

    private func fetchLatestRecovery() async throws -> WhoopRecovery? {
        let response: WhoopListResponse<WhoopRecovery> = try await get(path: "/recovery?limit=1&start=\(iso8601Yesterday())")
        return response.records.first
    }

    private func fetchLatestCycle() async throws -> WhoopCycle? {
        let response: WhoopListResponse<WhoopCycle> = try await get(path: "/cycle?limit=1")
        return response.records.first
    }

    private func fetchLatestSleep() async throws -> WhoopSleep? {
        let response: WhoopListResponse<WhoopSleep> = try await get(path: "/activity/sleep?limit=1")
        return response.records.first
    }

    private func get<T: Decodable>(path: String, retried: Bool = false) async throws -> T {
        guard let token = accessToken else { throw WhoopError.notAuthenticated }
        var request = URLRequest(url: URL(string: "\(baseURL)\(path)")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 401 {
            guard !retried else { throw WhoopError.notAuthenticated }   // prevent infinite recursion
            try await refreshAccessToken()
            return try await get(path: path, retried: true)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: data)
    }

    private func iso8601Yesterday() -> String {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        return ISO8601DateFormatter().string(from: yesterday)
    }

    // MARK: - Cache
    private func saveToCache() {
        if let encoded = try? JSONEncoder().encode(snapshot) {
            UserDefaults.standard.set(encoded, forKey: "whoop_snapshot_cache")
        }
    }

    private func loadCached() async {
        guard let data = UserDefaults.standard.data(forKey: "whoop_snapshot_cache"),
              let snap = try? JSONDecoder().decode(WhoopSnapshot.self, from: data) else { return }
        await MainActor.run { snapshot = snap; isConnected = true }
        await refresh()
    }
}

// MARK: - Supporting types

private struct WhoopListResponse<T: Codable>: Codable {
    let records: [T]
}

private class AnchorProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    let anchor: ASPresentationAnchor
    init(anchor: ASPresentationAnchor) { self.anchor = anchor }
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor { anchor }
}

enum WhoopError: LocalizedError {
    case invalidCallback
    case notAuthenticated
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .invalidCallback: return "Invalid OAuth callback URL"
        case .notAuthenticated: return "Not authenticated with WHOOP"
        case .apiError(let m): return "WHOOP API error: \(m)"
        }
    }
}

