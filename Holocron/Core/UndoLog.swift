import Foundation

// MARK: - Undo
//
// A short history of changes that can be taken back, such as deleting a note or swapping two lessons.
// Before the change, the affected tables are copied (the copy is cheap, rows are shared until one
// changes). Undo puts the copy back and keeps what it replaced, so Redo works too.
//
// The history is in memory only and nothing extra is written to disk. It is cleared for a table as
// soon as anything else changes that table, because putting the old rows back would also remove
// that newer change. A reload from the folder clears it for the tables that were read.

struct UndoStep {
    /// "Delete Note", as it reads in the Edit menu after Undo.
    var name: String
    /// What to say after it is done, such as "Note deleted".
    var done: String
    var tables: [TableName: [Row]]
}

extension Database {
    static let undoLimit = 20

    var undoName: String? { undoSteps.last?.name }
    var redoName: String? { redoSteps.last?.name }

    /// Makes a change that can be undone. `tables` are every table the change touches.
    func withUndo(_ name: String, done: String, tables ts: [TableName], _ change: () -> Void) {
        var copy: [TableName: [Row]] = [:]
        for t in ts { copy[t] = tables[t.rawValue] ?? [] }
        undoQuiet += 1
        change()
        undoQuiet -= 1
        undoSteps.append(UndoStep(name: name, done: done, tables: copy))
        if undoSteps.count > Self.undoLimit { undoSteps.removeFirst(undoSteps.count - Self.undoLimit) }
        redoSteps.removeAll()
        onUndoChange?(done)
    }

    /// Takes back the latest change. Returns its name, or nil when there is nothing to take back.
    @discardableResult
    func undo() -> String? {
        guard let step = undoSteps.popLast() else { return nil }
        redoSteps.append(swapIn(step))
        onUndoChange?(nil)
        return step.name
    }

    @discardableResult
    func redo() -> String? {
        guard let step = redoSteps.popLast() else { return nil }
        undoSteps.append(swapIn(step))
        onUndoChange?(nil)
        return step.name
    }

    /// Puts the saved rows back and returns the rows they replaced.
    private func swapIn(_ step: UndoStep) -> UndoStep {
        var now: [TableName: [Row]] = [:]
        undoQuiet += 1
        for (t, rows) in step.tables {
            now[t] = tables[t.rawValue] ?? []
            setRows(t, rows)
        }
        touch(Set(step.tables.keys))
        undoQuiet -= 1
        return UndoStep(name: step.name, done: step.done, tables: now)
    }

    /// Drops the steps that include any of these tables.
    func forgetUndo(touching names: Set<TableName>) {
        guard !undoSteps.isEmpty || !redoSteps.isEmpty else { return }
        let before = undoSteps.count + redoSteps.count
        undoSteps.removeAll { step in names.contains(where: { step.tables[$0] != nil }) }
        redoSteps.removeAll { step in names.contains(where: { step.tables[$0] != nil }) }
        if undoSteps.count + redoSteps.count != before { onUndoChange?(nil) }
    }
}
