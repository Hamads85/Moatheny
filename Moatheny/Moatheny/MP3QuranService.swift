import Foundation
import Combine

/// خدمة MP3Quran API للقراء الصوتيين
/// المصدر: https://www.mp3quran.net/ar/api
final class MP3QuranService: ObservableObject {
    
    // MARK: - Published Properties
    @Published var reciters: [MP3Reciter] = []
    @Published var currentReciter: MP3Reciter?
    @Published var surahList: [MP3Surah] = []
    @Published var isLoading = false
    @Published var error: String?
    
    // MARK: - Private Properties
    private let session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 30
        cfg.requestCachePolicy = .returnCacheDataElseLoad
        return URLSession(configuration: cfg)
    }()
    
    private let decoder = JSONDecoder()
    private let baseURL = "https://mp3quran.net/api/v3"
    
    // MARK: - Initialization
    init() {
        Task {
            await loadInitialData()
        }
    }
    
    // MARK: - Public Methods
    
    /// تحميل البيانات الأولية
    @MainActor
    func loadInitialData() async {
        isLoading = true
        error = nil
        
        do {
            // تحميل قائمة السور
            surahList = try await fetchSurahList()
            
            // تحميل قائمة القراء
            reciters = try await fetchReciters()
            
            // اختيار قارئ افتراضي (مشاري العفاسي)
            if let defaultReciter = reciters.first(where: { $0.name.contains("مشاري") || $0.name.contains("العفاسي") }) {
                currentReciter = defaultReciter
            } else {
                currentReciter = reciters.first
            }
            
        } catch {
            self.error = error.localizedDescription
            print("❌ خطأ في تحميل بيانات MP3Quran: \(error)")
        }
        
        isLoading = false
    }
    
    /// جلب قائمة السور
    func fetchSurahList(language: String = "ar") async throws -> [MP3Surah] {
        guard let url = URL(string: "\(baseURL)/suwar?language=\(language)") else {
            throw MP3QuranError.invalidURL
        }
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              200..<300 ~= httpResponse.statusCode else {
            throw MP3QuranError.serverError
        }
        
        struct Response: Decodable {
            let suwar: [MP3Surah]
        }
        
        let parsed = try decoder.decode(Response.self, from: data)
        return parsed.suwar
    }
    
    /// جلب قائمة القراء
    func fetchReciters(language: String = "ar") async throws -> [MP3Reciter] {
        guard let url = URL(string: "\(baseURL)/reciters?language=\(language)") else {
            throw MP3QuranError.invalidURL
        }
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              200..<300 ~= httpResponse.statusCode else {
            throw MP3QuranError.serverError
        }
        
        struct Response: Decodable {
            let reciters: [MP3Reciter]
        }
        
        let parsed = try decoder.decode(Response.self, from: data)
        return parsed.reciters
    }
    
    /// جلب قائمة الروايات
    func fetchRewayat(language: String = "ar") async throws -> [MP3Rewayah] {
        guard let url = URL(string: "\(baseURL)/riwayat?language=\(language)") else {
            throw MP3QuranError.invalidURL
        }
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              200..<300 ~= httpResponse.statusCode else {
            throw MP3QuranError.serverError
        }
        
        struct Response: Decodable {
            let riwayat: [MP3Rewayah]
        }
        
        let parsed = try decoder.decode(Response.self, from: data)
        return parsed.riwayat
    }
    
    /// جلب قائمة الإذاعات
    func fetchRadios(language: String = "ar") async throws -> [MP3Radio] {
        guard let url = URL(string: "\(baseURL)/radios?language=\(language)") else {
            throw MP3QuranError.invalidURL
        }
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              200..<300 ~= httpResponse.statusCode else {
            throw MP3QuranError.serverError
        }
        
        struct Response: Decodable {
            let radios: [MP3Radio]
        }
        
        let parsed = try decoder.decode(Response.self, from: data)
        return parsed.radios
    }
    
    /// جلب قائمة التفاسير
    func fetchTafasir(language: String = "ar") async throws -> [MP3Tafsir] {
        guard let url = URL(string: "\(baseURL)/tafasir?language=\(language)") else {
            throw MP3QuranError.invalidURL
        }
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              200..<300 ~= httpResponse.statusCode else {
            throw MP3QuranError.serverError
        }
        
        struct Response: Decodable {
            let tafasir: [MP3Tafsir]
        }
        
        let parsed = try decoder.decode(Response.self, from: data)
        return parsed.tafasir
    }
    
    /// الحصول على رابط الصوت لسورة معينة من قارئ معين
    func getAudioURL(reciter: MP3Reciter, surahNumber: Int) -> URL? {
        guard let moshaf = reciter.moshaf.first else { return nil }
        
        // تنسيق رقم السورة (001, 002, ..., 114)
        let surahStr = String(format: "%03d", surahNumber)
        
        // بناء الرابط
        let audioURLString = "\(moshaf.server)\(surahStr).mp3"
        return URL(string: audioURLString)
    }
    
    /// التحقق من توفر سورة معينة لقارئ معين
    func isSurahAvailable(reciter: MP3Reciter, surahNumber: Int) -> Bool {
        guard let moshaf = reciter.moshaf.first else { return false }
        return moshaf.surahList.contains(surahNumber)
    }
    
    /// البحث في القراء
    func searchReciters(query: String) -> [MP3Reciter] {
        guard !query.isEmpty else { return reciters }
        return reciters.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }
    
    /// تحديث القارئ الحالي
    @MainActor
    func selectReciter(_ reciter: MP3Reciter) {
        currentReciter = reciter
    }
}

