import Foundation
import Combine

/// Manages downloading audio for offline playback.
final class DownloadManager: ObservableObject {
    @Published var progress: [String: Double] = [:]

    func download(surah: Surah, reciter: Reciter) async {
        for (idx, ayah) in surah.ayahs.enumerated() {
            guard let url = ayah.audioURL else { continue }
            do {
                let (tmp, _) = try await URLSession.shared.download(from: url)
                let dest = FilePaths.cached("\(surah.id)-\(idx)-\(reciter.id).mp3")
                try? FileManager.default.removeItem(at: dest)
                try FileManager.default.moveItem(at: tmp, to: dest)
                progress["\(surah.id)-\(reciter.id)"] = Double(idx + 1) / Double(surah.ayahs.count)
            } catch {
                // Continue other ayahs on error.
                continue
            }
        }
    }
}

