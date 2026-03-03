import Foundation
import Combine

/// Service for syncing user data with AWS backend
final class SyncService: ObservableObject {
    
    // MARK: - Configuration
    
    private struct Config {
        static let apiBaseURL = "https://XXXXXXXXXX.execute-api.eu-central-1.amazonaws.com/prod" // TODO: Replace after deployment
    }
    
    // MARK: - Published Properties
    
    @Published private(set) var isSyncing = false
    @Published private(set) var lastSyncedAt: Date?
    @Published var syncError: Error?
    
    // MARK: - Private Properties
    
    private let session: URLSession
    private let auth = AuthService.shared
    private let defaults = UserDefaults.standard
    
    private let lastSyncKey = "moatheny_last_sync"
    
    // MARK: - Singleton
    
    static let shared = SyncService()
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        self.session = URLSession(configuration: config)
        
        if let timestamp = defaults.object(forKey: lastSyncKey) as? Date {
            lastSyncedAt = timestamp
        }
    }
    
    // MARK: - Public Methods
    
    /// Perform full sync with server
    func sync() async throws {
        guard auth.isAuthenticated else {
            throw SyncError.notAuthenticated
        }
        
        await MainActor.run { isSyncing = true }
        defer { Task { @MainActor in isSyncing = false } }
        
        let localData = gatherLocalData()
        
        let syncedData = try await performSync(localData: localData)
        
        applyServerData(syncedData)
        
        let now = Date()
        defaults.set(now, forKey: lastSyncKey)
        await MainActor.run { lastSyncedAt = now }
    }
    
    /// Get user settings from server
    func getSettings() async throws -> UserSettings {
        let data = try await apiRequest(method: "GET", path: "/settings")
        return try JSONDecoder().decode(UserSettings.self, from: data)
    }
    
    /// Save user settings to server
    func saveSettings(_ settings: UserSettings) async throws {
        let body = try JSONEncoder().encode(settings)
        let _ = try await apiRequest(method: "PUT", path: "/settings", body: body)
    }
    
    /// Get favorites from server
    func getFavorites(type: FavoriteType? = nil) async throws -> [Favorite] {
        var path = "/favorites"
        if let type = type {
            path += "?type=\(type.rawValue)"
        }
        
        let data = try await apiRequest(method: "GET", path: path)
        let response = try JSONDecoder().decode(FavoritesResponse.self, from: data)
        return response.favorites
    }
    
    /// Save a favorite to server
    func saveFavorite(_ favorite: Favorite) async throws {
        let body = try JSONEncoder().encode(favorite)
        let _ = try await apiRequest(method: "POST", path: "/favorites", body: body)
    }
    
    /// Delete a favorite from server
    func deleteFavorite(itemId: String) async throws {
        let _ = try await apiRequest(method: "DELETE", path: "/favorites/\(itemId)")
    }
    
    /// Get tasbih counters from server
    func getTasbih() async throws -> [TasbihCounter] {
        let data = try await apiRequest(method: "GET", path: "/tasbih")
        let response = try JSONDecoder().decode(TasbihResponse.self, from: data)
        return response.counters
    }
    
    /// Save tasbih counter to server
    func saveTasbih(_ counter: TasbihCounter) async throws {
        let body = try JSONEncoder().encode(counter)
        let _ = try await apiRequest(method: "POST", path: "/tasbih", body: body)
    }
    
    /// Log analytics event
    func logEvent(name: String, properties: [String: Any]? = nil) async {
        do {
            var event: [String: Any] = [
                "event": name,
                "platform": "ios",
                "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
            ]
            
            if let userId = auth.currentUser?.id {
                event["userId"] = userId
            } else {
                event["deviceId"] = UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
            }
            
            if let properties = properties {
                event["properties"] = properties
            }
            
            let body = try JSONSerialization.data(withJSONObject: event)
            let _ = try await apiRequest(method: "POST", path: "/analytics", body: body, requiresAuth: false)
        } catch {
            print("Analytics error: \(error)")
        }
    }
    
    // MARK: - Private Methods
    
    private func apiRequest(method: String, path: String, body: Data? = nil, requiresAuth: Bool = true) async throws -> Data {
        guard let url = URL(string: Config.apiBaseURL + path) else {
            throw SyncError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if requiresAuth {
            let token = try await auth.getAccessToken()
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        if let body = body {
            request.httpBody = body
        }
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SyncError.networkError
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            return data
        case 401:
            throw SyncError.unauthorized
        case 400...499:
            throw SyncError.clientError(httpResponse.statusCode)
        case 500...599:
            throw SyncError.serverError(httpResponse.statusCode)
        default:
            throw SyncError.httpError(httpResponse.statusCode)
        }
    }
    
    private func performSync(localData: SyncData) async throws -> SyncResponse {
        let requestBody = SyncRequest(
            lastSyncedAt: lastSyncedAt?.ISO8601Format(),
            data: localData
        )
        
        let body = try JSONEncoder().encode(requestBody)
        let data = try await apiRequest(method: "POST", path: "/sync", body: body)
        return try JSONDecoder().decode(SyncResponse.self, from: data)
    }
    
    private func gatherLocalData() -> SyncData {
        var data = SyncData()
        
        if let settingsData = defaults.data(forKey: "local_settings"),
           let settings = try? JSONDecoder().decode(UserSettings.self, from: settingsData) {
            data.settings = settings
        }
        
        if let favoritesData = defaults.data(forKey: "local_favorites"),
           let favorites = try? JSONDecoder().decode([Favorite].self, from: favoritesData) {
            data.favorites = favorites
        }
        
        if let tasbihData = defaults.data(forKey: "local_tasbih"),
           let tasbih = try? JSONDecoder().decode([TasbihCounter].self, from: tasbihData) {
            data.tasbih = tasbih
        }
        
        return data
    }
    
    private func applyServerData(_ response: SyncResponse) {
        if let settings = response.settings,
           let data = try? JSONEncoder().encode(settings) {
            defaults.set(data, forKey: "local_settings")
        }
        
        if let data = try? JSONEncoder().encode(response.favorites) {
            defaults.set(data, forKey: "local_favorites")
        }
        
        if let data = try? JSONEncoder().encode(response.tasbih) {
            defaults.set(data, forKey: "local_tasbih")
        }
    }
}

