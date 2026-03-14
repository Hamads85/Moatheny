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
        case .systemLarge:
            LargeWidgetView(entry: entry)
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
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                Text(entry.locationName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
                Image(systemName: "location.fill")
                    .font(.system(size: 7))
                    .foregroundColor(Color(hex: "D4AF37"))
                Spacer()
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "D4AF37").opacity(0.5))
            }
            
            Text(entry.hijriDate)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.white.opacity(0.35))
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.top, 1)
            
            Spacer()
            
            if let nextPrayer = entry.nextPrayer {
                Text(nextPrayer.arabicName)
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundColor(Color(hex: "D4AF37"))
                    .minimumScaleFactor(0.7)
                    .shadow(color: Color(hex: "D4AF37").opacity(0.2), radius: 6)
                
                Text(timeRemainingText(to: nextPrayer.time, from: entry.date))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.top, 3)
                
                Text(formatTime(nextPrayer.time))
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.4))
                    .padding(.top, 1)
            } else {
                Text("جاري التحميل...")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.5))
            }
            
            Spacer()
        }
        .environment(\.layoutDirection, .rightToLeft)
    }
}

// MARK: - Medium Widget View
struct MediumWidgetView: View {
    let entry: PrayerTimeEntry
    
    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 4) {
                    Text("الصلاة القادمة")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.45))
                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 9))
                        .foregroundColor(Color(hex: "D4AF37").opacity(0.6))
                }
                
                Spacer()
                
                if let nextPrayer = entry.nextPrayer {
                    Text(nextPrayer.arabicName)
                        .font(.system(size: 32, weight: .heavy, design: .rounded))
                        .foregroundColor(Color(hex: "D4AF37"))
                        .minimumScaleFactor(0.7)
                        .shadow(color: Color(hex: "D4AF37").opacity(0.2), radius: 6)
                    
                    Text(timeRemainingText(to: nextPrayer.time, from: entry.date))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.top, 1)
                    
                    Text(formatTime(nextPrayer.time))
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.45))
                        .padding(.top, 1)
                }
                
                Spacer()
            }
            .frame(maxWidth: .infinity)
            
            Rectangle()
                .fill(Color(hex: "D4AF37").opacity(0.15))
                .frame(width: 0.5)
                .padding(.vertical, 8)
            
            VStack(alignment: .leading, spacing: 6) {
                Text("الموقع الحالي")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.white.opacity(0.35))
                
                HStack(spacing: 3) {
                    Text(entry.locationName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                    Image(systemName: "location.fill")
                        .font(.system(size: 7))
                        .foregroundColor(Color(hex: "D4AF37"))
                }
                
                Text(entry.hijriDate)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.35))
                
                Spacer()
                
                if let previous = entry.previousPrayer {
                    let elapsed = entry.date.timeIntervalSince(previous.time)
                    if elapsed > 0 && elapsed < 3600 {
                        Text("مضى على \(previous.arabicName)")
                            .font(.system(size: 9))
                            .foregroundColor(.white.opacity(0.3))
                        Text(formatElapsedTime(elapsed))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white.opacity(0.4))
                    }
                }
                
                HStack {
                    Spacer()
                    Image(systemName: "building.columns.fill")
                        .font(.system(size: 20))
                        .foregroundColor(Color(hex: "D4AF37").opacity(0.12))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.leading, 12)
        }
        .environment(\.layoutDirection, .rightToLeft)
    }
}

// MARK: - Large Widget View
struct LargeWidgetView: View {
    let entry: PrayerTimeEntry
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                HStack(spacing: 4) {
                    Text(entry.locationName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                    Image(systemName: "location.fill")
                        .font(.system(size: 8))
                        .foregroundColor(Color(hex: "D4AF37"))
                }
                Spacer()
                Text(entry.hijriDate)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.35))
            }
            .padding(.bottom, 14)
            
            if let nextPrayer = entry.nextPrayer {
                HStack {
                    VStack(alignment: .trailing, spacing: 3) {
                        Text("الصلاة القادمة")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white.opacity(0.4))
                        Text(nextPrayer.arabicName)
                            .font(.system(size: 26, weight: .heavy, design: .rounded))
                            .foregroundColor(Color(hex: "D4AF37"))
                            .shadow(color: Color(hex: "D4AF37").opacity(0.15), radius: 4)
                    }
                    Spacer()
                    VStack(alignment: .leading, spacing: 3) {
                        Text(timeRemainingText(to: nextPrayer.time, from: entry.date))
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text(formatTime(nextPrayer.time))
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.45))
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color(hex: "D4AF37").opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color(hex: "D4AF37").opacity(0.12), lineWidth: 0.5)
                        )
                )
                .padding(.bottom, 14)
            }
            
            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(height: 0.5)
                .padding(.bottom, 6)
            
            VStack(spacing: 0) {
                ForEach(Array(entry.allPrayers.enumerated()), id: \.offset) { index, prayer in
                    let isNext = entry.nextPrayer?.name == prayer.name
                    
                    HStack {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(isNext ? Color(hex: "D4AF37") : .white.opacity(0.15))
                                .frame(width: 5, height: 5)
                            Text(prayer.arabicName)
                                .font(.system(size: 15, weight: isNext ? .bold : .regular))
                                .foregroundColor(isNext ? Color(hex: "D4AF37") : .white.opacity(0.65))
                        }
                        
                        Spacer()
                        
                        Text(formatTime(prayer.time))
                            .font(.system(size: 15, weight: isNext ? .bold : .regular, design: .rounded))
                            .foregroundColor(isNext ? .white : .white.opacity(0.4))
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(isNext ? Color(hex: "D4AF37").opacity(0.05) : .clear)
                    )
                    
                    if index < entry.allPrayers.count - 1 {
                        Rectangle()
                            .fill(.white.opacity(0.04))
                            .frame(height: 0.5)
                            .padding(.horizontal, 10)
                    }
                }
            }
            
            Spacer()
        }
        .environment(\.layoutDirection, .rightToLeft)
    }
}

