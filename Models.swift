import Foundation
import CoreLocation

// MARK: - Prayer

enum CalculationMethod: Int, Codable, CaseIterable {
    case muslimWorldLeague = 3
    case egyptian = 5
    case karachi = 1
    case ummAlQura = 4
    case isna = 2
}

#if canImport(Adhan)
import Adhan
extension CalculationMethod {
    /// Map our enum to Adhan's CalculationParameters
    var adhanParameters: CalculationParameters {
        switch self {
        case .muslimWorldLeague: 
            return Adhan.CalculationMethod.muslimWorldLeague.params
        case .egyptian: 
            return Adhan.CalculationMethod.egyptian.params
        case .karachi: 
            return Adhan.CalculationMethod.karachi.params
        case .ummAlQura: 
            return Adhan.CalculationMethod.ummAlQura.params
        case .isna: 
            return Adhan.CalculationMethod.northAmerica.params
        }
    }
}
#endif

struct Prayer: Identifiable, Codable, Equatable {
    let id: String              // e.g., fajr, sunrise
    let name: String            // English display
    let arabicName: String      // Arabic display
    let time: Date
}

struct PrayerDay: Codable {
    let date: Date
    let prayers: [Prayer]
}

// MARK: - Quran

struct Reciter: Identifiable, Codable, Hashable {
    let id: Int
    let name: String
    let arabicName: String
    let style: String?
    let bitrate: Int?
    let baseURL: URL
}

struct Translation: Codable, Hashable {
    let language: String
    let text: String
}

struct Ayah: Identifiable, Codable, Hashable {
    let id: Int
    let numberInSurah: Int
    let text: String
    let juz: Int
    let hizb: Int
    let page: Int
    let audioURL: URL?
    let translations: [Translation]?
}

struct Surah: Identifiable, Codable, Hashable {
    let id: Int
    let name: String
    let englishName: String
    let revelationType: String
    let numberOfAyahs: Int
    let ayahs: [Ayah]
}

// MARK: - Azkar

enum AzkarCategory: String, Codable, CaseIterable {
    case morning, evening, sleep, wakeUp, afterPrayer, food, travel, mosque, ablution, quranicDuas, propheticDuas, ruqyah, namesOfAllah
}

struct Zikr: Identifiable, Codable, Hashable {
    let id: Int
    let category: AzkarCategory
    let arabicText: String
    let transliteration: String?
    let translation: String
    let reference: String?
    let repetitionCount: Int
    let benefit: String?
    let audioURL: URL?
}

// MARK: - Tasbih

struct TasbihCounter: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var target: Int
    var current: Int
}

