import Foundation
import CoreLocation
import Adhan

/// Handles prayer time retrieval, calculation fallback, caching, and notifications.
final class PrayerTimeService {
    private let api: APIClient
    private let cache: LocalCache
    private let location: LocationService
    private let notifications: NotificationService

    init(api: APIClient, cache: LocalCache, location: LocationService, notifications: NotificationService) {
        self.api = api
        self.cache = cache
        self.location = location
        self.notifications = notifications
    }

    func loadPrayerTimes(method: CalculationMethod) async throws -> PrayerDay {
        guard let loc = location.currentLocation else {
            throw AppError.permission("Location not available")
        }

        do {
            let day = try await api.fetchPrayerTimes(lat: loc.coordinate.latitude, lon: loc.coordinate.longitude, method: method)
            try? cache.store(day, named: "prayer.json")
            scheduleNotifications(for: day)
            return day
        } catch {
            // Local Adhan fallback
            let params = method.adhanParameters
            let comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
            guard let times = PrayerTimes(coordinates: Coordinates(latitude: loc.coordinate.latitude, longitude: loc.coordinate.longitude),
                                          date: comps,
                                          calculationParameters: params) else {
                throw AppError.generic("Failed to calculate local prayer times")
            }
            let prayers = [
                Prayer(id: "fajr", name: "Fajr", arabicName: "الفجر", time: times.fajr),
                Prayer(id: "sunrise", name: "Sunrise", arabicName: "الشروق", time: times.sunrise),
                Prayer(id: "dhuhr", name: "Dhuhr", arabicName: "الظهر", time: times.dhuhr),
                Prayer(id: "asr", name: "Asr", arabicName: "العصر", time: times.asr),
                Prayer(id: "maghrib", name: "Maghrib", arabicName: "المغرب", time: times.maghrib),
                Prayer(id: "isha", name: "Isha", arabicName: "العشاء", time: times.isha)
            ]
            let day = PrayerDay(date: Date(), prayers: prayers)
            try? cache.store(day, named: "prayer.json")
            scheduleNotifications(for: day)
            return day
        }
    }

    private func scheduleNotifications(for day: PrayerDay) {
        day.prayers.forEach { notifications.scheduleAdhan(for: $0) }
    }

    func cached() -> PrayerDay? {
        try? cache.load(PrayerDay.self, named: "prayer.json")
    }
}

