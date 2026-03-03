import Foundation
import SwiftUI

enum AppError: LocalizedError {
    case network(String)
    case decoding(String)
    case file(String)
    case permission(String)
    case generic(String)

    var errorDescription: String? {
        switch self {
        case .network(let m), .decoding(let m), .file(let m), .permission(let m), .generic(let m):
            return m
        }
    }
}

extension Date {
    func formattedTime() -> String {
        let f = DateFormatter()
        f.timeStyle = .short
        return f.string(from: self)
    }
}

extension Bundle {
    func loadJSON<T: Decodable>(_ name: String, as type: T.Type) throws -> T {
        guard let url = url(forResource: name, withExtension: "json") else {
            throw AppError.file("Missing bundled file: \(name).json")
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(T.self, from: data)
    }
}

struct FilePaths {
    static let cacheDir: URL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
    static func cached(_ name: String) -> URL { cacheDir.appendingPathComponent(name) }
}

