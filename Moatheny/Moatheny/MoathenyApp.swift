import SwiftUI
import Combine
import CoreLocation
import WidgetKit
import BackgroundTasks

@main
struct MoathenyApp: App {
    @StateObject private var container = AppContainer()
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.scenePhase) var scenePhase

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(container)
                .environmentObject(container.cityStore)
                .environmentObject(container.prayerVM)
                .environmentObject(container.quranVM)
                .environmentObject(container.azkarVM)
                .environmentObject(container.settingsVM)
                .environmentObject(container.audio)
                .environmentObject(container.mp3Quran)
                .environment(\.layoutDirection, .rightToLeft) // RTL للتطبيق بالكامل
                .onAppear {
                    // طلب الأذونات تلقائياً عند بدء التطبيق
                    container.requestAllPermissions()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        // تحديث الودجت عند فتح التطبيق
                        WidgetCenter.shared.reloadAllTimelines()
                    } else if newPhase == .background {
                        // جدولة التحديث في الخلفية
                        container.scheduleAppRefresh()
                    }
                }
        }
    }
}

// MARK: - App Delegate للتعامل مع الإشعارات في الخلفية
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // لا نستخدم APNs حالياً (التطبيق يعتمد على Local Notifications).
        return true
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        print("✅ تم التسجيل للإشعارات البعيدة")
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("⚠️ فشل التسجيل للإشعارات البعيدة: \(error.localizedDescription)")
    }
}

/// Dependency injection container for shared services and view models.
final class AppContainer: ObservableObject {
    // ObservableObject automatically synthesizes objectWillChange, no need to declare explicitly
    
    let api = APIClient()
    let cache = LocalCache()
    let location = LocationService()
    lazy var cityStore = CityStore(location: location)
    let audio = AudioPlayerService()
    let notifications = NotificationService()
    let downloadManager = DownloadManager()
    let scraper = WebScraper()
    lazy var qibla = QiblaService(cache: cache)
    let hijri = HijriService()
    let compass = CompassService()
    let mp3Quran = MP3QuranService() // خدمة القراء الصوتيين من mp3quran.net

    lazy var prayerService = PrayerTimeService(api: api, cache: cache, location: location, cityStore: cityStore, hijri: hijri, notifications: notifications)
    lazy var quranService = QuranService(api: api, cache: cache, downloadManager: downloadManager, audio: audio)
    lazy var azkarService = AzkarService(api: api, cache: cache, notifications: notifications, scraper: scraper)

    lazy var prayerVM = PrayerTimesViewModel(service: prayerService)
    lazy var quranVM = QuranViewModel(service: quranService)
    lazy var azkarVM = AzkarViewModel(service: azkarService)
    lazy var settingsVM = SettingsViewModel(notifications: notifications, audio: audio, prayerService: prayerService)
    
    init() {
        // تسجيل مهام الخلفية
        registerBackgroundTasks()
        
        // بدء تحميل البيانات تلقائياً
        setupAutoRefresh()
    }
    
    private func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.YourMangaApp.Moatheny.refresh", using: nil) { task in
            self.handleAppRefresh(task: task as! BGAppRefreshTask)
        }
    }
    
    func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: "com.YourMangaApp.Moatheny.refresh")
        // التحديث بعد 6 ساعات على الأقل
        request.earliestBeginDate = Date(timeIntervalSinceNow: 6 * 60 * 60)
        
        do {
            try BGTaskScheduler.shared.submit(request)
            // print("✅ تم جدولة تحديث الخلفية")
        } catch {
            print("❌ فشل جدولة تحديث الخلفية: \(error)")
        }
    }
    
    private func handleAppRefresh(task: BGAppRefreshTask) {
        // جدولة التحديث القادم
        scheduleAppRefresh()
        
        // إنشاء عملية للتحديث
        let operation = Task {
            // تحديث أوقات الصلاة
            await prayerVM.refresh()
            
            // إعادة جدولة الإشعارات لضمان استمرارها
            if let day = prayerService.cached() {
                // نستخدم prayerService مباشرة لأنها تملك notifications
                // لكن prayerService private? لا، prayerService public (lazy var)
                // لكن نحتاج الوصول لـ notifications
                // prayerService.scheduleNotifications is private.
                // سنستخدم notifications مباشرة
                notifications.cancelPrayerNotificationsOnly()
                notifications.scheduleAllPrayers(day.prayers)
            }
            
            task.setTaskCompleted(success: true)
        }
        
        // معالجة انتهاء الوقت المخصص للمهمة
        task.expirationHandler = {
            operation.cancel()
        }
    }
    
    /// طلب جميع الأذونات تلقائياً
    func requestAllPermissions() {
        // طلب إذن الموقع
        location.request()
        
        // طلب إذن الإشعارات
        notifications.requestPermissions()
        
        // جدولة الدعاء اليومي
        notifications.scheduleDailyDua()
        
        // تحميل أوقات الصلاة تلقائياً بعد الحصول على الموقع
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            Task {
                await self?.prayerVM.refresh()
            }
        }
    }
    
    /// إعداد التحديث التلقائي
    private func setupAutoRefresh() {
        // مراقبة تغييرات الموقع وتحديث أوقات الصلاة تلقائياً (فقط عند استخدام GPS)
        location.$currentLocation
            .compactMap { $0 }
            .debounce(for: .seconds(1), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                guard self.cityStore.useCurrentLocation else { return }
                Task { await self.prayerVM.refresh() }
            }
            .store(in: &cancellables)
        
        // مراقبة تغيير مصدر المدينة (GPS/يدوي) أو المدينة المختارة، وتحديث البيانات فوراً
        cityStore.$useCurrentLocation
            .removeDuplicates()
            .sink { [weak self] _ in
                Task { await self?.prayerVM.refresh() }
            }
            .store(in: &cancellables)
        
        cityStore.$selectedCityId
            .removeDuplicates()
            .sink { [weak self] _ in
                Task { await self?.prayerVM.refresh() }
            }
            .store(in: &cancellables)
        
        // مراقبة تغيير حالة الإذن
        location.$authorizationStatus
            .sink { [weak self] status in
                if status == .authorizedWhenInUse || status == .authorizedAlways {
                    self?.location.startUpdating()
                }
            }
            .store(in: &cancellables)
    }
    
    private var cancellables = Set<AnyCancellable>()
}
