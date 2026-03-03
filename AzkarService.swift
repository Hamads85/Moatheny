import Foundation

/// Provides azkar data, caching, reminders, and scraping fallback.
final class AzkarService {
    private let api: APIClient
    private let cache: LocalCache
    private let notifications: NotificationService
    private let scraper: WebScraper

    init(api: APIClient, cache: LocalCache, notifications: NotificationService, scraper: WebScraper) {
        self.api = api
        self.cache = cache
        self.notifications = notifications
        self.scraper = scraper
    }

    func loadAzkar() async throws -> [Zikr] {
        if let cached: [Zikr] = try? cache.load([Zikr].self, named: "azkar.json") {
            return cached
        }
        do {
            let azkar = try await api.fetchAzkar()
            try? cache.store(azkar, named: "azkar.json")
            return azkar
        } catch {
            // Scraping fallback (placeholder URL)
            let azkar = try await scraper.scrapeAzkar(from: URL(string: "https://example.com/azkar")!)
            try? cache.store(azkar, named: "azkar.json")
            return azkar
        }
    }

    func scheduleMorningEvening() {
        notifications.scheduleAzkarReminder(hour: 5, minute: 30, category: .morning)
        notifications.scheduleAzkarReminder(hour: 17, minute: 0, category: .evening)
    }
}

