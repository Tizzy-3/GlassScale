import Foundation

/// 落盘到 Application Support/GlassScale/store.json。
///
/// 纯本地存储：没有账号、没有网络、没有第三方依赖。
enum Persistence {
    enum RecoveryError: LocalizedError {
        case missingPrimary
        var errorDescription: String? {
            "主数据文件缺失，但检测到自动备份。请先恢复备份，避免覆盖历史数据。"
        }
    }
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

    /// 本机数据目录；目录创建失败会在实际保存时报告。
    private static var folderURL: URL {
        // 不能退回临时目录：目录不可用时须报告错误，避免文件随后被清理。
        URL.applicationSupportDirectory.appendingPathComponent(folderName, isDirectory: true)
    }

    static var fileURL: URL { folderURL.appendingPathComponent(fileName) }

    /// 头像单独存一个文件，不进 JSON（图片 base64 会撑大 store.json）
    static var avatarURL: URL { folderURL.appendingPathComponent("avatar.jpg") }

    static func load(from url: URL = fileURL) throws -> Payload? {
        guard FileManager.default.fileExists(atPath: url.path) else {
            let backup = backupURL(for: url)
            if backup != url, FileManager.default.fileExists(atPath: backup.path) {
                throw RecoveryError.missingPrimary
            }
            return nil
        }
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Payload.self, from: data)
    }

    static func backupURL(for url: URL = fileURL) -> URL {
        url.deletingLastPathComponent().appendingPathComponent("store.backup.json")
    }

    static func loadBackup(for url: URL = fileURL) throws -> Payload? {
        try load(from: backupURL(for: url))
    }

    static func save(_ payload: Payload, to url: URL = fileURL, allowReplacingUnreadable: Bool = false) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(payload)
        let folder = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        if !FileManager.default.fileExists(atPath: url.path),
           FileManager.default.fileExists(atPath: backupURL(for: url).path),
           !allowReplacingUnreadable {
            throw RecoveryError.missingPrimary
        }
        if FileManager.default.fileExists(atPath: url.path) {
            do {
                _ = try load(from: url)
            } catch {
                guard allowReplacingUnreadable else { throw error }
                // 恢复须显式触发；先保留无法读取的原文件，不能静默覆盖。
                let preserved = folder.appendingPathComponent("store.unreadable-\(UUID().uuidString).json")
                try FileManager.default.copyItem(at: url, to: preserved)
            }
            if (try? load(from: url)) != nil {
                try Data(contentsOf: url).write(to: backupURL(for: url), options: .atomic)
            }
        } else if !FileManager.default.fileExists(atPath: backupURL(for: url).path) {
            try data.write(to: backupURL(for: url), options: .atomic)
        }
        try data.write(to: url, options: .atomic)
    }

    static func wipe() {
        try? FileManager.default.removeItem(at: fileURL)
        try? FileManager.default.removeItem(at: avatarURL)
    }
}
