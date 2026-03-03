import Foundation

/// Handles Quran text, reciters, and audio download/playback.
final class QuranService {
    private let api: APIClient
    private let cache: LocalCache
    private let downloadManager: DownloadManager
    private let audio: AudioPlayerService

    init(api: APIClient, cache: LocalCache, downloadManager: DownloadManager, audio: AudioPlayerService) {
        self.api = api
        self.cache = cache
        self.downloadManager = downloadManager
        self.audio = audio
    }

    func loadQuran() async throws -> [Surah] {
        if let cached: [Surah] = try? cache.load([Surah].self, named: "quran.json") {
            return cached
        }
        let surahs = try await api.fetchQuran()
        try? cache.store(surahs, named: "quran.json")
        return surahs
    }

    func loadReciters() async throws -> [Reciter] {
        if let cached: [Reciter] = try? cache.load([Reciter].self, named: "reciters.json") {
            return cached
        }
        let reciters = try await api.fetchReciters()
        try? cache.store(reciters, named: "reciters.json")
        return reciters
    }

    func play(ayah: Ayah, reciter: Reciter) {
        // If ayah has explicit audio URL use it, otherwise fallback to reciter base URL.
        audio.play(url: ayah.audioURL ?? reciter.baseURL, metadata: "Ayah \(ayah.numberInSurah)")
    }

    func downloadSurah(_ surah: Surah, reciter: Reciter) async {
        await downloadManager.download(surah: surah, reciter: reciter)
    }
}

