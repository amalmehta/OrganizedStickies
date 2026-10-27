import SwiftUI
import StickiesCore

struct EmptyStateView: View {
    let picture: AnyView
    let title: String
    let message: String
    var actions: AnyView? = nil

    var body: some View {
        VStack(spacing: 14) {
            picture
                .frame(width: 120, height: 96)
                .accessibilityHidden(true)
            Text(title)
                .font(.system(size: 19, weight: .semibold, design: .serif))
                .foregroundStyle(Theme.ink)
            Text(message)
                .font(.callout)
                .foregroundStyle(Theme.quiet)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)
                .fixedSize(horizontal: false, vertical: true)
            if let actions { actions.padding(.top, 4) }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Two stickies, slightly askew, in the folder's color. Flat, close to the real thing.
struct NoteStackPicture: View {
    let color: FolderColor

    var body: some View {
        ZStack {
            sticky.rotationEffect(.degrees(-7)).offset(x: -14, y: 4)
            sticky.rotationEffect(.degrees(5)).offset(x: 14, y: -4)
        }
    }

    private var sticky: some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(Theme.paper(color))
            .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(Theme.dot(color).opacity(0.5), lineWidth: 1))
            .overlay(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 6) {
                    Capsule().fill(Theme.dot(color)).frame(width: 38, height: 5)
                    Capsule().fill(Theme.dot(color).opacity(0.45)).frame(width: 50, height: 3)
                    Capsule().fill(Theme.dot(color).opacity(0.45)).frame(width: 30, height: 3)
                }
                .padding(10)
            }
            .frame(width: 72, height: 72)
            .shadow(color: .black.opacity(0.06), radius: 2, y: 1)
    }
}

struct FolderEmptyState: View {
    @Environment(Board.self) private var board
    let folder: Folder

    var body: some View {
        switch folder.kind {
        case .inbox:
            EmptyStateView(
                picture: AnyView(NoteStackPicture(color: .paper)),
                title: "Inbox is clear",
                message: "New notes land here first. When there's something to sort, each note gets a suggested folder.",
                actions: AnyView(Button("New Note") { board.newNote() }.keyboardShortcut(.defaultAction)))
        case .archive:
            EmptyStateView(
                picture: AnyView(NoteStackPicture(color: .stone)),
                title: "Nothing archived yet",
                message: "Notes you're done with rest here, out of the way but still searchable. Notes untouched for \(board.staleDays) days get an Archive button.")
        case .user:
            EmptyStateView(
                picture: AnyView(NoteStackPicture(color: folder.color)),
                title: "Nothing in \(folder.name) yet",
                message: "Drag notes here from the Inbox, or write one. Once a few notes are here, Inbox suggestions start pointing to this folder.",
                actions: AnyView(Button("New Note") { board.newNote() }))
        }
    }
}

/// First run: no notes anywhere.
struct WelcomeView: View {
    @Environment(Board.self) private var board
    @State private var status: String?
    @State private var working = false

    var body: some View {
        EmptyStateView(
            picture: AnyView(NoteStackPicture(color: .butter)),
            title: "Start with the notes you have",
            message: "Copy your Apple Stickies in (the originals stay untouched), try a set of sample notes, or write your first one. Each note is a plain text file in Documents › Organized Stickies.",
            actions: AnyView(VStack(spacing: 10) {
                HStack(spacing: 10) {
                    Button {
                        working = true
                        Task { status = await board.importFromAppleStickies(); working = false }
                    } label: { Label("Import from Apple Stickies", systemImage: "square.and.arrow.down") }
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("importStickies")
                    Button {
                        working = true
                        Task { await board.addSampleNotes(); working = false }
                    } label: { Label("Add Sample Notes", systemImage: "rectangle.stack") }
                        .accessibilityIdentifier("addSamples")
                    Button { board.newNote() } label: { Label("New Note", systemImage: "square.and.pencil") }
                }
                .disabled(working)
                if let status {
                    Text(status).font(.callout).foregroundStyle(Theme.quiet)
                }
            }))
    }
}
