import AuthenticationServices
import SwiftUI

@Observable
final class AuthService: NSObject {
    var isSignedIn: Bool = false
    var userID: String = ""
    var displayName: String = ""
    var email: String = ""
    var isGuest: Bool = false

    private let userIDKey   = "auth_user_id"
    private let nameKey     = "auth_display_name"
    private let emailKey    = "auth_email"
    private let guestKey    = "auth_is_guest"

    override init() {
        super.init()
        loadFromDefaults()
    }

    // MARK: - Sign in with Apple

    func signInWithApple(presentationAnchor: ASPresentationAnchor) {
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        _anchor = presentationAnchor
        controller.performRequests()
    }

    private var _anchor: ASPresentationAnchor?

    // MARK: - Guest / Skip

    func continueAsGuest() {
        isGuest = true
        isSignedIn = true
        userID = "guest"
        displayName = "Guest"
        email = ""
        save()
    }

    // MARK: - Sign out

    func signOut() {
        isSignedIn = false
        isGuest = false
        userID = ""
        displayName = ""
        email = ""
        UserDefaults.standard.removeObject(forKey: userIDKey)
        UserDefaults.standard.removeObject(forKey: nameKey)
        UserDefaults.standard.removeObject(forKey: emailKey)
        UserDefaults.standard.removeObject(forKey: guestKey)
    }

    // MARK: - Revocation check

    func checkCredentialState() async {
        guard !isGuest, !userID.isEmpty else { return }
        let state = try? await ASAuthorizationAppleIDProvider().credentialState(forUserID: userID)
        if state == .revoked || state == .notFound {
            await MainActor.run { signOut() }
        }
    }

    // MARK: - Persistence

    func persistToDefaults() { save() }

    private func save() {
        UserDefaults.standard.set(userID,      forKey: userIDKey)
        UserDefaults.standard.set(displayName, forKey: nameKey)
        UserDefaults.standard.set(email,       forKey: emailKey)
        UserDefaults.standard.set(isGuest,     forKey: guestKey)
    }

    private func loadFromDefaults() {
        userID      = UserDefaults.standard.string(forKey: userIDKey) ?? ""
        displayName = UserDefaults.standard.string(forKey: nameKey)   ?? ""
        email       = UserDefaults.standard.string(forKey: emailKey)  ?? ""
        isGuest     = UserDefaults.standard.bool(forKey: guestKey)
        isSignedIn  = !userID.isEmpty
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension AuthService: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else { return }

        userID = credential.user
        isGuest = false

        // Apple only sends name/email on first sign-in; persist what we get
        if let fullName = credential.fullName {
            let given  = fullName.givenName  ?? ""
            let family = fullName.familyName ?? ""
            let name   = [given, family].filter { !$0.isEmpty }.joined(separator: " ")
            if !name.isEmpty { displayName = name }
        }
        if let appleEmail = credential.email, !appleEmail.isEmpty {
            email = appleEmail
        }

        // Use a fallback display name if Apple didn't provide one
        if displayName.isEmpty { displayName = email.isEmpty ? "Health+ User" : email.components(separatedBy: "@").first ?? "User" }

        isSignedIn = true
        save()
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        // User cancelled or error — don't change state
        print("Apple Sign In error: \(error.localizedDescription)")
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding

extension AuthService: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        _anchor ?? ASPresentationAnchor()
    }
}
