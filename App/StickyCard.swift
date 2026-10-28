import SwiftUI
import StickiesCore

struct StickyCard: View {
    @Environment(Board.self) private var board
    @Environment(\.textScale) private var scale
    let note: Note
    let folder: Folder
    var showFolder = false
    /// Called after notes are dropped onto this card (they now sit before it).
    var onDropBefore: ([Note.ID]) -> Void = { _ in }
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
        // As tall as its text: short notes make short cards.
        .frame(maxWidth: .infinity, alignment: .topLeading)
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
            onDropBefore(ids)
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
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { board.frames.cards[note.id] = $0 }
        .onDisappear { board.frames.cards[note.id] = nil }
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
            .frame(height: 240 * scale)
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
                    .lineLimit(CardHeight.bodyLines)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(.bottom, 4)
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

/// A quick guess at a card's height from its text, used only to decide which
/// column it goes in (the card itself is always as tall as its text). Close
/// enough that columns end at about the same place.
enum CardHeight {
    static let bodyLines = 8

    static func estimate(_ note: Note, width: CGFloat, scale: Double, hasFooterNote: Bool) -> Double {
        let textWidth = max(60, Double(width) - 28)
        func lines<S: StringProtocol>(_ s: S, charWidth: Double) -> Int {
            max(1, Int((Double(s.count) * charWidth * scale / textWidth).rounded(.up)))
        }
        let title = min(2, lines(note.title.isEmpty ? "Untitled" : note.title, charWidth: 8.4))
        var body = 0
        if !note.body.isEmpty {
            for paragraph in note.body.split(separator: "\n", omittingEmptySubsequences: false) {
                body += lines(paragraph, charWidth: 6.9)
                if body >= bodyLines { break }
            }
            body = min(bodyLines, body)
        }
        let footer = hasFooterNote ? 56.0 : 18.0
        return (28 + Double(title) * 19 + (body > 0 ? 6 + Double(body) * 17.5 : 0) + 10 + footer) * scale
    }
}
