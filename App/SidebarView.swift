import SwiftUI
import StickiesCore

struct SidebarView: View {
    @Environment(Board.self) private var board
    @State private var showFeedback = false

    var body: some View {
        let selection = Binding<Folder.ID?>(
            get: { board.selectedFolderID },
            set: { if let id = $0 { board.select(id) } })
        List(selection: selection) {
            FolderRow(folder: board.library.inbox).tag(board.library.inbox.id)
            Section("Folders") {
                ForEach(board.library.userFolders) { folder in
                    FolderRow(folder: folder).tag(folder.id)
                }
                .onMove { from, to in
                    guard let i = from.first else { return }
                    let id = board.library.userFolders[i].id
                    board.moveFolder(id, to: to > i ? to - 1 : to)
                }
                if board.library.userFolders.isEmpty {
                    Text("Make a folder for each part of your life you jot notes about: a project, cooking, trips.")
                        .font(.caption)
                        .foregroundStyle(Theme.quiet)
                        .fixedSize(horizontal: false, vertical: true)
                        .selectionDisabled()
                }
            }
            Section {
                FolderRow(folder: board.library.archive).tag(board.library.archive.id)
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            HStack {
                Button { board.newFolder() } label: {
                    Label("New Folder", systemImage: "folder.badge.plus")
                }
                .help("New folder (⇧⌘N)")
                .accessibilityIdentifier("newFolderButton")
                Spacer()
                Button { showFeedback = true } label: {
                    Label("Feedback", systemImage: "bubble.left")
                        .labelStyle(.iconOnly)
                }
                .help("Send feedback")
                .accessibilityLabel("Send feedback")
                .accessibilityIdentifier("feedbackButton")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(Theme.quiet)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .sheet(isPresented: $showFeedback) { FeedbackView() }
    }
}

struct FolderRow: View {
    @Environment(Board.self) private var board
    let folder: Folder
    @State private var isTargeted = false
    @State private var draftName = ""
    @State private var confirmDelete = false
    @FocusState private var nameFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            if folder.kind == .user {
                Circle()
                    .fill(Theme.dot(folder.color))
                    .frame(width: 9, height: 9)
                    .frame(width: 18)
            } else {
                Image(systemName: folder.kind.symbol)
                    .foregroundStyle(Theme.quiet)
                    .frame(width: 18)
            }
            if board.renamingFolderID == folder.id {
                TextField("Folder name", text: $draftName)
                    .textFieldStyle(.plain)
                    .focused($nameFocused)
                    .onAppear { draftName = folder.name; nameFocused = true }
                    .onSubmit { board.renameFolder(folder.id, to: draftName) }
                    .onExitCommand { board.renamingFolderID = nil }
                    .onChange(of: nameFocused) { _, focused in
                        if !focused && board.renamingFolderID == folder.id { board.renameFolder(folder.id, to: draftName) }
                    }
                    .accessibilityIdentifier("folderNameField")
            } else {
                Text(folder.name).lineLimit(1)
            }
            Spacer(minLength: 4)
            let stale = board.staleCount(in: folder)
            if stale > 0 {
                Image(systemName: "clock")
                    .font(.caption2)
                    .foregroundStyle(Theme.quiet)
                    .help("\(stale) \(stale == 1 ? "note" : "notes") untouched for \(board.staleDays)+ days")
            }
            let shown = board.shownCount(folder)
            if shown > 0 {
                Text("\(shown)")
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(Theme.quiet)
                    .contentTransition(.numericText())
                    .animation(.snappy, value: shown)
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        // A small bounce when a flying card lands here.
        .keyframeAnimator(initialValue: 1.0, trigger: board.landings[folder.name] ?? 0) { row, scale in
            row.scaleEffect(scale, anchor: .leading)
        } keyframes: { _ in
            SpringKeyframe(1.06, duration: 0.12)
            SpringKeyframe(1.0, duration: 0.3)
        }
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { board.frames.folders[folder.name] = $0 }
        .background(RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.accent, lineWidth: isTargeted ? 2 : 0).padding(-4))
        .dropDestination(for: String.self) { items, _ in
            let ids = items.compactMap(NoteDragID.parse)
            for id in ids { board.move(id, to: folder.id) }
            return !ids.isEmpty
        } isTargeted: { isTargeted = $0 }
        .contextMenu {
            if folder.kind == .user {
                Button("Rename") { board.renamingFolderID = folder.id }
                Menu("Color") {
                    ForEach(FolderColor.userChoices, id: \.self) { c in
                        Button { board.setColor(folder.id, c) } label: {
                            Text(c.displayName + (c == folder.color ? "  ✓" : ""))
                        }
                    }
                }
            }
            Button("Show in Finder") { board.revealInFinder(folder) }
            if folder.kind == .user {
                Divider()
                Button("Delete Folder…", role: .destructive) { confirmDelete = true }
            }
        }
        .confirmationDialog("Delete “\(folder.name)”?", isPresented: $confirmDelete) {
            Button("Delete Folder", role: .destructive) { board.deleteFolder(folder.id) }
        } message: {
            Text(folder.notes.isEmpty
                 ? "The empty folder goes to the Trash."
                 : "Its \(folder.notes.count) \(folder.notes.count == 1 ? "note moves" : "notes move") to Inbox, so nothing is lost. The empty folder goes to the Trash.")
        }
        .accessibilityElement(children: board.renamingFolderID == folder.id ? .contain : .combine)
        .accessibilityLabel(board.renamingFolderID == folder.id ? "Rename folder" : "\(folder.name), \(folder.notes.count) notes")
        .accessibilityIdentifier("folder-\(folder.name)")
    }
}

/// Notes are dragged as "note:<uuid>" strings.
enum NoteDragID {
    static func string(_ id: Note.ID) -> String { "note:\(id.uuidString)" }
    static func parse(_ s: String) -> Note.ID? {
        guard s.hasPrefix("note:") else { return nil }
        return UUID(uuidString: String(s.dropFirst(5)))
    }
}
