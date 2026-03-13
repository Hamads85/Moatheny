import Foundation
import CoreLocation
import Adhan
import WidgetKit

/// Handles prayer time retrieval, calculation fallback, caching, and notifications.
final class PrayerTimeService {
    private let api: APIClient
    private let cache: LocalCache
    private let location: LocationService
    private let cityStore: CityStore
    private let hijri: HijriService
    private let notifications: NotificationService

    init(api: APIClient, cache: LocalCache, location: LocationService, cityStore: CityStore, hijri: HijriService, notifications: NotificationService) {
        self.api = api
        self.cache = cache
        self.location = location
        self.cityStore = cityStore
        self.hijri = hijri
        self.notifications = notifications
    }

    func loadPrayerTimes(method: CalculationMethod) async throws -> PrayerDay {
        guard let coord = cityStore.activeCoordinate else {
            throw AppError.permission("Location not available")
        }

        // Use Adhan library primarily for 100% accuracy and offline support
        let params = method.adhanParameters
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month, .day], from: Date())
        
        guard let times = PrayerTimes(coordinates: Coordinates(latitude: coord.latitude, longitude: coord.longitude),
                                      date: comps,
                                      calculationParameters: params) else {
            // Fallback to API if local calculation fails (unlikely)
            return try await loadPrayerTimesFromAPI(method: method, coord: coord)
        }
        
        let prayers = [
            Prayer(id: "fajr", name: "Fajr", arabicName: "الفجر", time: times.fajr),
            Prayer(id: "sunrise", name: "Sunrise", arabicName: "الشروق", time: times.sunrise),
            Prayer(id: "dhuhr", name: "Dhuhr", arabicName: "الظهر", time: times.dhuhr),
            Prayer(id: "asr", name: "Asr", arabicName: "العصر", time: times.asr),
            Prayer(id: "maghrib", name: "Maghrib", arabicName: "المغرب", time: times.maghrib),
            Prayer(id: "isha", name: "Isha", arabicName: "العشاء", time: times.isha)
        ]
        
        var day = PrayerDay(date: Date(), prayers: prayers)
        day.cityName = cityStore.activeCityName
        day.hijriDate = hijri.hijriString(for: day.date)
        
        try? cache.store(day, named: cacheFileName())
        savePrayerTimesToSharedDefaults(day)
        scheduleNotifications(for: day)
        
        return day
    }
    
    private func loadPrayerTimesFromAPI(method: CalculationMethod, coord: CLLocationCoordinate2D) async throws -> PrayerDay {
        var day = try await api.fetchPrayerTimes(lat: coord.latitude, lon: coord.longitude, method: method)
        day.cityName = cityStore.activeCityName
        day.hijriDate = hijri.hijriString(for: day.date)
        try? cache.store(day, named: cacheFileName())
        savePrayerTimesToSharedDefaults(day)
        scheduleNotifications(for: day)
        return day
    }
    
    private func savePrayerTimesToSharedDefaults(_ day: PrayerDay) {
        guard let sharedDefaults = UserDefaults(suiteName: "group.com.YourMangaApp.Moatheny") else { return }
        
        // حفظ أوقات الصلاة
        for prayer in day.prayers {
            sharedDefaults.set(prayer.time, forKey: "prayer_\(prayer.id)")
        }
        
        // حفظ تاريخ آخر تحديث
        sharedDefaults.set(Date(), forKey: "lastPrayerUpdate")
        sharedDefaults.synchronize()
        
        // تحديث الودجت فوراً
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func scheduleNotifications(for day: PrayerDay) {
        // نلغي إشعارات الصلاة السابقة فقط ثم نعيد جدولتها لهذا اليوم
        notifications.cancelPrayerNotificationsOnly()
        notifications.scheduleAllPrayers(day.prayers)
    }

    func cached() -> PrayerDay? {
        try? cache.load(PrayerDay.self, named: cacheFileName())
    }
    
    private func cacheFileName() -> String {
        "prayer_\(cityStore.activeCacheKey).json"
    }
}

