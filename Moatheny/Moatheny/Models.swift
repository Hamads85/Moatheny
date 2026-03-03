import Foundation
import CoreLocation

// MARK: - Prayer

enum CalculationMethod: Int, Codable, CaseIterable {
    case muslimWorldLeague = 3
    case egyptian = 5
    case karachi = 1
    case ummAlQura = 4
    case isna = 2
    
    var arabicName: String {
        switch self {
        case .muslimWorldLeague: return "رابطة العالم الإسلامي"
        case .egyptian: return "الهيئة المصرية العامة للمساحة"
        case .karachi: return "جامعة العلوم الإسلامية، كراتشي"
        case .ummAlQura: return "أم القرى، مكة المكرمة"
        case .isna: return "الجمعية الإسلامية لأمريكا الشمالية"
        }
    }
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
    
    /// اسم المدينة (GPS أو اختيار يدوي) لعرضها في صفحة الأذان/القبلة.
    var cityName: String?
    
    /// التاريخ الهجري المنسق (للعرض).
    var hijriDate: String?
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
    case morning, evening, sleep, wakeUp, afterPrayer, food, travel, mosque, ablution, quranicDuas, propheticDuas, ruqyah, namesOfAllah, distress, forgiveness, salawat, friday, gratitude, protection, istikhara
    
    var arabicName: String {
        switch self {
        case .morning: return "أذكار الصباح"
        case .evening: return "أذكار المساء"
        case .sleep: return "أذكار النوم"
        case .wakeUp: return "أذكار الاستيقاظ"
        case .afterPrayer: return "أذكار بعد الصلاة"
        case .food: return "أذكار الطعام"
        case .travel: return "أذكار السفر"
        case .mosque: return "أذكار المسجد"
        case .ablution: return "أذكار الوضوء"
        case .quranicDuas: return "أدعية قرآنية"
        case .propheticDuas: return "أدعية نبوية"
        case .ruqyah: return "الرقية الشرعية"
        case .namesOfAllah: return "أسماء الله الحسنى"
        case .distress: return "أذكار الكرب والهم"
        case .forgiveness: return "الاستغفار والتوبة"
        case .salawat: return "الصلاة على النبي ﷺ"
        case .friday: return "أذكار يوم الجمعة"
        case .gratitude: return "أذكار الشكر"
        case .protection: return "أذكار الحفظ والحماية"
        case .istikhara: return "صلاة الاستخارة"
        }
    }
    
    var icon: String {
        switch self {
        case .morning: return "sun.max.fill"
        case .evening: return "moon.fill"
        case .sleep: return "bed.double.fill"
        case .wakeUp: return "alarm.fill"
        case .afterPrayer: return "hands.sparkles.fill"
        case .food: return "fork.knife"
        case .travel: return "airplane"
        case .mosque: return "building.columns.fill"
        case .ablution: return "drop.fill"
        case .quranicDuas: return "book.fill"
        case .propheticDuas: return "star.fill"
        case .ruqyah: return "shield.fill"
        case .namesOfAllah: return "sparkles"
        case .distress: return "heart.fill"
        case .forgiveness: return "arrow.uturn.backward.circle.fill"
        case .salawat: return "heart.text.square.fill"
        case .friday: return "calendar"
        case .gratitude: return "hand.raised.fill"
        case .protection: return "lock.shield.fill"
        case .istikhara: return "person.fill.questionmark"
        }
    }
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

