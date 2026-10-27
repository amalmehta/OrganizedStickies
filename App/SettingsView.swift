import SwiftUI
import StickiesCore

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettings().tabItem { Label("General", systemImage: "gearshape") }
            SortingSettings().tabItem { Label("Sorting", systemImage: "arrow.triangle.branch") }
            ImportSettings().tabItem { Label("Import", systemImage: "square.and.arrow.down") }
        }
        .frame(width: 520)
        .tint(Theme.accent)
    }
}

private struct GeneralSettings: View {
    @Environment(Board.self) private var board
    @AppStorage("textSize") private var textSize: TextSize = .standard
    @AppStorage("staleDays") private var staleDays = Staleness.defaultDays

    var body: some View {
        Form {
            Section {
                LabeledContent("Notes folder") {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(board.root.path(percentEncoded: false).replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                            .textSelection(.enabled)
                            .foregroundStyle(Theme.quiet)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Button("Show in Finder") { board.revealInFinder() }
                    }
                }
                Text("Each folder is a real folder and each note a plain text file, so Spotlight and Time Machine see them. Edits made in another app show up when you switch back.")
                    .font(.caption)
                    .foregroundStyle(Theme.quiet)
            }
            Section {
                Picker("Text size", selection: $textSize) {
                    ForEach(TextSize.allCases) { Text($0.label).tag($0) }
                }
            }
            Section {
                Stepper(value: $staleDays, in: Staleness.allowedDays) {
                    LabeledContent("Suggest archiving after", value: "\(staleDays) days untouched")
                }
                .onChange(of: staleDays) { _, _ in board.dismissedStale = [] }
                Text("A note nobody has edited for this long gets an Archive button. It's never moved for you. 14 days is a starting guess: raise it if good notes get flagged, lower it if old ones pile up.")
                    .font(.caption)
                    .foregroundStyle(Theme.quiet)
            }
        }
        .formStyle(.grouped)
        .frame(height: 380)
    }
}

private struct SortingSettings: View {
    @Environment(Board.self) private var board
    @AppStorage("sortStrictness") private var strictness = 0.0

    var body: some View {
        Form {
            Section {
                Picker("Suggestions", selection: $strictness) {
                    Text("Careful").tag(0.1)
                    Text("Balanced").tag(0.0)
                    Text("Eager").tag(-0.1)
                }
                .pickerStyle(.segmented)
                .onChange(of: strictness) { _, _ in board.scheduleSort() }
                Text(strictnessHelp)
                    .font(.caption)
                    .foregroundStyle(Theme.quiet)
            }
            Section("How sorting works") {
                HowSortingWorks()
                Text("**How well it does (an estimate):** on 22 invented sample notes it hadn't seen, Balanced made 10 suggestions and all 10 were right, and 9 of 12 longer notes got one. That's a small, made-up set, so 10 out of 10 is consistent with a true rate as low as about 72%. Your own notes are the real test. If suggestions start being wrong, choose Careful.")
                    .font(.callout)
                    .foregroundStyle(Theme.quiet)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .formStyle(.grouped)
        .frame(height: 520)
    }

    private var strictnessHelp: String {
        switch strictness {
        case let s where s > 0: "Fewer suggestions, more often right."
        case let s where s < 0: "More suggestions, more often wrong. Check each before you click."
        default: "Fitted on sample notes to show a suggestion only when it's very likely right."
        }
    }
}

private struct ImportSettings: View {
    @Environment(Board.self) private var board
    @State private var status: String?
    @State private var working = false

    var body: some View {
        Form {
            Section {
                HStack {
                    Button {
                        working = true
                        Task { status = await board.importFromAppleStickies(); working = false }
                    } label: { Label("Import from Apple Stickies", systemImage: "square.and.arrow.down") }
                    if working { ProgressView().controlSize(.small) }
                }
                Text("Copies every Apple Stickies note into Inbox as plain text, keeping its last-edited date. Apple Stickies isn't changed, and notes already copied are skipped. Colors and formatting aren't kept: here, color shows the folder. macOS may ask once to let this app read Stickies' data.")
                    .font(.caption)
                    .foregroundStyle(Theme.quiet)
                if let status {
                    Text(status).font(.callout)
                }
            }
            Section {
                Button {
                    working = true
                    Task { await board.addSampleNotes(); status = "Added sample notes: 6 folders, an Inbox to sort, and a few old notes."; working = false }
                } label: { Label("Add Sample Notes", systemImage: "rectangle.stack") }
                Text("Invented notes in six folders plus an Inbox to sort, so you can try everything before using your own. They're ordinary files, so delete them like any note.")
                    .font(.caption)
                    .foregroundStyle(Theme.quiet)
            }
        }
        .formStyle(.grouped)
        .frame(height: 320)
        .disabled(working)
    }
}

struct FeedbackView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Feedback")
                .font(.system(size: 19, weight: .semibold, design: .serif))
            Text("What worked, what got in the way, what you expected to happen. It opens as a GitHub issue in your browser, and nothing is sent until you press Submit there.")
                .font(.callout)
                .foregroundStyle(Theme.quiet)
                .fixedSize(horizontal: false, vertical: true)
            TextEditor(text: $text)
                .font(.body)
                .frame(height: 140)
                .scrollContentBackground(.hidden)
                .padding(6)
                .background(Theme.paper(.paper), in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.hairline))
                .accessibilityLabel("Feedback text")
            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Open in Browser") {
                    var c = URLComponents(string: "https://github.com/amalmehta/OrganizedStickies/issues/new")!
                    let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
                    c.queryItems = [
                        .init(name: "title", value: "Feedback: " + String(text.prefix(60))),
                        .init(name: "body", value: text + "\n\n— Organized Stickies \(version), macOS \(ProcessInfo.processInfo.operatingSystemVersionString)"),
                    ]
                    if let url = c.url { NSWorkspace.shared.open(url) }
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 440)
    }
}
