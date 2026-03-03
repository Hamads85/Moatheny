import SwiftUI
import Combine

@main
struct MoathenyApp: App {
    @StateObject private var container = AppContainer()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(container)
                .environmentObject(container.prayerVM)
                .environmentObject(container.quranVM)
                .environmentObject(container.azkarVM)
                .environmentObject(container.settingsVM)
        }
    }
}

/// Dependency injection container for shared services and view models.
final class AppContainer: ObservableObject {
    // Explicit publisher to satisfy ObservableObject; trigger manually if container-level changes occur.
    let objectWillChange = ObservableObject.ObjectWillChangePublisher()

    let api = APIClient()
    let cache = LocalCache()
    let location = LocationService()
    let audio = AudioPlayerService()
    let notifications = NotificationService()
    let downloadManager = DownloadManager()
    let scraper = WebScraper()
    let qibla = QiblaService()
    let hijri = HijriService()

    lazy var prayerService = PrayerTimeService(api: api, cache: cache, location: location, notifications: notifications)
    lazy var quranService = QuranService(api: api, cache: cache, downloadManager: downloadManager, audio: audio)
    lazy var azkarService = AzkarService(api: api, cache: cache, notifications: notifications, scraper: scraper)

    lazy var prayerVM = PrayerTimesViewModel(service: prayerService)
    lazy var quranVM = QuranViewModel(service: quranService)
    lazy var azkarVM = AzkarViewModel(service: azkarService)
    lazy var settingsVM = SettingsViewModel(notifications: notifications, audio: audio, prayerService: prayerService)
}

