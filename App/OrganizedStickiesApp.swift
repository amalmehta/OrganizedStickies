import AppKit
import SwiftUI
import StickiesCore

@main
struct OrganizedStickiesApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var board: Board
    @AppStorage("textSize") private var textSize: TextSize = .standard

    init() {
        let args = ProcessInfo.processInfo.arguments
        let isDemo = args.contains("-demo")
        let root: URL
        if isDemo {
            // A fresh copy of the sample notes each launch, so demo mode never touches real notes.
            root = FileManager.default.temporaryDirectory.appendingPathComponent("Organized Stickies Demo-\(UUID().uuidString.prefix(8))/Organized Stickies")
            try? SampleSet.load().write(to: root)
        } else if let i = args.firstIndex(of: "-root"), i + 1 < args.count {
            root = URL(fileURLWithPath: args[i + 1], isDirectory: true)
        } else {
            root = LibraryLoader.defaultRoot
        }
        let board = Board(root: root, isDemo: isDemo)
        _board = State(initialValue: board)
        AppDelegate.board = board
        board.reload()
    }

    var body: some Scene {
        // The board window is an AppKit window opened by AppDelegate, so it
        // always appears at launch (SwiftUI's scene restoration sometimes
        // skips it). Settings stays a SwiftUI scene for ⌘,.
        Settings {
            SettingsView()
                .environment(board)
                .environment(\.textScale, textSize.scale)
        }
        .commands { BoardCommands(board: board) }
    }
}

/// The board's root view; reads text size so changes apply live.
struct BoardRoot: View {
    let board: Board
    @AppStorage("textSize") private var textSize: TextSize = .standard

    var body: some View {
        ContentView()
            .environment(board)
            .environment(\.textScale, textSize.scale)
            .frame(minWidth: 640, minHeight: 420)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    @MainActor static var board: Board?
    @MainActor private var window: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        MainActor.assumeIsolated {
            // For documentation screenshots: -appearance light|dark.
            let args = ProcessInfo.processInfo.arguments
            if let i = args.firstIndex(of: "-appearance"), i + 1 < args.count {
                NSApp.appearance = NSAppearance(named: args[i + 1] == "dark" ? .darkAqua : .aqua)
            }
            showBoard()
        }
    }

    @MainActor func showBoard() {
        guard let board = AppDelegate.board else { return }
        if let window {
            window.makeKeyAndOrderFront(nil)
            return
        }
        let controller = NSHostingController(rootView: BoardRoot(board: board))
        controller.sceneBridgingOptions = [.toolbars, .title]
        let w = NSWindow(contentViewController: controller)
        w.title = board.isDemo ? "Organized Stickies (Demo)" : "Organized Stickies"
        w.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        w.toolbarStyle = .unified
        // See-through, so the glass backdrop shows the desktop behind the window.
        w.titlebarAppearsTransparent = true
        w.isOpaque = false
        w.backgroundColor = .clear
        w.isReleasedWhenClosed = false
        w.contentMinSize = NSSize(width: 640, height: 420)
        w.setContentSize(NSSize(width: 1080, height: 720))
        w.center()
        w.setFrameAutosaveName("Board")
        w.identifier = NSUserInterfaceItemIdentifier("board")
        window = w
        w.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        MainActor.assumeIsolated { showBoard() }
        return true
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let board = AppDelegate.board else { return .terminateNow }
        Task { @MainActor in
            board.endEditing()
            await board.flushAndWait()
            NSApp.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    func applicationDidBecomeActive(_ notification: Notification) {
        // Pick up edits made in Finder or another editor.
        MainActor.assumeIsolated {
            guard let board = AppDelegate.board, board.loaded, board.editingNoteID == nil else { return }
            board.reload()
        }
    }

    func applicationWillResignActive(_ notification: Notification) {
        MainActor.assumeIsolated { AppDelegate.board?.flush() }
    }
}

private struct TextScaleKey: EnvironmentKey { static let defaultValue: Double = 1 }
extension EnvironmentValues {
    var textScale: Double {
        get { self[TextScaleKey.self] }
        set { self[TextScaleKey.self] = newValue }
    }
}

struct BoardCommands: Commands {
    let board: Board

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Note") { board.newNote() }
                .keyboardShortcut("n")
            Button("New Folder") { board.newFolder() }
                .keyboardShortcut("n", modifiers: [.command, .shift])
        }
        CommandMenu("Note") {
            Button("Edit Note") { if let id = board.selectedNoteID { board.beginEditing(id) } }
                .disabled(board.selectedNoteID == nil || board.editingNoteID != nil)
            Button("Done Editing") { board.endEditing() }
                .disabled(board.editingNoteID == nil)
            Divider()
            Button("Accept Suggestion") { if let id = board.selectedNoteID { board.acceptSuggestion(id) } }
                .keyboardShortcut("y", modifiers: [.command])
                .disabled(board.selectedNoteID.flatMap { board.library.note($0) }.flatMap { board.suggestion(for: $0)?.folder } == nil)
            Button("Move All Suggested") { board.acceptAllSuggestions() }
                .keyboardShortcut("y", modifiers: [.command, .shift])
                .disabled(board.suggestedMoves.isEmpty)
            Menu("Move To") {
                ForEach(Array(board.library.folders.enumerated()), id: \.element.id) { i, f in
                    let b = Button(f.name) { if let id = board.selectedNoteID { board.move(id, to: f.id) } }
                    if i < 9 { b.keyboardShortcut(KeyEquivalent(Character("\(i + 1)")), modifiers: [.command, .option]) } else { b }
                }
            }
            .disabled(board.selectedNoteID == nil)
            Button("Archive") { if let id = board.selectedNoteID { board.archive(id) } }
                .keyboardShortcut("e", modifiers: [.command, .shift])
                .disabled(board.selectedNoteID == nil)
            Divider()
            Button("Move to Trash") { if let id = board.selectedNoteID { board.delete(id) } }
                .keyboardShortcut(.delete, modifiers: [.command])
                .disabled(board.selectedNoteID == nil || board.editingNoteID != nil)
        }
        CommandGroup(after: .sidebar) {
            ForEach(Array(board.library.folders.prefix(9).enumerated()), id: \.element.id) { i, f in
                Button("Show \(f.name)") { board.select(f.id) }
                    .keyboardShortcut(KeyEquivalent(Character("\(i + 1)")), modifiers: [.command])
            }
            Divider()
        }
    }
}