// MARK: - Models

struct UserSettings: Codable {
    var calculationMethod: Int?
    var notificationsEnabled: Bool?
    var language: String?
    var theme: String?
    var latitude: Double?
    var longitude: Double?
    var cityName: String?
}

enum FavoriteType: String, Codable {
    case surah
    case ayah
    case zikr
    case reciter
}

struct Favorite: Codable, Identifiable {
    var id: String { itemId }
    let itemId: String
    let type: FavoriteType
    let referenceId: String?
    let title: String?
    let subtitle: String?
    let createdAt: String?
}

struct FavoritesResponse: Codable {
    let favorites: [Favorite]
}

struct TasbihResponse: Codable {
    let counters: [TasbihCounter]
}

struct SyncRequest: Codable {
    let lastSyncedAt: String?
    let data: SyncData
}

struct SyncData: Codable {
    var settings: UserSettings?
    var favorites: [Favorite]?
    var tasbih: [TasbihCounter]?
    var prayers: [PrayerLog]?
}

struct PrayerLog: Codable {
    let date: String
    var fajr: Bool
    var dhuhr: Bool
    var asr: Bool
    var maghrib: Bool
    var isha: Bool
    var notes: String?
}

struct SyncResponse: Codable {
    let settings: UserSettings?
    let favorites: [Favorite]
    let tasbih: [TasbihCounter]
    let prayers: [PrayerLog]
    let syncedAt: String
}

// MARK: - Errors

enum SyncError: LocalizedError {
    case notAuthenticated
    case unauthorized
    case invalidURL
    case networkError
    case httpError(Int)
    case clientError(Int)
    case serverError(Int)
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "يرجى تسجيل الدخول للمزامنة"
        case .unauthorized:
            return "انتهت صلاحية الجلسة"
        case .invalidURL:
            return "رابط غير صالح"
        case .networkError:
            return "خطأ في الاتصال بالشبكة"
        case .httpError(let code):
            return "خطأ HTTP: \(code)"
        case .clientError(let code):
            return "خطأ في الطلب: \(code)"
        case .serverError(let code):
            return "خطأ في الخادم: \(code)"
        }
    }
}

// MARK: - TasbihCounter Extension

extension TasbihCounter: Codable {
    enum CodingKeys: String, CodingKey {
        case id = "counterId"
        case title
        case target
        case current
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let idString = try container.decode(String.self, forKey: .id)
        id = UUID(uuidString: idString) ?? UUID()
        title = try container.decode(String.self, forKey: .title)
        target = try container.decode(Int.self, forKey: .target)
        current = try container.decode(Int.self, forKey: .current)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id.uuidString, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(target, forKey: .target)
        try container.encode(current, forKey: .current)
    }
}
