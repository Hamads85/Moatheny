import Foundation
import Combine

/// Authentication service using AWS Cognito
final class AuthService: ObservableObject {
    
    // MARK: - Configuration
    
    private struct Config {
        static let userPoolId = "eu-central-1_mqThjbgqC"
        static let clientId = "6feqgak7g7al8hv76veckv5hhj"
        static let region = "eu-central-1"
        
        static var cognitoURL: URL {
            URL(string: "https://cognito-idp.\(region).amazonaws.com")!
        }
    }
    
    // MARK: - Published Properties
    
    @Published private(set) var isAuthenticated = false
    @Published private(set) var currentUser: User?
    @Published private(set) var isLoading = false
    @Published var error: AuthError?
    
    // MARK: - Private Properties
    
    private let session: URLSession
    private let keychain = KeychainHelper.shared
    private var cancellables = Set<AnyCancellable>()
    
    // Token storage keys
    private let accessTokenKey = "moatheny_access_token"
    private let refreshTokenKey = "moatheny_refresh_token"
    private let idTokenKey = "moatheny_id_token"
    private let userKey = "moatheny_user"
    
    // MARK: - Singleton
    
    static let shared = AuthService()
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: config)
        
        loadStoredSession()
    }
    
    // MARK: - Public Methods
    
    /// Sign up a new user
    func signUp(email: String, password: String, name: String? = nil) async throws {
        await MainActor.run { isLoading = true }
        defer { Task { @MainActor in isLoading = false } }
        
        let parameters: [String: Any] = [
            "ClientId": Config.clientId,
            "Username": email,
            "Password": password,
            "UserAttributes": [
                ["Name": "email", "Value": email],
                name.map { ["Name": "name", "Value": $0] }
            ].compactMap { $0 }
        ]
        
        let _ = try await cognitoRequest(action: "SignUp", parameters: parameters)
    }
    
    /// Confirm sign up with verification code
    func confirmSignUp(email: String, code: String) async throws {
        await MainActor.run { isLoading = true }
        defer { Task { @MainActor in isLoading = false } }
        
        let parameters: [String: Any] = [
            "ClientId": Config.clientId,
            "Username": email,
            "ConfirmationCode": code
        ]
        
        let _ = try await cognitoRequest(action: "ConfirmSignUp", parameters: parameters)
    }
    
    /// Sign in with email and password
    func signIn(email: String, password: String) async throws {
        await MainActor.run { isLoading = true }
        defer { Task { @MainActor in isLoading = false } }
        
        let parameters: [String: Any] = [
            "AuthFlow": "USER_PASSWORD_AUTH",
            "ClientId": Config.clientId,
            "AuthParameters": [
                "USERNAME": email,
                "PASSWORD": password
            ]
        ]
        
        let response = try await cognitoRequest(action: "InitiateAuth", parameters: parameters)
        
        guard let authResult = response["AuthenticationResult"] as? [String: Any],
              let accessToken = authResult["AccessToken"] as? String,
              let refreshToken = authResult["RefreshToken"] as? String,
              let idToken = authResult["IdToken"] as? String else {
            throw AuthError.invalidResponse
        }
        
        try saveTokens(accessToken: accessToken, refreshToken: refreshToken, idToken: idToken)
        
        let user = try await fetchUserInfo(accessToken: accessToken)
        try saveUser(user)
        
        await MainActor.run {
            self.currentUser = user
            self.isAuthenticated = true
        }
    }
    
    /// Sign out
    func signOut() {
        keychain.delete(key: accessTokenKey)
        keychain.delete(key: refreshTokenKey)
        keychain.delete(key: idTokenKey)
        keychain.delete(key: userKey)
        
        DispatchQueue.main.async {
            self.currentUser = nil
            self.isAuthenticated = false
        }
    }
    
    /// Get current access token (refreshes if needed)
    func getAccessToken() async throws -> String {
        guard let accessToken = keychain.get(key: accessTokenKey) else {
            throw AuthError.notAuthenticated
        }
        
        if isTokenExpired(accessToken) {
            return try await refreshAccessToken()
        }
        
        return accessToken
    }
    
    /// Resend confirmation code
    func resendConfirmationCode(email: String) async throws {
        let parameters: [String: Any] = [
            "ClientId": Config.clientId,
            "Username": email
        ]
        
        let _ = try await cognitoRequest(action: "ResendConfirmationCode", parameters: parameters)
    }
    
    /// Request password reset
    func forgotPassword(email: String) async throws {
        let parameters: [String: Any] = [
            "ClientId": Config.clientId,
            "Username": email
        ]
        
        let _ = try await cognitoRequest(action: "ForgotPassword", parameters: parameters)
    }
    
    /// Confirm password reset
    func confirmForgotPassword(email: String, code: String, newPassword: String) async throws {
        let parameters: [String: Any] = [
            "ClientId": Config.clientId,
            "Username": email,
            "ConfirmationCode": code,
            "Password": newPassword
        ]
        
        let _ = try await cognitoRequest(action: "ConfirmForgotPassword", parameters: parameters)
    }
    
    // MARK: - Private Methods
    
    private func loadStoredSession() {
        guard let _ = keychain.get(key: accessTokenKey),
              let userData = keychain.getData(key: userKey),
              let user = try? JSONDecoder().decode(User.self, from: userData) else {
            return
        }
        
        currentUser = user
        isAuthenticated = true
    }
    
    private func cognitoRequest(action: String, parameters: [String: Any]) async throws -> [String: Any] {
        var request = URLRequest(url: Config.cognitoURL)
        request.httpMethod = "POST"
        request.setValue("application/x-amz-json-1.1", forHTTPHeaderField: "Content-Type")
        request.setValue("AWSCognitoIdentityProviderService.\(action)", forHTTPHeaderField: "X-Amz-Target")
        request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.networkError
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        
        if httpResponse.statusCode != 200 {
            if let errorType = json["__type"] as? String {
                throw AuthError.cognitoError(errorType, json["message"] as? String ?? "Unknown error")
            }
            throw AuthError.httpError(httpResponse.statusCode)
        }
        
        return json
    }
    
    private func fetchUserInfo(accessToken: String) async throws -> User {
        let parameters: [String: Any] = [
            "AccessToken": accessToken
        ]
        
        let response = try await cognitoRequest(action: "GetUser", parameters: parameters)
        
        guard let username = response["Username"] as? String,
              let attributes = response["UserAttributes"] as? [[String: String]] else {
            throw AuthError.invalidResponse
        }
        
        var email = ""
        var name: String?
        var sub = ""
        
        for attr in attributes {
            switch attr["Name"] {
            case "email": email = attr["Value"] ?? ""
            case "name": name = attr["Value"]
            case "sub": sub = attr["Value"] ?? ""
            default: break
            }
        }
        
        return User(id: sub, email: email, name: name ?? username)
    }
    
    private func refreshAccessToken() async throws -> String {
        guard let refreshToken = keychain.get(key: refreshTokenKey) else {
            throw AuthError.notAuthenticated
        }
        
        let parameters: [String: Any] = [
            "AuthFlow": "REFRESH_TOKEN_AUTH",
            "ClientId": Config.clientId,
            "AuthParameters": [
                "REFRESH_TOKEN": refreshToken
            ]
        ]
        
        let response = try await cognitoRequest(action: "InitiateAuth", parameters: parameters)
        
        guard let authResult = response["AuthenticationResult"] as? [String: Any],
              let accessToken = authResult["AccessToken"] as? String,
              let idToken = authResult["IdToken"] as? String else {
            signOut()
            throw AuthError.sessionExpired
        }
        
        keychain.save(key: accessTokenKey, value: accessToken)
        keychain.save(key: idTokenKey, value: idToken)
        
        return accessToken
    }
    
    private func saveTokens(accessToken: String, refreshToken: String, idToken: String) throws {
        keychain.save(key: accessTokenKey, value: accessToken)
        keychain.save(key: refreshTokenKey, value: refreshToken)
        keychain.save(key: idTokenKey, value: idToken)
    }
    
    private func saveUser(_ user: User) throws {
        let data = try JSONEncoder().encode(user)
        keychain.save(key: userKey, data: data)
    }
    
    private func isTokenExpired(_ token: String) -> Bool {
        let parts = token.split(separator: ".")
        guard parts.count == 3,
              let payloadData = Data(base64Encoded: String(parts[1]).base64Padded),
              let payload = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any],
              let exp = payload["exp"] as? TimeInterval else {
            return true
        }
        
        return Date().timeIntervalSince1970 > exp - 300
    }
}

