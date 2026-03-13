//
//  PrayerTimeWidget.swift
//  PrayerTimeWidget
//
//  Created by Hamad Alshabanah on 06/12/2025.
//

import WidgetKit
import SwiftUI
import CoreLocation
import Adhan

// MARK: - Prayer Data Model
struct PrayerData {
    let name: String
    let arabicName: String
    let time: Date
    let isNext: Bool
}

// MARK: - Timeline Entry
struct PrayerTimeEntry: TimelineEntry {
    let date: Date
    let nextPrayer: PrayerData?
    let previousPrayer: PrayerData?
    let allPrayers: [PrayerData]
    let locationName: String
    let hijriDate: String
    let state: WidgetState
    
    enum WidgetState {
        case loading
        case loaded
        case error(String)
    }
}

// MARK: - Timeline Provider
struct PrayerTimeProvider: TimelineProvider {
    
    // إحداثيات افتراضية (الرياض)
    private let defaultLatitude = 24.7136
    private let defaultLongitude = 46.6753
    
    // مدير الموقع للحصول على الموقع الحالي
    private let locationManager = CLLocationManager()
    
    func placeholder(in context: Context) -> PrayerTimeEntry {
        createPlaceholderEntry()
    }
    
    func getSnapshot(in context: Context, completion: @escaping (PrayerTimeEntry) -> Void) {
        let entry = createEntry(for: Date())
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<PrayerTimeEntry>) -> Void) {
        var entries: [PrayerTimeEntry] = []
        let now = Date()
        let cal = Calendar.current
        
        // 1. Entry for NOW (Immediate update)
        entries.append(createEntry(for: now))
        
        // 2. Calculate future prayer times for accurate scheduling
        // We need coordinates to calculate exact times
        var latitude = defaultLatitude
        var longitude = defaultLongitude
        
        if let sharedDefaults = UserDefaults(suiteName: "group.com.YourMangaApp.Moatheny") {
            if let lat = sharedDefaults.object(forKey: "lastKnownLatitude") as? Double,
               let lon = sharedDefaults.object(forKey: "lastKnownLongitude") as? Double {
                latitude = lat
                longitude = lon
            }
        }
        
        let coordinates = Coordinates(latitude: latitude, longitude: longitude)
        var params = CalculationMethod.ummAlQura.params
        params.madhab = .shafi
        
        var futureTimes: [Date] = []
        
        // Today's prayers
        let todayComps = cal.dateComponents([.year, .month, .day], from: now)
        if let todayPrayers = PrayerTimes(coordinates: coordinates, date: todayComps, calculationParameters: params) {
            let times = [todayPrayers.fajr, todayPrayers.sunrise, todayPrayers.dhuhr, todayPrayers.asr, todayPrayers.maghrib, todayPrayers.isha]
            futureTimes.append(contentsOf: times.filter { $0 > now })
        }
        
        // Tomorrow's prayers (to ensure continuity)
        if let tomorrow = cal.date(byAdding: .day, value: 1, to: now) {
            let tomorrowComps = cal.dateComponents([.year, .month, .day], from: tomorrow)
            if let tomorrowPrayers = PrayerTimes(coordinates: coordinates, date: tomorrowComps, calculationParameters: params) {
                let times = [tomorrowPrayers.fajr, tomorrowPrayers.sunrise, tomorrowPrayers.dhuhr, tomorrowPrayers.asr, tomorrowPrayers.maghrib, tomorrowPrayers.isha]
                futureTimes.append(contentsOf: times)
            }
        }
        
        // 3. Create timeline entries at exact prayer times
        for time in futureTimes {
            // Entry exactly at prayer time (switches "Next Prayer" to the new one)
            entries.append(createEntry(for: time))
            
            // Entry 20 minutes after (optional, to refresh UI state if needed)
            if let after20 = cal.date(byAdding: .minute, value: 20, to: time) {
                entries.append(createEntry(for: after20))
            }
        }
        
        // Sort and limit
        entries.sort { $0.date < $1.date }
        
        // Create the timeline
        // policy: .atEnd means request new timeline when these run out (tomorrow)
        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
    }
    
    // MARK: - Helper Methods
    
    private func createPlaceholderEntry() -> PrayerTimeEntry {
        let now = Date()
        return PrayerTimeEntry(
            date: now,
            nextPrayer: PrayerData(name: "Fajr", arabicName: "الفجر", time: now.addingTimeInterval(3600), isNext: true),
            previousPrayer: nil,
            allPrayers: [],
            locationName: "الرياض",
            hijriDate: "١٥ جمادى الآخرة ١٤٤٦",
            state: .loading
        )
    }
    
    private func createEntry(for date: Date) -> PrayerTimeEntry {
        // الحصول على الموقع من UserDefaults المشترك أو استخدام الموقع الافتراضي
        var latitude = defaultLatitude
        var longitude = defaultLongitude
        var locationName = "الرياض"
        
        if let sharedDefaults = UserDefaults(suiteName: "group.com.YourMangaApp.Moatheny") {
            if let savedLatitude = sharedDefaults.object(forKey: "lastKnownLatitude") as? Double,
               let savedLongitude = sharedDefaults.object(forKey: "lastKnownLongitude") as? Double {
                latitude = savedLatitude
                longitude = savedLongitude
            }
            
            if let savedCity = sharedDefaults.string(forKey: "lastKnownCity") {
                locationName = savedCity
            }
            
            // محاولة استخدام أوقات الصلاة المحفوظة من التطبيق الرئيسي
            if let lastUpdate = sharedDefaults.object(forKey: "lastPrayerUpdate") as? Date,
               Calendar.current.isDateInToday(lastUpdate),
               let savedPrayerTimes = loadSavedPrayerTimes(from: sharedDefaults) {
                // استخدام الأوقات المحفوظة
                let prayers = savedPrayerTimes
                let (nextPrayer, previousPrayer) = findNextAndPreviousPrayerFromSaved(prayers: prayers, currentDate: date)
                
                return PrayerTimeEntry(
                    date: date,
                    nextPrayer: nextPrayer,
                    previousPrayer: previousPrayer,
                    allPrayers: prayers,
                    locationName: locationName,
                    hijriDate: getHijriDate(from: date),
                    state: .loaded
                )
            }
        }
        
        // حساب أوقات الصلاة باستخدام Adhan
        let coordinates = Coordinates(latitude: latitude, longitude: longitude)
        
        // إعدادات الحساب (أم القرى - المذهب الحنبلي)
        var params = CalculationMethod.ummAlQura.params
        params.madhab = .shafi // المذهب الحنبلي يستخدم نفس أوقات الشافعي
        
        // حساب أوقات اليوم
        let comps = Calendar.current.dateComponents([.year, .month, .day], from: date)
        guard let prayerTimes = PrayerTimes(coordinates: coordinates, date: comps, calculationParameters: params) else {
            return PrayerTimeEntry(
                date: date,
                nextPrayer: nil,
                previousPrayer: nil,
                allPrayers: [],
                locationName: locationName,
                hijriDate: getHijriDate(from: date),
                state: .error("خطأ في حساب الأوقات")
            )
        }
        
        // تحويل إلى مصفوفة من الصلوات
        let prayers = createPrayerDataArray(from: prayerTimes, currentDate: date)
        
        // تحديد الصلاة القادمة والسابقة
        let (nextPrayer, previousPrayer) = findNextAndPreviousPrayer(prayers: prayers, currentDate: date, prayerTimes: prayerTimes, coordinates: coordinates, params: params)
        
        return PrayerTimeEntry(
            date: date,
            nextPrayer: nextPrayer,
            previousPrayer: previousPrayer,
            allPrayers: prayers,
            locationName: locationName,
            hijriDate: getHijriDate(from: date),
            state: .loaded
        )
    }
    
    private func loadSavedPrayerTimes(from defaults: UserDefaults) -> [PrayerData]? {
        guard let fajr = defaults.object(forKey: "prayer_fajr") as? Date,
              let sunrise = defaults.object(forKey: "prayer_sunrise") as? Date,
              let dhuhr = defaults.object(forKey: "prayer_dhuhr") as? Date,
              let asr = defaults.object(forKey: "prayer_asr") as? Date,
              let maghrib = defaults.object(forKey: "prayer_maghrib") as? Date,
              let isha = defaults.object(forKey: "prayer_isha") as? Date else {
            return nil
        }
        
        return [
            PrayerData(name: "Fajr", arabicName: "الفجر", time: fajr, isNext: false),
            PrayerData(name: "Sunrise", arabicName: "الشروق", time: sunrise, isNext: false),
            PrayerData(name: "Dhuhr", arabicName: "الظهر", time: dhuhr, isNext: false),
            PrayerData(name: "Asr", arabicName: "العصر", time: asr, isNext: false),
            PrayerData(name: "Maghrib", arabicName: "المغرب", time: maghrib, isNext: false),
            PrayerData(name: "Isha", arabicName: "العشاء", time: isha, isNext: false)
        ]
    }
    
    private func findNextAndPreviousPrayerFromSaved(prayers: [PrayerData], currentDate: Date) -> (next: PrayerData?, previous: PrayerData?) {
        // الصلوات الخمس فقط (بدون الشروق)
        let mainPrayers = prayers.filter { $0.name != "Sunrise" }
        
        // البحث عن الصلاة القادمة
        if let nextPrayerIndex = mainPrayers.firstIndex(where: { $0.time > currentDate }) {
            let next = mainPrayers[nextPrayerIndex]
            let previous = nextPrayerIndex > 0 ? mainPrayers[nextPrayerIndex - 1] : nil
            
            return (
                PrayerData(name: next.name, arabicName: next.arabicName, time: next.time, isNext: true),
                previous
            )
        }
        
        // إذا انتهت جميع صلوات اليوم، الصلاة القادمة هي فجر الغد
        // نحتاج لحساب فجر الغد
        return (nil, mainPrayers.last)
    }
    
    private func createPrayerDataArray(from prayerTimes: PrayerTimes, currentDate: Date) -> [PrayerData] {
        return [
            PrayerData(name: "Fajr", arabicName: "الفجر", time: prayerTimes.fajr, isNext: false),
            PrayerData(name: "Sunrise", arabicName: "الشروق", time: prayerTimes.sunrise, isNext: false),
            PrayerData(name: "Dhuhr", arabicName: "الظهر", time: prayerTimes.dhuhr, isNext: false),
            PrayerData(name: "Asr", arabicName: "العصر", time: prayerTimes.asr, isNext: false),
            PrayerData(name: "Maghrib", arabicName: "المغرب", time: prayerTimes.maghrib, isNext: false),
            PrayerData(name: "Isha", arabicName: "العشاء", time: prayerTimes.isha, isNext: false)
        ]
    }
    
    private func findNextAndPreviousPrayer(prayers: [PrayerData], currentDate: Date, prayerTimes: PrayerTimes, coordinates: Coordinates, params: CalculationParameters) -> (next: PrayerData?, previous: PrayerData?) {
        
        // الصلوات الخمس فقط (بدون الشروق)
        let mainPrayers = prayers.filter { $0.name != "Sunrise" }
        
        // البحث عن الصلاة القادمة
        if let nextPrayerIndex = mainPrayers.firstIndex(where: { $0.time > currentDate }) {
            let next = mainPrayers[nextPrayerIndex]
            let previous = nextPrayerIndex > 0 ? mainPrayers[nextPrayerIndex - 1] : nil
            
            return (
                PrayerData(name: next.name, arabicName: next.arabicName, time: next.time, isNext: true),
                previous
            )
        }
        
        // إذا انتهت جميع صلوات اليوم، الصلاة القادمة هي فجر الغد
        if let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: currentDate) {
            let tomorrowComps = Calendar.current.dateComponents([.year, .month, .day], from: tomorrow)
            if let tomorrowPrayers = PrayerTimes(coordinates: coordinates, date: tomorrowComps, calculationParameters: params) {
                return (
                    PrayerData(name: "Fajr", arabicName: "الفجر", time: tomorrowPrayers.fajr, isNext: true),
                    mainPrayers.last // العشاء هي الصلاة السابقة
                )
            }
        }
        
        return (nil, nil)
    }
    
    private func getHijriDate(from date: Date) -> String {
        let hijriCalendar = Calendar(identifier: .islamicUmmAlQura)
        let formatter = DateFormatter()
        formatter.calendar = hijriCalendar
        formatter.locale = Locale(identifier: "ar")
        formatter.dateFormat = "d MMMM yyyy"
        return formatter.string(from: date)
    }
}

