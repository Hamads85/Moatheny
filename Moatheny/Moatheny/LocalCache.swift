import Foundation

/// Simple JSON-based cache for offline support.
final class LocalCache {
    private let fm = FileManager.default
    private let queue = DispatchQueue(label: "LocalCache")

    func store<T: Encodable>(_ value: T, named: String) throws {
        let url = FilePaths.cached(named)
        let data = try JSONEncoder().encode(value)
        try data.write(to: url, options: .atomic)
    }

    func load<T: Decodable>(_ type: T.Type, named: String) throws -> T {
        let url = FilePaths.cached(named)
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(T.self, from: data)
    }

    func exists(_ named: String) -> Bool {
        fm.fileExists(atPath: FilePaths.cached(named).path)
    }
}

