import Foundation
import SwiftSoup

/// Example scraper using SwiftSoup for azkar fallback.
final class WebScraper {
    func scrapeAzkar(from url: URL) async throws -> [Zikr] {
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let html = String(data: data, encoding: .utf8) else {
            throw AppError.decoding("Invalid HTML")
        }
        let doc = try SwiftSoup.parse(html)
        let items = try doc.select(".zikr-item")
        return try items.enumerated().map { idx, el in
            Zikr(
                id: idx,
                category: .morning,
                arabicText: try el.select(".arabic").text(),
                transliteration: nil,
                translation: try el.select(".translation").text(),
                reference: try? el.select(".ref").text(),
                repetitionCount: Int(try el.select(".count").text()) ?? 1,
                benefit: nil,
                audioURL: nil
            )
        }
    }
}