// MARK: - Widget Views

struct PrayerTimeWidgetEntryView: View {
    var entry: PrayerTimeProvider.Entry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .accessoryRectangular:
            AccessoryRectangularView(entry: entry)
        case .accessoryInline:
            AccessoryInlineView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

// MARK: - Small Widget View
struct SmallWidgetView: View {
    let entry: PrayerTimeEntry
    
    var body: some View {
        ZStack {
            // الخلفية
            LinearGradient(
                colors: [Color(hex: "1A3A2F"), Color(hex: "0D1F17")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            VStack(spacing: 8) {
                // العنوان
                HStack {
                    Image(systemName: "moon.stars.fill")
                        .font(.caption)
                        .foregroundColor(Color(hex: "D4AF37"))
                    Text("الصلاة القادمة")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.7))
                    Spacer()
                }
                
                if let nextPrayer = entry.nextPrayer {
                    // اسم الصلاة
                    Text(nextPrayer.arabicName)
                        .font(.title2.bold())
                        .foregroundColor(.white)
                    
                    // الوقت المتبقي
                    Text(timeRemainingText(to: nextPrayer.time, from: entry.date))
                        .font(.headline)
                        .foregroundColor(Color(hex: "43AA8B"))
                    
                    // وقت الصلاة
                    Text(formatTime(nextPrayer.time))
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                } else {
                    Text("جاري التحميل...")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            .padding()
        }
    }
}

// MARK: - Medium Widget View
struct MediumWidgetView: View {
    let entry: PrayerTimeEntry
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "1A3A2F"), Color(hex: "0D1F17")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            HStack(spacing: 16) {
                // القسم الأيسر - الصلاة القادمة
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "moon.stars.fill")
                            .foregroundColor(Color(hex: "D4AF37"))
                        Text("الصلاة القادمة")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    if let nextPrayer = entry.nextPrayer {
                        Text(nextPrayer.arabicName)
                            .font(.title.bold())
                            .foregroundColor(.white)
                        
                        // العد التنازلي أو التصاعدي
                        VStack(alignment: .leading, spacing: 2) {
                            Text(timeRemainingText(to: nextPrayer.time, from: entry.date))
                                .font(.headline)
                                .foregroundColor(Color(hex: "43AA8B"))
                            
                            Text(formatTime(nextPrayer.time))
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.6))
                        }
                        