// MARK: - Data Models

/// نموذج السورة
struct MP3Surah: Codable, Identifiable {
    let id: Int
    let name: String
    let startPage: Int
    let endPage: Int
    let makkia: Int
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case startPage = "start_page"
        case endPage = "end_page"
        case makkia
    }
    
    var isMakki: Bool {
        makkia == 1
    }
    
    var revelationType: String {
        isMakki ? "مكية" : "مدنية"
    }
}

/// نموذج القارئ
struct MP3Reciter: Codable, Identifiable {
    let id: Int
    let name: String
    let letter: String
    let moshaf: [MP3Moshaf]
    
    var displayName: String {
        name
    }
}

/// نموذج المصحف
struct MP3Moshaf: Codable, Identifiable {
    let id: Int
    let name: String
    let server: String
    let surahTotal: Int
    let moshafType: Int
    let surahList: [Int]
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case server
        case surahTotal = "surah_total"
        case moshafType = "moshaf_type"
        case surahList = "surah_list"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        server = try container.decode(String.self, forKey: .server)
        surahTotal = try container.decode(Int.self, forKey: .surahTotal)
        moshafType = try container.decode(Int.self, forKey: .moshafType)
        
        // surah_list يأتي كـ string "1,2,3,..." نحوله لـ array
        let surahListString = try container.decode(String.self, forKey: .surahList)
        surahList = surahListString.split(separator: ",").compactMap { Int($0) }
    }
}

/// نموذج الرواية
struct MP3Rewayah: Codable, Identifiable {
    let id: Int
    let name: String
}

/// نموذج الإذاعة
struct MP3Radio: Codable, Identifiable {
    let id: Int
    let name: String
    let url: String
    let recentDate: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case url
        case recentDate = "recent_date"
    }
}

/// نموذج التفسير
struct MP3Tafsir: Codable, Identifiable {
    let id: Int
    let name: String
}

// MARK: - Error Types

enum MP3QuranError: LocalizedError {
    case invalidURL
    case serverError
    case decodingError
    case noData
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "رابط غير صالح"
        case .serverError:
            return "خطأ في الخادم"
        case .decodingError:
            return "خطأ في معالجة البيانات"
        case .noData:
            return "لا توجد بيانات"
        }
    }
}