// MARK: - Models

extension AuthService {
    struct User: Codable, Identifiable {
        let id: String
        let email: String
        let name: String
    }
}

// MARK: - Errors

enum AuthError: LocalizedError {
    case notAuthenticated
    case sessionExpired
    case invalidResponse
    case networkError
    case httpError(Int)
    case cognitoError(String, String)
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "لم يتم تسجيل الدخول"
        case .sessionExpired:
            return "انتهت صلاحية الجلسة، يرجى تسجيل الدخول مرة أخرى"
        case .invalidResponse:
            return "استجابة غير صالحة من الخادم"
        case .networkError:
            return "خطأ في الاتصال بالشبكة"
        case .httpError(let code):
            return "خطأ HTTP: \(code)"
        case .cognitoError(let type, let message):
            return mapCognitoError(type: type, message: message)
        }
    }
    
    private func mapCognitoError(type: String, message: String) -> String {
        switch type {
        case "UserNotFoundException":
            return "البريد الإلكتروني غير مسجل"
        case "NotAuthorizedException":
            return "كلمة المرور غير صحيحة"
        case "UsernameExistsException":
            return "البريد الإلكتروني مسجل مسبقاً"
        case "InvalidPasswordException":
            return "كلمة المرور ضعيفة. يجب أن تحتوي على 8 أحرف على الأقل مع أرقام"
        case "CodeMismatchException":
            return "رمز التحقق غير صحيح"
        case "ExpiredCodeException":
            return "انتهت صلاحية رمز التحقق"
        case "UserNotConfirmedException":
            return "يرجى تأكيد البريد الإلكتروني أولاً"
        default:
            return message
        }
    }
}

// MARK: - Keychain Helper

final class KeychainHelper {
    static let shared = KeychainHelper()
    private init() {}
    
    func save(key: String, value: String) {
        guard let data = value.data(using: .utf8) else { return }
        save(key: key, data: data)
    }
    
    func save(key: String, data: Data) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }
    
    func get(key: String) -> String? {
        guard let data = getData(key: key) else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    func getData(key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        SecItemCopyMatching(query as CFDictionary, &result)
        return result as? Data
    }
    
    func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - String Extension

private extension String {
    var base64Padded: String {
        var str = self
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        
        while str.count % 4 != 0 {
            str += "="
        }
        return str
    }
}
