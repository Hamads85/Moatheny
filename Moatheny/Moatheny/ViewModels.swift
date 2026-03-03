import Foundation
import SwiftUI
import Combine

@MainActor
final class PrayerTimesViewModel: ObservableObject {
    @Published var day: PrayerDay?
    @Published var error: String?
    @Published var isLoading = false

    private let service: PrayerTimeService
    init(service: PrayerTimeService) { self.service = service }

    func refresh(method: CalculationMethod = .ummAlQura) async {
        isLoading = true
        do {
            day = try await service.loadPrayerTimes(method: method)
        } catch {
            self.error = error.localizedDescription
            self.day = service.cached()
        }
        isLoading = false
    }
}

@MainActor
final class QuranViewModel: ObservableObject {
    @Published var surahs: [Surah] = []
    @Published var reciters: [Reciter] = []
    @Published var error: String?
    @Published var isLoading = false

    private let service: QuranService
    init(service: QuranService) { self.service = service }

    func load() async {
        isLoading = true
        do {
            async let s = service.loadQuran()
            async let r = service.loadReciters()
            surahs = try await s
            reciters = try await r
        } catch { self.error = error.localizedDescription }
        isLoading = false
    }
}

@MainActor
final class AzkarViewModel: ObservableObject {
    @Published var azkarByCategory: [AzkarCategory: [Zikr]] = [:]
    @Published var error: String?
    @Published var isLoading = false
    private let service: AzkarService
    init(service: AzkarService) { self.service = service }

    func load(forceRefresh: Bool = false) async {
        // السماح بإعادة التحميل إذا كان forceRefresh أو البيانات فارغة
        guard forceRefresh || azkarByCategory.isEmpty else { return }
        isLoading = true
        error = nil
        do {
            let azkar = try await service.loadAzkar()
            azkarByCategory = Dictionary(grouping: azkar, by: { $0.category })
            if azkarByCategory.isEmpty {
                self.error = "لا توجد أذكار"
            }
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
    
    func forceReload() async {
        azkarByCategory = [:]
        await load()
    }
}

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var adhanEnabled = true
    @Published var selectedMethod: CalculationMethod = .ummAlQura
    
    // إعدادات التنبيهات (بخطوات 5 دقائق)
    @Published var preAdhanMinutes: Int = 10 { didSet { applyNotificationSettingsIfNeeded() } }
    @Published var adhanOffsetMinutes: Int = 0 { didSet { applyNotificationSettingsIfNeeded() } }
    @Published var iqamaDelayMinutes: Int = 15 { didSet { applyNotificationSettingsIfNeeded() } }
    @Published var iqamaEnabled: Bool = true { didSet { applyNotificationSettingsIfNeeded() } }

    private let notifications: NotificationService
    private let audio: AudioPlayerService
    private let prayerService: PrayerTimeService
    
    /// يمنع recursion: apply() قد يعيد تعيين نفس الـ @Published (clamp) وبالتالي يعيد استدعاء didSet بلا نهاية.
    private var isApplyingNotificationSettings = false

    init(notifications: NotificationService, audio: AudioPlayerService, prayerService: PrayerTimeService) {
        self.notifications = notifications
        self.audio = audio
        self.prayerService = prayerService
        
        // تحميل القيم الحالية من NotificationService
        isApplyingNotificationSettings = true
        self.adhanEnabled = notifications.isAdhanEnabled
        self.iqamaEnabled = notifications.isIqamaEnabled
        self.preAdhanMinutes = notifications.preAdhanMinutes
        self.adhanOffsetMinutes = notifications.adhanOffsetMinutes
        self.iqamaDelayMinutes = notifications.iqamaDelayMinutes
        isApplyingNotificationSettings = false
    }

    func requestNotificationPermission() { notifications.requestPermissions() }
    
    private func applyNotificationSettingsIfNeeded() {
        guard !isApplyingNotificationSettings else { return }
        applyNotificationSettings()
    }
    
    private func applyNotificationSettings() {
        guard !isApplyingNotificationSettings else { return }
        isApplyingNotificationSettings = true
        defer { isApplyingNotificationSettings = false }
        
        // ضبط الحدود (التغيير من UI يكون بخطوات 5 لكن نضمنها هنا أيضاً)
        let clampedPre = clampStep5(preAdhanMinutes, min: 5, max: 30)
        let clampedOffset = clampStep5(adhanOffsetMinutes, min: 0, max: 30)
        let clampedIqama = clampStep5(iqamaDelayMinutes, min: 5, max: 30)
        
        if preAdhanMinutes != clampedPre { preAdhanMinutes = clampedPre }
        if adhanOffsetMinutes != clampedOffset { adhanOffsetMinutes = clampedOffset }
        if iqamaDelayMinutes != clampedIqama { iqamaDelayMinutes = clampedIqama }
        
        notifications.isAdhanEnabled = adhanEnabled
        notifications.isIqamaEnabled = iqamaEnabled
        notifications.preAdhanMinutes = preAdhanMinutes
        notifications.adhanOffsetMinutes = adhanOffsetMinutes
        notifications.iqamaDelayMinutes = iqamaDelayMinutes
        
        // إعادة جدولة إشعارات اليوم (إن وجدت بيانات)
        if let day = prayerService.cached() {
            notifications.scheduleAllPrayers(day.prayers)
        }
    }
    
    private func clampStep5(_ value: Int, min: Int, max: Int) -> Int {
        let clamped = Swift.max(min, Swift.min(max, value))
        // تقريب لأقرب مضاعف 5
        let rounded = Int((Double(clamped) / 5.0).rounded()) * 5
        return Swift.max(min, Swift.min(max, rounded))
    }
}

