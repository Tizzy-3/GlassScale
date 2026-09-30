import Foundation

/// 落盘到 Application Support/GlassScale/store.json。
///
/// 纯本地存储：没有账号、没有网络、没有第三方依赖。
enum Persistence {
    struct Payload: Codable {
        var entries: [WeightEntry] = []
        var profile: BodyProfile = BodyProfile()
        var goal: WeightGoal? = nil
        var settings: AppSettings = AppSettings()
    }

    private static let fileName = "store.json"
    private static let folderName = "GlassScale"

    /// 用于 iCloud / 文件 App 备份的文件夹（Application Support 默认不参与备份的用户偏好区）
    private static var folderURL: URL {
        let base = (try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? FileManager.default.temporaryDirectory

        let folder = base.appendingPathComponent(folderName, isDirectory: true)
        if !FileManager.default.fileExists(atPath: folder.path) {
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        return folder
    }

    static var fileURL: URL { folderURL.appendingPathComponent(fileName) }

    /// 头像单独存一个文件，不进 JSON（图片 base64 会撑大 store.json）
    static var avatarURL: URL { folderURL.appendingPathComponent("avatar.jpg") }

    static func load() -> Payload? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(Payload.self, from: data)
    }

    static func save(_ payload: Payload) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(payload) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    static func wipe() {
        try? FileManager.default.removeItem(at: fileURL)
        try? FileManager.default.removeItem(at: avatarURL)
    }
}
