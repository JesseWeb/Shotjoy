import Foundation

public enum ImageNaming {
    public static func fileName(
        date: Date = Date(),
        prefix: String = "ShotDesk",
        timeZone: TimeZone = .current
    ) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd HH.mm.ss"
        return "\(prefix) \(formatter.string(from: date)).png"
    }

    public static func uniqueURL(
        directory: URL,
        date: Date = Date(),
        prefix: String = "ShotDesk"
    ) -> URL {
        let base = fileName(date: date, prefix: prefix)
        var candidate = directory.appendingPathComponent(base)
        if !FileManager.default.fileExists(atPath: candidate.path) {
            return candidate
        }
        let stem = (base as NSString).deletingPathExtension
        let ext = (base as NSString).pathExtension
        for index in 2...999 {
            candidate = directory.appendingPathComponent("\(stem)-\(index).\(ext)")
            if !FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
        }
        return directory.appendingPathComponent("\(stem)-\(UUID().uuidString).\(ext)")
    }
}
