
import Foundation
import Combine

/// Manages downloading audio for offline playback.
///
/// Improvements:
/// - Runs UI state updates on the Main Actor.
/// - Supports cancellation.
/// - Uses atomic replacement when possible.
/// - Allows dependency injection for testability.
/// - Skips already-downloaded files.
@MainActor
final class DownloadManager: ObservableObject {
    /// Download progress keyed by "<surahId>-<reciterId>".
    @Published private(set) var progress: [String: Double] = [:]

    private let session: URLSession
    private let fileManager: FileManager

    init(session: URLSession = .shared, fileManager: FileManager = .default) {
        self.session = session
        self.fileManager = fileManager
    }

    /// Downloads all ayah audio files for a given surah/reciter.
    /// Progress is updated incrementally per ayah.
    ///
    /// Notes:
    /// - This function is cancellable (Task cancellation stops work).
    /// - Errors in individual ayahs are tolerated; the download continues.
    func download(surah: Surah, reciter: Reciter) async {
        let key = progressKey(surahID: surah.id, reciterID: reciter.id)
        let total = max(surah.ayahs.count, 1)

        // Initialize progress at the start so the UI can reflect "in progress".
        progress[key] = 0

        for (idx, ayah) in surah.ayahs.enumerated() {
            // Respect cancellation promptly.
            if Task.isCancelled { break }

            guard let url = ayah.audioURL else {
                updateProgress(key: key, completed: idx + 1, total: total)
                continue
            }

            let dest = destinationURL(surahID: surah.id, ayahIndex: idx, reciterID: reciter.id)

            // Skip if already downloaded (fast path).
            if fileManager.fileExists(atPath: dest.path) {
                updateProgress(key: key, completed: idx + 1, total: total)
                continue
            }

            do {
                try ensureParentDirectoryExists(for: dest)
                try await downloadFile(from: url, to: dest)
            } catch {
                // Intentionally continue other ayahs on failure.
                // Consider collecting errors if you want to present a summary to users.
            }

            updateProgress(key: key, completed: idx + 1, total: total)
        }
    }

    // MARK: - Internals

    private func progressKey(surahID: Int, reciterID: Int) -> String {
        "\(surahID)-\(reciterID)"
    }

    private func destinationURL(surahID: Int, ayahIndex: Int, reciterID: Int) -> URL {
        FilePaths.cached("\(surahID)-\(ayahIndex)-\(reciterID).mp3")
    }

    private func updateProgress(key: String, completed: Int, total: Int) {
        progress[key] = Double(completed) / Double(total)
    }

    private func ensureParentDirectoryExists(for url: URL) throws {
        let dir = url.deletingLastPathComponent()
        var isDir: ObjCBool = false
        if !fileManager.fileExists(atPath: dir.path, isDirectory: &isDir) {
            try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }

    private func downloadFile(from remoteURL: URL, to destinationURL: URL) async throws {
        // Use URLSession download for large files; it streams to disk.
        let (tmp, _) = try await session.download(from: remoteURL)

        // Prefer atomic replacement when destination exists.
        // If it doesn't exist, a move is effectively atomic on the same volume.
        if fileManager.fileExists(atPath: destinationURL.path) {
            _ = try fileManager.replaceItemAt(destinationURL, withItemAt: tmp)
        } else {
            // Clean up any stale tmp destination if needed.
            try? fileManager.removeItem(at: destinationURL)
            try fileManager.moveItem(at: tmp, to: destinationURL)
        }
    }
}

