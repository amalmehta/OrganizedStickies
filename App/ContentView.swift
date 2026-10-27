import SwiftUI
import StickiesCore

struct ContentView: View {
    @Environment(Board.self) private var board

    var body: some View {
        @Bindable var board = board
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 190, ideal: 220, max: 320)
        } detail: {
            BoardView()
        }
        .searchable(text: $board.searchText, placement: .toolbar, prompt: "Search all notes")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { board.newNote() } label: {
                    Label("New Note", systemImage: "square.and.pencil")
                }
                .help("New note (⌘N)")
                .accessibilityIdentifier("newNoteButton")
            }
        }
        .overlay(alignment: .bottom) {
            if let message = board.errorMessage {
                ErrorBanner(message: message) { board.errorMessage = nil }
                    .padding(16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.2), value: board.errorMessage)
        .tint(Theme.accent)
    }
}

struct ErrorBanner: View {
    let message: String
    let dismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(Theme.terracotta)
            Text(message)
                .font(.callout)
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
            Button("Dismiss", action: dismiss)
                .buttonStyle(.borderless)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        .frame(maxWidth: 560)
    }
}
