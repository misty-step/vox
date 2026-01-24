import Combine
import Foundation

@MainActor
final class AuthManager: ObservableObject {
    static let shared = AuthManager()

    enum State: Equatable {
        case unknown
        case authenticated(token: String)
        case unauthenticated
    }

    @Published private(set) var state: State = .unknown

    var token: String? {
        if case let .authenticated(token) = state {
            return token
        }
        return nil
    }

    var isAuthenticated: Bool {
        token != nil
    }

    init() {
        if let token = KeychainHelper.load(), !token.isEmpty {
            state = .authenticated(token: token)
            Diagnostics.info("Auth token loaded from keychain.")
        } else {
            state = .unauthenticated
            Diagnostics.info("No auth token found in keychain.")
        }
    }

    func handleDeepLink(url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            Diagnostics.warning("Ignoring auth deep link: invalid URL.")
            return
        }
        guard components.scheme == "vox" else { return }
        let host = components.host ?? ""
        let path = components.path
        guard host == "auth" || path == "/auth" else { return }

        guard let token = components.queryItems?.first(where: { $0.name == "token" })?.value,
              !token.isEmpty else {
            Diagnostics.warning("Auth deep link missing token.")
            return
        }

        do {
            try KeychainHelper.save(token: token)
            state = .authenticated(token: token)
            Diagnostics.info("Stored auth token from deep link.")
        } catch {
            Diagnostics.warning("Failed to save auth token: \(error.localizedDescription)")
        }
    }

    func signOut() {
        do {
            try KeychainHelper.delete()
            state = .unauthenticated
            Diagnostics.info("Signed out.")
        } catch {
            Diagnostics.warning("Failed to delete auth token: \(error.localizedDescription)")
        }
    }
}
