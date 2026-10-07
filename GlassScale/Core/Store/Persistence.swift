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
        /// 喝水记录（后加字段，老版本 JSON 里没有）
        var waterEntries: [WaterEntry] = []

        // 手写编解码：老版本 store.json 里没有 waterEntries 等新字段，
        // 用 decodeIfPresent 保证升级不丢数据。
        private enum CodingKeys: String, CodingKey {
            case entries, profile, goal, settings, waterEntries
        }

        init(
            entries: [WeightEntry] = [],
            profile: BodyProfile = BodyProfile(),
            goal: WeightGoal? = nil,
            settings: AppSettings = AppSettings(),
            waterEntries: [WaterEntry] = []
        ) {
            self.entries = entries
            self.profile = profile
            self.goal = goal
            self.settings = settings
            self.waterEntries = waterEntries
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            entries = try c.decodeIfPresent([WeightEntry].self, forKey: .entries) ?? []
            profile = try c.decodeIfPresent(BodyProfile.self, forKey: .profile) ?? BodyProfile()
            goal = try c.decodeIfPresent(WeightGoal.self, forKey: .goal)
            settings = try c.decodeIfPresent(AppSettings.self, forKey: .settings) ?? AppSettings()
            waterEntries = try c.decodeIfPresent([WaterEntry].self, forKey: .waterEntries) ?? []
        }

        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(entries, forKey: .entries)
            try c.encode(profile, forKey: .profile)
            try c.encodeIfPresent(goal, forKey: .goal)
            try c.encode(settings, forKey: .settings)
            try c.encode(waterEntries, forKey: .waterEntries)
        }
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
