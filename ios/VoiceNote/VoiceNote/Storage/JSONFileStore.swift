import Foundation

/// 把 Codable 物件存成 Documents 底下的 JSON 檔。
enum JSONFileStore {
    static func url(for fileName: String) -> URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent(fileName)
    }

    static func load<T: Decodable>(_ type: T.Type, from fileName: String) -> T? {
        let url = url(for: fileName)
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(T.self, from: data)
    }

    static func save<T: Encodable>(_ value: T, to fileName: String) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(value) else { return }
        try? data.write(to: url(for: fileName), options: [.atomic])
    }
}
