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
        case .classScreen: return "A student friendly projector view with the learning intention, steps, today's timetable, a timer and a stopwatch"
        case .term: return "Term overview for one subject"
        case .units: return "Units of inquiry"
        case .devotion: return "Daily devotion and Circle Time scripts"
        case .students: return "Student records, notes and reports"
        case .work: return "Photos of students' work, with captions for reports"
        case .quick: return "Photo grid for fast notes"
        case .assess: return "Mark the whole class on one task"
        case .hours: return "Face to face, release and DOTTL"
        }
    }

    /// The settings.csv key that holds whether this module is on.
    var settingKey: String { "module_" + rawValue }

    /// The settings.csv key that holds the sidebar order, as screen names separated by commas.
    static let orderKey = "sidebar_order"

    /// Reads a saved order. Unknown or repeated names are skipped, and any screen not in the list goes at the end.
    static func order(from saved: String?) -> [NavItem] {
        var out: [NavItem] = []
        for part in (saved ?? "").split(separator: ",") {
            if let n = NavItem(rawValue: String(part)), !out.contains(n) { out.append(n) }
        }
        return out + allCases.filter { !out.contains($0) }
    }
}

extension AppModel {
    func isEnabled(_ n: NavItem) -> Bool {
        guard n.canDisable else { return true }
        return (db.setting(n.settingKey) ?? "").lowercased() != "off"
    }

    /// The sidebar in the order the teacher chose in Settings. Screens left out of the saved order go at the end.
    var sidebarOrder: [NavItem] { NavItem.order(from: db.setting(NavItem.orderKey)) }

    var visibleNav: [NavItem] { sidebarOrder.filter { isEnabled($0) } }

    /// Where a screen would go if moved up (-1) or down (+1): the next screen under the same sidebar heading.
    private func sidebarTarget(_ item: NavItem, by step: Int) -> Int? {
        let items = sidebarOrder
        guard let i = items.firstIndex(of: item) else { return nil }
        var j = i + step
        while items.indices.contains(j) {
            if items[j].group == item.group { return j }
            j += step
        }
        return nil
    }

    func canMoveSidebar(_ item: NavItem, by step: Int) -> Bool { sidebarTarget(item, by: step) != nil }

    /// Moves a screen one place up (-1) or down (+1) among the screens under its heading. Does nothing at either end.
    func moveSidebar(_ item: NavItem, by step: Int) {
        guard let j = sidebarTarget(item, by: step), let i = sidebarOrder.firstIndex(of: item) else { return }
        var items = sidebarOrder
        items.swapAt(i, j)
        db.setSetting(NavItem.orderKey, items.map(\.rawValue).joined(separator: ","))
    }

    /// Puts the sidebar back in the order Holocron ships with.
    func resetSidebarOrder() {
        db.setSetting(NavItem.orderKey, "")
    }

    func setEnabled(_ n: NavItem, _ on: Bool) {
        guard n.canDisable else { return }
        db.setSetting(n.settingKey, on ? "on" : "off")
        if !on && nav == n { nav = .today }
    }
}
