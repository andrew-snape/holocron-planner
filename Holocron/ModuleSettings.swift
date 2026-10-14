import SwiftUI

// MARK: - Modules that can be switched off
//
// Stored in settings.csv as rows like "module_devotion,off". A missing row means the module is on.
// Today always stays on.

extension NavItem {
    var canDisable: Bool { self != .today }

    var blurb: String {
        switch self {
        case .today: return "The day at a glance"
        case .week: return "Plan the fortnight in a grid"
        case .classScreen: return "A student friendly projector view with the learning intention, steps and a timer"
        case .term: return "Term overview for one subject"
        case .units: return "Units of inquiry"
        case .devotion: return "Daily devotion and Circle Time scripts"
        case .students: return "Student records, notes and reports"
        case .quick: return "Photo grid for fast notes"
        case .assess: return "Mark the whole class on one task"
        case .hours: return "Face to face, release and DOTTL"
        }
    }
}

extension AppModel {
    func isEnabled(_ n: NavItem) -> Bool {
        guard n.canDisable else { return true }
        let v = db.rows(.settings).first(where: { $0.s("key") == "module_" + n.rawValue })?.s("value") ?? ""
        return v.lowercased() != "off"
    }

    var visibleNav: [NavItem] { NavItem.allCases.filter { isEnabled($0) } }

    func setEnabled(_ n: NavItem, _ on: Bool) {
        guard n.canDisable else { return }
        let key = "module_" + n.rawValue
        let value = on ? "on" : "off"
        if db.rows(.settings).contains(where: { $0.s("key") == key }) {
            db.update(.settings, where: { $0.s("key") == key }) { $0["value"] = value }
        } else {
            db.append(.settings, ["key": key, "value": value])
        }
        db.touch(.settings)
        if !on && nav == n { nav = .today }
    }
}