// MARK: - Accessory Views (Lock Screen)
struct AccessoryRectangularView: View {
    let entry: PrayerTimeEntry
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            if let nextPrayer = entry.nextPrayer {
                HStack(spacing: 4) {
                    Text(nextPrayer.arabicName)
                        .font(.system(size: 15, weight: .bold))
                    Image(systemName: "moon.fill")
                        .font(.system(size: 10))
                }
                
                Text(timeRemainingText(to: nextPrayer.time, from: entry.date))
                    .font(.system(size: 12, weight: .medium))
                
                Text(formatTime(nextPrayer.time))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .environment(\.layoutDirection, .rightToLeft)
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
                .containerBackground(for: .widget) {
                    LinearGradient(
                        colors: [Color(hex: "0D1B2A"), Color(hex: "1B2838")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
        }
        .configurationDisplayName("مواقيت الصلاة")
        .description("يعرض الوقت المتبقي للصلاة القادمة")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular, .accessoryInline])
    }
}

// MARK: - Previews
#Preview(as: .systemSmall) {
    PrayerTimeWidget()
} timeline: {
    PrayerTimeEntry(
        date: .now,
        nextPrayer: PrayerData(name: "Dhuhr", arabicName: "الظهر", time: .now.addingTimeInterval(3600), isNext: true),
        previousPrayer: PrayerData(name: "Fajr", arabicName: "الفجر", time: .now.addingTimeInterval(-7200), isNext: false),
        allPrayers: [
            PrayerData(name: "Fajr", arabicName: "الفجر", time: .now.addingTimeInterval(-7200), isNext: false),
            PrayerData(name: "Sunrise", arabicName: "الشروق", time: .now.addingTimeInterval(-5400), isNext: false),
            PrayerData(name: "Dhuhr", arabicName: "الظهر", time: .now.addingTimeInterval(3600), isNext: true),
            PrayerData(name: "Asr", arabicName: "العصر", time: .now.addingTimeInterval(10800), isNext: false),
            PrayerData(name: "Maghrib", arabicName: "المغرب", time: .now.addingTimeInterval(18000), isNext: false),
            PrayerData(name: "Isha", arabicName: "العشاء", time: .now.addingTimeInterval(21600), isNext: false)
        ],
        locationName: "الرياض",
        hijriDate: "٢٥ رمضان ١٤٤٧",
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
        hijriDate: "٢٥ رمضان ١٤٤٧",
        state: .loaded
    )
}

#Preview(as: .systemLarge) {
    PrayerTimeWidget()
} timeline: {
    PrayerTimeEntry(
        date: .now,
        nextPrayer: PrayerData(name: "Dhuhr", arabicName: "الظهر", time: .now.addingTimeInterval(3600), isNext: true),
        previousPrayer: PrayerData(name: "Fajr", arabicName: "الفجر", time: .now.addingTimeInterval(-7200), isNext: false),
        allPrayers: [
            PrayerData(name: "Fajr", arabicName: "الفجر", time: .now.addingTimeInterval(-7200), isNext: false),
            PrayerData(name: "Sunrise", arabicName: "الشروق", time: .now.addingTimeInterval(-5400), isNext: false),
            PrayerData(name: "Dhuhr", arabicName: "الظهر", time: .now.addingTimeInterval(3600), isNext: true),
            PrayerData(name: "Asr", arabicName: "العصر", time: .now.addingTimeInterval(10800), isNext: false),
            PrayerData(name: "Maghrib", arabicName: "المغرب", time: .now.addingTimeInterval(18000), isNext: false),
            PrayerData(name: "Isha", arabicName: "العشاء", time: .now.addingTimeInterval(21600), isNext: false)
        ],
        locationName: "الرياض",
        hijriDate: "٢٥ رمضان ١٤٤٧",
        state: .loaded
    )
}
