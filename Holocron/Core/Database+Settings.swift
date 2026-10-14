import Foundation

// MARK: - Simple saved settings (settings.csv holds key,value rows)

extension Database {
    static let defaultClassName = "6AS"

    /// What is typed in Settings, which may be empty (the default name is then shown).
    var classNameSetting: String {
        rows(.settings).first(where: { $0.s("key") == "class_name" })?.s("value") ?? ""
    }

    /// The class name shown in the sidebar and on exported student summaries.
    var className: String {
        let v = rows(.settings).first(where: { $0.s("key") == "class_name" })?.s("value")
            .trimmingCharacters(in: .whitespaces) ?? ""
        return v.isEmpty ? Database.defaultClassName : v
    }

    func setClassName(_ name: String) {
        let key = "class_name"
        if rows(.settings).contains(where: { $0.s("key") == key }) {
            update(.settings, where: { $0.s("key") == key }) { $0["value"] = name }
        } else {
            append(.settings, ["key": key, "value": name])
        }
        touch(.settings)
    }
}

// MARK: - Private subjects and private devotion
//
// Stored in settings.csv, which is in the student folder and so never shared. Rows look like
// "private_subject_Devotion,on" and "private_devotion,on". A missing row means shared.

extension Database {
    static let privateSubjectPrefix = "private_subject_"
    static let privateDevotionKey = "private_devotion"

    /// Reads the privacy rows from a list of settings rows.
    static func privacy(from rows: [Row]) -> (subjects: Set<String>, devotion: Bool) {
        var subjects = Set<String>()
        var devotion = false
        for r in rows where r.s("value").lowercased() == "on" {
            let k = r.s("key")
            if k == privateDevotionKey { devotion = true }
            else if k.hasPrefix(privateSubjectPrefix) { subjects.insert(String(k.dropFirst(privateSubjectPrefix.count))) }
        }
        return (subjects, devotion)
    }

    func isPrivateSubject(_ name: String) -> Bool {
        Database.privacy(from: rows(.settings)).subjects.contains(name)
    }

    var devotionIsPrivate: Bool { Database.privacy(from: rows(.settings)).devotion }

    func setSetting(_ key: String, _ value: String) {
        if rows(.settings).contains(where: { $0.s("key") == key }) {
            update(.settings, where: { $0.s("key") == key }) { $0["value"] = value }
        } else {
            append(.settings, ["key": key, "value": value])
        }
        touch(.settings)
    }
}
