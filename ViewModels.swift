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

    func load() async {
        isLoading = true
        do {
            let azkar = try await service.loadAzkar()
            azkarByCategory = Dictionary(grouping: azkar, by: { $0.category })
        } catch { self.error = error.localizedDescription }
        isLoading = false
    }
}

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var adhanEnabled = true
    @Published var selectedMethod: CalculationMethod = .ummAlQura

    private let notifications: NotificationService
    private let audio: AudioPlayerService
    private let prayerService: PrayerTimeService

    init(notifications: NotificationService, audio: AudioPlayerService, prayerService: PrayerTimeService) {
        self.notifications = notifications
        self.audio = audio
        self.prayerService = prayerService
    }

    func requestNotificationPermission() { notifications.requestPermissions() }
}

