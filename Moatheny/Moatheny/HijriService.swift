import Foundation

final class HijriService {
    /// تاريخ هجري (أم القرى) منسق بالعربية.
    func hijriString(for date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .islamicUmmAlQura)
        formatter.locale = Locale(identifier: "ar")
        formatter.timeZone = .current
        formatter.dateFormat = "d MMMM yyyy هـ"
        return formatter.string(from: date)
    }
    
    /// رقم اليوم في الشهر الهجري (أم القرى).
    func hijriDay(for date: Date = Date()) -> Int {
        let cal = Calendar(identifier: .islamicUmmAlQura)
        return cal.component(.day, from: date)
    }
}

