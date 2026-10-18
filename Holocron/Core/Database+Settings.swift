import Foundation

// MARK: - Simple saved settings (settings.csv holds key,value rows)

extension Database {
    static let defaultClassName = "6AS"
    static let classNameKey = "class_name"

    /// The value saved for a settings key, or nil when there is no row for it.
    func setting(_ key: String) -> String? {
        index(.settings).settings[key]
    }

    /// Saves a settings value, adding the row when the key is new.
    func setSetting(_ key: String, _ value: String) {
        if setting(key) != nil {
            update(.settings, where: { $0.s("key") == key }) { $0["value"] = value }
        } else {
            append(.settings, ["key": key, "value": value])
        }
        touch(.settings)
    }

    /// What is typed in Settings, which may be empty (the default name is then shown).
    var classNameSetting: String {
        setting(Database.classNameKey) ?? ""
    }

    /// The class name shown in the sidebar and on exported student summaries.
    var className: String {
        let v = classNameSetting.trimmingCharacters(in: .whitespaces)
        return v.isEmpty ? Database.defaultClassName : v
    }

    func setClassName(_ name: String) {
        setSetting(Database.classNameKey, name)
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
        index(.settings).privacy.subjects.contains(name)
    }

    var devotionIsPrivate: Bool { index(.settings).privacy.devotion }
}
