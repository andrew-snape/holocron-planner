import Foundation

/// Every CSV file the planner reads and writes, with its columns.
enum TableName: String, CaseIterable {
    case students, subjects, periods, timetable, dayplan, lessons, assessments, rubrics
    case plannotes, wellbeing, behaviour, lessonnotes, dottl, terms, nonteaching, dayoverrides
    case devotion, quotes, units, todo, reportjudge, reportcomment
    /// Lessons for subjects marked private. Same columns as lessons, but it lives in the student folder and is never shared.
    case lessonsprivate
    /// Mac app only: the First, Then and Next steps typed on the Class screen. Kept in the student folder.
    case classsteps
    /// Mac app only: key and value pairs such as which modules are switched off.
    case settings

    /// Which folder a table lives in. Planner tables can be shared with other staff;
    /// student tables (and personal ones such as the hours log and to-do) stay private.
    var isPlanner: Bool {
        switch self {
        case .subjects, .periods, .timetable, .dayplan, .lessons, .rubrics, .terms,
             .nonteaching, .dayoverrides, .devotion, .quotes, .units:
            return true
        default:
            return false
        }
    }

    var header: [String] {
        switch self {
        case .students:      return ["id", "first", "surname", "birthdate", "parents", "house", "roles", "adjustments", "nccd", "medical", "notes"]
        case .subjects:      return ["subject", "kind", "colour"]
        case .periods:       return ["period", "name", "start", "end"]
        case .timetable:     return ["week", "day", "period", "subject"]
        case .dayplan:       return ["date", "period", "subject"]
        case .lessons, .lessonsprivate: return ["date", "period", "subject", "summary", "li", "sc", "tuning", "teaching", "independent", "reflection", "resources", "codes", "atl", "profile"]
        case .assessments:   return ["id", "student_id", "date", "subject", "task", "result", "comment"]
        case .rubrics:       return ["rubric", "element", "order", "level", "descriptor"]
        case .plannotes:     return ["id", "student_id", "date", "type", "note"]
        case .wellbeing:     return ["id", "student_id", "date", "period_lost", "minutes", "note"]
        case .behaviour:     return ["id", "student_id", "date", "note"]
        case .lessonnotes:   return ["id", "student_id", "date", "time", "subject", "note"]
        case .dottl:         return ["id", "date", "type", "minutes", "note"]
        case .terms:         return ["year", "term", "start", "end"]
        case .nonteaching:   return ["date", "label"]
        case .dayoverrides:  return ["date", "type", "note"]
        case .devotion:      return ["date", "theme", "scripture", "time", "domain", "profile", "focus", "greeting", "values", "reading", "message", "questions", "prayer", "primer_name", "primer", "primer_note", "went_well", "transition"]
        case .quotes:        return ["date", "quote", "artist", "band", "source"]
        case .units:         return ["id", "title", "theme", "central_idea", "lines", "concepts", "related", "atl", "profile", "start", "end", "notes", "reflection"]
        case .todo:          return ["id", "text", "due", "done", "created"]
        case .reportjudge:   return ["id", "student_id", "sem", "subject", "achievement", "engagement"]
        case .reportcomment: return ["id", "student_id", "sem", "general"]
        case .classsteps:    return ["date", "period", "first", "then", "next"]
        case .settings:      return ["key", "value"]
        }
    }
}

// MARK: - Fixed lists

enum PYP {
    static let themes: [(name: String, hex: String)] = [
        ("Who we are", "#FF9500"),
        ("Where we are in place and time", "#A2845E"),
        ("How we express ourselves", "#FF2D55"),
        ("How the world works", "#007AFF"),
        ("How we organise ourselves", "#5856D6"),
        ("Sharing the planet", "#34C759")
    ]
    static let keyConcepts = ["Form", "Function", "Causation", "Change", "Connection", "Perspective", "Responsibility"]
    static let atlSkills = ["Thinking", "Research", "Communication", "Social", "Self-management"]
    static let profile = ["Inquirers", "Knowledgeable", "Thinkers", "Communicators", "Principled",
                          "Open-minded", "Caring", "Risk-takers", "Balanced", "Reflective"]
    static func themeHex(_ t: String) -> String {
        themes.first(where: { $0.name == t })?.hex ?? "#8E8E93"
    }
}

enum Lists {
    static let achievement = ["Extending", "Mastering", "Consolidating", "Developing", "Emerging", "Modified", "Not assessed"]
    static let engagement = ["Comprehensive", "Appropriate", "Inconsistent", "Minimal"]
    static let rubricLevels = ["Working Towards", "At Standard", "Working Beyond"]
    static let dayTypes = ["Normal", "Camp", "Sports carnival", "Excursion", "Pupil free day", "Other"]
    static let dottlTypes = ["Meeting", "Parent teacher", "Professional development", "Camp",
                             "Yard duty", "Wellbeing", "Behaviour", "Planning", "Other"]
    static let planNoteTypes = ["ILP goal", "ILP review", "SSG meeting", "NCCD adjustment", "NCCD evidence"]
    static let noBump = ["Circle Time", "Devotion"]
    static let houseColours: [String: String] = ["Deakin": "#DEB64A", "Barton": "#0B9EC5", "Parkes": "#E13B38", "Higgins": "#005E56"]
}
