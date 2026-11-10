import Foundation

// MARK: - Groups of students
//
// groups.csv lives in the student folder. Each row is one named group, with its students' ids joined
// by semicolons. Names of students are never kept in it.

struct StudentGroup: Identifiable, Equatable {
    var id: String
    var name: String
    var subject: String
    var studentIDs: [String]
}

extension Database {
    var studentGroups: [StudentGroup] {
        rows(.groups).map {
            StudentGroup(id: $0.s("id"), name: $0.s("name"), subject: $0.s("subject"), studentIDs: Grouping.ids($0.s("student_ids")))
        }
        .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// The group's students who are still on the roll, in roll order.
    func members(of group: StudentGroup) -> [Student] {
        let want = Set(group.studentIDs)
        return roster.filter { want.contains($0.id) }
    }

    func addGroup(name: String, subject: String, studentIDs: [String]) {
        append(.groups, ["id": uid(), "name": name, "subject": subject, "student_ids": Grouping.join(studentIDs)])
        touch(.groups)
    }

    func renameGroup(_ id: String, to name: String) {
        update(.groups, where: { $0.s("id") == id }) { $0["name"] = name }
        touch(.groups)
    }

    func deleteGroup(_ id: String) {
        withUndo("Delete Group", done: "Group deleted", tables: [.groups]) {
            remove(.groups, where: { $0.s("id") == id })
            touch(.groups)
        }
    }

    /// Takes a student out of every group, for when they are deleted.
    func removeFromGroups(_ studentID: String) {
        var changed = false
        update(.groups, where: { Grouping.ids($0.s("student_ids")).contains(studentID) }) { r in
            r["student_ids"] = Grouping.join(Grouping.ids(r.s("student_ids")).filter { $0 != studentID })
            changed = true
        }
        if changed { touch(.groups) }
    }

    /// A student's most recent numbered result, for making groups that mix results. For one subject, or any.
    func latestPercent(_ studentID: String, subject: String = "") -> Double? {
        var best: (date: String, value: Double)? = nil
        for a in rows(.assessments) where a.s("student_id") == studentID && (subject.isEmpty || a.s("subject") == subject) {
            guard let p = Markbook.percent(a.s("result")) else { continue }
            if best == nil || a.s("date") >= best!.date { best = (a.s("date"), p) }
        }
        return best?.value
    }

    /// Whether names of groups' students may show on the Class screen. Off until switched on.
    static let classGroupsKey = "class_groups"
    var classGroupsOn: Bool { (setting(Database.classGroupsKey) ?? "off") == "on" }
}
