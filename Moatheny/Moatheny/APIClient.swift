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
            guard let raw = parsed.data.timings[id] else { return nil }
            // Aladhan يعيد "HH:mm" (وأحياناً "HH:mm (AST)")، نأخذ أول جزء.
            let clean = raw.components(separatedBy: " ").first ?? raw
            guard let timeOnly = formatter.date(from: clean) else { return nil }
            
            // تثبيت الوقت على تاريخ اليوم (بدلاً من تاريخ مرجعي 2000)
            let cal = Calendar.current
            let nowComps = cal.dateComponents([.year, .month, .day], from: Date())
            let timeComps = cal.dateComponents([.hour, .minute], from: timeOnly)
            var comps = DateComponents()
            comps.year = nowComps.year
            comps.month = nowComps.month
            comps.day = nowComps.day
            comps.hour = timeComps.hour
            comps.minute = timeComps.minute
            comps.second = 0
            
            guard let date = cal.date(from: comps) else { return nil }
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

        return PrayerDay(date: Date(), prayers: prayers, cityName: nil, hijriDate: nil)
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
        
        struct APIAyah: Decodable {
            let number: Int
            let numberInSurah: Int
            let text: String
            let juz: Int
            let page: Int
            let hizbQuarter: Int?
            let manzil: Int?
            let ruku: Int?
            let sajda: Bool?
            
            enum CodingKeys: String, CodingKey {
                case number, numberInSurah, text, juz, page
                case hizbQuarter, manzil, ruku, sajda
            }
        }
        
        struct APISurah: Decodable {
            let number: Int
            let name: String
            let englishName: String
            let revelationType: String
            let numberOfAyahs: Int
            let ayahs: [APIAyah]
        }
        
        struct Response: Decodable {
            struct DataObj: Decodable {
                let surahs: [APISurah]
            }
            let data: DataObj
        }
        
        let parsed = try decoder.decode(Response.self, from: data)
        
        // تحويل من API model إلى app model
        return parsed.data.surahs.map { apiSurah in
            Surah(
                id: apiSurah.number,
                name: apiSurah.name,
                englishName: apiSurah.englishName,
                revelationType: apiSurah.revelationType,
                numberOfAyahs: apiSurah.numberOfAyahs,
                ayahs: apiSurah.ayahs.map { apiAyah in
                    // حساب الحزب من hizbQuarter أو من الجزء
                    // كل جزء = 2 حزب، كل حزب = 4 أرباع
                    let calculatedHizb = apiAyah.hizbQuarter != nil ? 
                        (apiAyah.hizbQuarter! - 1) / 4 + 1 : // من رقم الربع
                        (apiAyah.juz - 1) * 2 + 1 // تقدير من الجزء
                    
                    return Ayah(
                        id: apiAyah.number,
                        numberInSurah: apiAyah.numberInSurah,
                        text: apiAyah.text,
                        juz: apiAyah.juz,
                        hizb: calculatedHizb,
                        page: apiAyah.page,
                        audioURL: nil,
                        translations: nil
                    )
                }
            )
        }
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

    // MARK: Qibla Direction (Aladhan)

    /// جلب اتجاه القبلة من API
    /// - Parameters:
    ///   - latitude: خط العرض
    ///   - longitude: خط الطول
    /// - Returns: اتجاه القبلة بالدرجات (0-360، حيث 0 = الشمال)
    func fetchQiblaDirection(latitude: Double, longitude: Double) async throws -> Double {
        guard let url = URL(string: "https://api.aladhan.com/v1/qibla/\(latitude)/\(longitude)") else {
            throw AppError.network("Bad qibla URL")
        }
        
        let (data, resp) = try await session.data(from: url)
        guard let http = resp as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw AppError.network("Qibla API failed")
        }
        
        struct Response: Decodable {
            let code: Int
            let status: String
            struct DataObj: Decodable {
                let latitude: Double
                let longitude: Double
                let direction: Double
            }
            let data: DataObj
        }
        
        let parsed = try decoder.decode(Response.self, from: data)
        
        // التحقق من نجاح الطلب
        guard parsed.code == 200, parsed.status == "OK" else {
            throw AppError.network("Qibla API returned error: \(parsed.status)")
        }
        
        // تطبيع الزاوية إلى [0, 360]
        var direction = parsed.data.direction
        while direction < 0 { direction += 360 }
        while direction >= 360 { direction -= 360 }
        
        return direction
    }
}

