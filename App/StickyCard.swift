import SwiftUI
import StickiesCore

struct StickyCard: View {
    @Environment(Board.self) private var board
    @Environment(\.textScale) private var scale
    let note: Note
    let folder: Folder
    var showFolder = false
    @FocusState private var editorFocused: Bool
    @State private var isTargeted = false
    @State private var hovering = false

    private var isEditing: Bool { board.editingNoteID == note.id }
    private var isSelected: Bool { board.selectedNoteID == note.id }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if isEditing {
                editor
            } else {
                preview
            }
            footer
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(height: 200 * scale)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Theme.paper(folder.color))
                .shadow(color: .black.opacity(hovering || isEditing ? 0.12 : 0.06), radius: hovering || isEditing ? 6 : 2, y: 1)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(isSelected || isTargeted ? Theme.accent : Theme.hairline, lineWidth: isSelected || isTargeted ? 2 : 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 10))
        .onHover { h in withAnimation(.easeOut(duration: 0.15)) { hovering = h } }
        .onTapGesture {
            if showFolder { board.select(folder.id) }
            board.beginEditing(note.id)
        }
        .modifier(DraggableUnlessEditing(id: note.id, isEditing: isEditing, title: note.title, color: folder.color))
        .dropDestination(for: String.self) { items, _ in
            let ids = items.compactMap(NoteDragID.parse)
            for id in ids { board.reorder(id, before: note.id) }
            return !ids.isEmpty
        } isTargeted: { isTargeted = $0 }
        .contextMenu { menu }
        // One VoiceOver element per card; its buttons become named actions
        // (fewer swipes, and a small accessibility tree with many cards).
        .accessibilityElement(children: isEditing ? .contain : .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
        .accessibilityAction(named: "Edit") { board.beginEditing(note.id) }
        .accessibilityActions {
            if case let .suggest(name, _, _)? = board.suggestion(for: note) {
                Button("Move to \(name)") { board.acceptSuggestion(note.id) }
                Button("Dismiss suggestion") { board.dismissSuggestion(note.id) }
            }
            if folder.kind != .archive { Button("Archive") { board.archive(note.id) } }
            Button("Move to Trash") { board.delete(note.id) }
        }
        .accessibilityIdentifier("note-\(note.title)")
    }

    // MARK: Parts

    private var editor: some View {
        TextEditor(text: Binding(
            get: { board.library.note(note.id)?.text ?? "" },
            set: { board.setText(note.id, $0) }))
            .font(Theme.bodyFont(scale))
            .foregroundStyle(Theme.ink)
            .scrollContentBackground(.hidden)
            .scrollIndicators(.automatic)
            .focused($editorFocused)
            .onAppear { editorFocused = true }
            .onKeyPress(.escape) { board.endEditing(); return .handled }
            .onChange(of: editorFocused) { _, focused in
                if !focused && board.editingNoteID == note.id { board.endEditing() }
            }
            .padding(.horizontal, -5)
            .accessibilityLabel("Note text")
            .accessibilityIdentifier("noteEditor")
    }

    private var preview: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(note.title.isEmpty ? "Untitled" : note.title)
                .font(Theme.titleFont(scale))
                .foregroundStyle(note.title.isEmpty ? Theme.quiet : Theme.ink)
                .lineLimit(2)
            if !note.body.isEmpty {
                Text(note.body)
                    .font(Theme.bodyFont(scale))
                    .foregroundStyle(Theme.ink.opacity(0.82))
                    .lineSpacing(2)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .clipped()
    }

    @ViewBuilder
    private var footer: some View {
        if !isEditing, let outcome = board.suggestion(for: note) {
            switch outcome {
            case let .suggest(name, _, reason):
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Button { board.acceptSuggestion(note.id) } label: {
                            Label("Move to \(name)", systemImage: "arrow.right")
                                .lineLimit(1)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .tint(Theme.accent)
                        .help("Move this note to \(name) (⌘Y)")
                        .accessibilityIdentifier("acceptSuggestion")
                        Button { board.dismissSuggestion(note.id) } label: {
                            Image(systemName: "xmark")
                        }
                        .buttonStyle(.borderless)
                        .controlSize(.small)
                        .foregroundStyle(Theme.quiet)
                        .help("Not there. Keep it in Inbox.")
                        .accessibilityLabel("Dismiss suggestion")
                    }
                    Text(reason)
                        .font(Theme.smallFont(scale))
                        .foregroundStyle(Theme.quiet)
                        .lineLimit(2)
                        .help(reason)
                }
            case let .noClearMatch(reason):
                VStack(alignment: .leading, spacing: 2) {
                    Label("No clear match", systemImage: "questionmark.folder")
                    Text(reason).lineLimit(2).opacity(0.85)
                }
                .font(Theme.smallFont(scale))
                .foregroundStyle(Theme.quiet)
                .help(reason)
            }
        } else if !isEditing, board.isStale(note, in: folder) {
            HStack(spacing: 6) {
                Label("Untouched \(Staleness.ageLabel(note.modified).replacingOccurrences(of: " ago", with: ""))", systemImage: "clock")
                    .font(Theme.smallFont(scale))
                    .foregroundStyle(Theme.terracotta)
                    .lineLimit(1)
                Spacer(minLength: 2)
                Button("Archive") { board.archive(note.id) }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Move to Archive. It stays searchable.")
                Button { board.dismissedStale.insert(note.id) } label: { Image(systemName: "xmark") }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                    .foregroundStyle(Theme.quiet)
                    .help("Keep it here")
                    .accessibilityLabel("Keep note here")
            }
        } else {
            HStack(spacing: 6) {
                if showFolder {
                    Circle().fill(Theme.dot(folder.color)).frame(width: 7, height: 7)
                    Text(folder.name).lineLimit(1)
                    Text("·")
                }
                Text(isEditing ? "Editing · Esc when done" : "Edited \(Staleness.ageLabel(note.modified))")
                    .lineLimit(1)
            }
            .font(Theme.smallFont(scale))
            .foregroundStyle(Theme.quiet)
        }
    }

    @ViewBuilder
    private var menu: some View {
        Button("Edit") { board.beginEditing(note.id) }
        Menu("Move To") {
            ForEach(board.library.folders.filter { $0.id != folder.id }) { f in
                Button(f.name) { board.move(note.id, to: f.id) }
            }
        }
        if folder.kind != .archive {
            Button("Archive") { board.archive(note.id) }
        }
        Button("Copy Text") {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(note.text, forType: .string)
        }
        if note.isOnDisk {
            Button("Show in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([board.root.appendingPathComponent(folder.name).appendingPathComponent(note.fileName)])
            }
        }
        Divider()
        Button("Move to Trash", role: .destructive) { board.delete(note.id) }
    }

    private var accessibilityText: String {
        var parts = [note.title.isEmpty ? "Untitled note" : note.title]
        if !note.body.isEmpty { parts.append(String(note.body.prefix(140))) }
        if showFolder { parts.append("in \(folder.name)") }
        parts.append("edited \(Staleness.ageLabel(note.modified))")
        if case let .suggest(name, _, _)? = board.suggestion(for: note) { parts.append("suggested folder: \(name)") }
        return parts.joined(separator: ". ")
    }
}

/// Cards drag as "note:<uuid>" — but not while you're selecting text in one.
private struct DraggableUnlessEditing: ViewModifier {
    let id: Note.ID
    let isEditing: Bool
    let title: String
    let color: FolderColor

    func body(content: Content) -> some View {
        if isEditing {
            content
        } else {
            content.draggable(NoteDragID.string(id)) {
                Text(title.isEmpty ? "Untitled" : title)
                    .font(.system(size: 13, weight: .semibold, design: .serif))
                    .padding(10)
                    .frame(width: 160, alignment: .leading)
                    .background(Theme.paper(color), in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}
