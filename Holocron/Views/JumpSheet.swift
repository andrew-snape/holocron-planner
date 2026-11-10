import SwiftUI

/// Jump (Cmd+K): type a few letters, press Return, and go to a student, a screen, a unit or a lesson.
struct JumpSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var picked = 0
    @FocusState private var focused: Bool

    /// Names stay off the list while a Class screen could be showing them to the room.
    private var namesOK: Bool { model.classScreens.isEmpty && model.nav != .classScreen }

    var body: some View {
        let list = JumpSearch.results(query, db: model.db, screens: model.visibleNav,
                                      includeStudents: namesOK, today: todayISO())
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(Color.ink2)
                TextField("Jump to a student, screen, unit or lesson", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 17))
                    .focused($focused)
                    .onSubmit { open(list) }
                    .onKeyPress(.downArrow) { picked = min(picked + 1, max(list.count - 1, 0)); return .handled }
                    .onKeyPress(.upArrow) { picked = max(picked - 1, 0); return .handled }
                    .accessibilityLabel("Jump to")
            }
            .padding(14)
            Divider()
            if list.isEmpty {
                Text(query.trimmed.isEmpty ? "Nothing to jump to." : "Nothing matches \u{201C}\(query)\u{201D}.")
                    .font(.system(size: 13)).foregroundStyle(Color.ink2)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(Array(list.enumerated()), id: \.element.id) { i, r in
                                row(r, selected: i == picked)
                                    .id(r.id)
                                    .onTapGesture { go(r) }
                                    .accessibilityAction { go(r) }
                                    .accessibilityHint("Opens it")
                            }
                        }
                        .padding(8)
                    }
                    .onChange(of: picked) { _, n in
                        if list.indices.contains(n) { proxy.scrollTo(list[n].id) }
                    }
                }
            }
            Divider()
            Text("Return to go, Esc to close.")
                .font(.system(size: 12)).foregroundStyle(Color.ink2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14).padding(.vertical, 8)
        }
        .frame(minWidth: 420, idealWidth: 520, minHeight: 320, idealHeight: 420)
        .background(Color.appBG)
        .onAppear { focused = true }
        .onChange(of: query) { _, _ in picked = 0 }
        .onExitCommand { dismiss() }
    }

    private func row(_ r: JumpResult, selected: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: r.symbol).frame(width: 22).foregroundStyle(Color.appBlue)
            VStack(alignment: .leading, spacing: 1) {
                Text(r.title).font(.system(size: 13, weight: .medium)).lineLimit(1)
                Text(r.detail).font(.system(size: 12)).foregroundStyle(Color.ink2).lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(selected ? Color.fillStrong : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }

    private func open(_ list: [JumpResult]) {
        if list.indices.contains(picked) { go(list[picked]) }
    }

    private func go(_ r: JumpResult) {
        dismiss()
        model.jump(to: r.target)
    }
}
