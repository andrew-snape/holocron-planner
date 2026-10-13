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
