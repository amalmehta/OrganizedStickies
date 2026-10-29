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
        .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        .background { Backdrop().ignoresSafeArea() }
        .overlay { FlightLayer().ignoresSafeArea() }
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

/// Draws accepted cards flying into their folder rows. Purely visual: it
/// takes no clicks and VoiceOver skips it (the move itself is announced by
/// the card leaving and the folder count changing).
struct FlightLayer: View {
    @Environment(Board.self) private var board

    var body: some View {
        GeometryReader { geo in
            let origin = geo.frame(in: .global).origin
            ForEach(board.flights) { FlyingCard(flight: $0, origin: origin) }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct FlyingCard: View {
    let flight: Flight
    let origin: CGPoint
    @State private var landed = false
    @State private var faded = false

    var body: some View {
        let from = flight.from
        // Aim at the row's color dot, shrinking to about its height.
        let target = CGPoint(x: flight.to.minX + 18, y: flight.to.midY)
        let end = max(0.08, min(0.3, flight.to.height / max(from.height, 1)))
        VStack(alignment: .leading) {
            Text(flight.title)
                .font(.system(size: 15, weight: .semibold, design: .serif))
                .foregroundStyle(Theme.ink)
                .lineLimit(2)
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(width: from.width, height: from.height, alignment: .topLeading)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(landed ? Theme.dot(flight.toColor) : Theme.paper(flight.fromColor))
                .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
        }
        .scaleEffect(landed ? end : 1)
        .opacity(faded ? 0 : 1)
        .position(x: (landed ? target.x : from.midX) - origin.x, y: (landed ? target.y : from.midY) - origin.y)
        .onAppear {
            withAnimation(.spring(duration: Flight.duration, bounce: 0.12).delay(flight.delay)) { landed = true }
            withAnimation(.easeIn(duration: Flight.duration * 0.5).delay(flight.delay + Flight.duration * 0.55)) { faded = true }
        }
    }
}
