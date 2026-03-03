import Foundation

/// Networking layer for prayer times, Quran, reciters, and azkar.
final class APIClient {
    private let session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 15
        cfg.requestCachePolicy = .returnCacheDataElseLoad
        return URLSession(configuration: cfg)
    }()
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .secondsSince1970
        return d
    }()

    // MARK: Prayer Times (Aladhan)

    func fetchPrayerTimes(lat: Double, lon: Double, method: CalculationMethod) async throws -> PrayerDay {
        let ts = Int(Date().timeIntervalSince1970)
        guard let url = URL(string: "https://api.aladhan.com/v1/timings/\(ts)?latitude=\(lat)&longitude=\(lon)&method=\(method.rawValue)") else {
            throw AppError.network("Bad prayer URL")
        }
        let (data, resp) = try await session.data(from: url)
        guard let http = resp as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw AppError.network("Prayer API failed")
        }
        struct Response: Decodable {
            struct DataObj: Decodable {
                let timings: [String: String]
            }
            let data: DataObj
        }
        let parsed = try decoder.decode(Response.self, from: data)
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = .current

        func prayer(_ id: String, _ ar: String) -> Prayer? {
            guard let raw = parsed.data.timings[id],
                  let date = formatter.date(from: raw) else { return nil }
            return Prayer(id: id.lowercased(), name: id.capitalized, arabicName: ar, time: date)
        }

        let prayers = [
            prayer("Fajr", "الفجر"),
            prayer("Sunrise", "الشروق"),
            prayer("Dhuhr", "الظهر"),
            prayer("Asr", "العصر"),
            prayer("Maghrib", "المغرب"),
            prayer("Isha", "العشاء")
        ].compactMap { $0 }

        return PrayerDay(date: Date(), prayers: prayers)
    }

    // MARK: Quran Text (AlQuran Cloud)

    func fetchQuran() async throws -> [Surah] {
        guard let url = URL(string: "https://api.alquran.cloud/v1/quran/quran-uthmani") else {
            throw AppError.network("Bad Quran URL")
        }
        let (data, resp) = try await session.data(from: url)
        guard let http = resp as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw AppError.network("Quran API failed")
        }
        struct Response: Decodable {
            struct DataObj: Decodable {
                let surahs: [Surah]
            }
            let data: DataObj
        }
        let parsed = try decoder.decode(Response.self, from: data)
        return parsed.data.surahs
    }

    // MARK: Reciters (Quran.com)

    func fetchReciters() async throws -> [Reciter] {
        guard let url = URL(string: "https://api.quran.com/api/v4/resources/recitations") else {
            throw AppError.network("Bad reciters URL")
        }
        let (data, resp) = try await session.data(from: url)
        guard let http = resp as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw AppError.network("Reciters API failed")
        }
        struct Resp: Decodable { let recitations: [Reciter] }
        return try decoder.decode(Resp.self, from: data).recitations
    }

    // MARK: Azkar (GitHub raw example)

    func fetchAzkar() async throws -> [Zikr] {
        guard let url = URL(string: "https://raw.githubusercontent.com/osamayy/azkar-db/master/azkar.json") else {
            throw AppError.network("Bad azkar URL")
        }
        let (data, resp) = try await session.data(from: url)
        guard let http = resp as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw AppError.network("Azkar API failed")
        }
        return try decoder.decode([Zikr].self, from: data)
    }
}