                        // إذا مضى وقت على الأذان
                        if let previous = entry.previousPrayer, entry.date > previous.time {
                            let elapsed = entry.date.timeIntervalSince(previous.time)
                            if elapsed < 3600 { // أقل من ساعة
                                Text("مضى على \(previous.arabicName): \(formatElapsedTime(elapsed))")
                                    .font(.caption2)
                                    .foregroundColor(Color(hex: "FF6B6B"))
                            }
                        }
                    }
                }
                
                Spacer()
                
                // القسم الأيمن - معلومات إضافية
                VStack(alignment: .trailing, spacing: 8) {
                    Text(entry.locationName)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                    
                    Text(entry.hijriDate)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.5))
                    
                    Spacer()
                    
                    // أيقونة الكعبة
                    Image(systemName: "building.columns.fill")
                        .font(.title2)
                        .foregroundColor(Color(hex: "D4AF37").opacity(0.5))
                }
            }
            .padding()
        }
    }
}

// MARK: - Accessory Views (Lock Screen)
struct AccessoryRectangularView: View {
    let entry: PrayerTimeEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let nextPrayer = entry.nextPrayer {
                HStack {
                    Image(systemName: "moon.fill")
                    Text(nextPrayer.arabicName)
                        .font(.headline)
                }
                
                Text(timeRemainingText(to: nextPrayer.time, from: entry.date))
                    .font(.caption)
                
                Text(formatTime(nextPrayer.time))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct AccessoryInlineView: View {
    let entry: PrayerTimeEntry
    
    var body: some View {
        if let nextPrayer = entry.nextPrayer {
            Text("\(nextPrayer.arabicName) - \(timeRemainingText(to: nextPrayer.time, from: entry.date))")
        } else {
            Text("مواقيت الصلاة")
        }
    }
}

// MARK: - Helper Functions

func timeRemainingText(to targetDate: Date, from currentDate: Date) -> String {
    let interval = targetDate.timeIntervalSince(currentDate)
    
    if interval <= 0 {
        // الوقت مضى - عرض "حان الوقت" أو العد التصاعدي
        let elapsed = abs(interval)
        if elapsed < 60 {
            return "حان الآن"
        } else if elapsed < 3600 {
            let minutes = Int(elapsed / 60)
            return "مضى \(minutes) د"
        }
        return "مضى الوقت"
    }
    
    let hours = Int(interval / 3600)
    let minutes = Int((interval.truncatingRemainder(dividingBy: 3600)) / 60)
    
    if hours > 0 {
        if minutes > 0 {
            return "باقي \(hours) س \(minutes) د"
        }
        return "باقي \(hours) ساعة"
    } else if minutes > 0 {
        return "باقي \(minutes) دقيقة"
    } else {
        let seconds = Int(interval)
        return "باقي \(seconds) ثانية"
    }
}

func formatElapsedTime(_ interval: TimeInterval) -> String {
    let minutes = Int(interval / 60)
    if minutes < 60 {
        return "\(minutes) د"
    }
    let hours = minutes / 60
    let remainingMinutes = minutes % 60
    return "\(hours) س \(remainingMinutes) د"
}

func formatTime(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "h:mm a"
    formatter.locale = Locale(identifier: "ar")
    return formatter.string(from: date)
}

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Widget Configuration
struct PrayerTimeWidget: Widget {
    let kind: String = "PrayerTimeWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PrayerTimeProvider()) { entry in
            PrayerTimeWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("مواقيت الصلاة")
        .description("يعرض الوقت المتبقي للصلاة القادمة")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline])
    }
}

// MARK: - Preview
#Preview(as: .systemSmall) {
    PrayerTimeWidget()
} timeline: {
    PrayerTimeEntry(
        date: .now,
        nextPrayer: PrayerData(name: "Dhuhr", arabicName: "الظهر", time: .now.addingTimeInterval(3600), isNext: true),
        previousPrayer: PrayerData(name: "Fajr", arabicName: "الفجر", time: .now.addingTimeInterval(-7200), isNext: false),
        allPrayers: [],
        locationName: "الرياض",
        hijriDate: "٢٣ جمادى الآخرة ١٤٤٦",
        state: .loaded
    )
}

#Preview(as: .systemMedium) {
    PrayerTimeWidget()
} timeline: {
    PrayerTimeEntry(
        date: .now,
        nextPrayer: PrayerData(name: "Asr", arabicName: "العصر", time: .now.addingTimeInterval(5400), isNext: true),
        previousPrayer: PrayerData(name: "Dhuhr", arabicName: "الظهر", time: .now.addingTimeInterval(-1800), isNext: false),
        allPrayers: [],
        locationName: "الرياض",
        hijriDate: "٢٣ جمادى الآخرة ١٤٤٦",
        state: .loaded
    )
}
