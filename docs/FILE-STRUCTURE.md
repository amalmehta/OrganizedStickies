# File Structure

```
OrganizedStickies/
├── OrganizedStickies.md        The spec: goals, decisions, definitions, changelog
├── README.md                   What it is, a screenshot, links
├── project.yml                 XcodeGen project (the .xcodeproj is generated, not committed)
├── App/                        The Mac app (SwiftUI + one AppKit window)
│   ├── OrganizedStickiesApp.swift   Entry point, board window (and its undo), menu commands, quit handling
│   ├── Board.swift                  App state: wraps Library, debounced saves, serial disk queue, sorting
│   ├── ContentView.swift            Sidebar + board split view, search, error banner
│   ├── SidebarView.swift            Folders: counts, stale marker, drop targets, rename/color/delete
│   ├── BoardView.swift              The grid, header, starter folders panel, "How sorting works", search results
│   ├── StickyCard.swift             One note: preview, in-place editor, suggestion and stale chips
│   ├── EmptyStates.swift            Pictures and next steps for empty folders and first run
│   ├── SettingsView.swift           ⌘, (General, Sorting, Import) and the feedback sheet
│   ├── Theme.swift                  Muted-paper palette (light and dark), fonts, text sizes
│   ├── Info.plist
│   └── Assets.xcassets              App icon, accent color
├── Core/                       StickiesCore: all logic, no UI (Swift package)
│   ├── Sources/StickiesCore/
│   │   ├── Model.swift              Note, Folder, FolderColor, DiskOp, LibraryIndex
│   │   ├── Library.swift            In-memory truth; every edit returns the DiskOps to apply; undo changes and their reverses
│   │   ├── LibraryLoader.swift      Reads ~/Documents/Organized Stickies into a Library
│   │   ├── NoteDisk.swift           Actor that applies DiskOps in order (write, rename, move, trash, bring back from the Trash)
│   │   ├── NoteNaming.swift         Titles and safe, readable file names
│   │   ├── ColumnPacking.swift      Which column each card goes in (shortest first, kept while you work)
│   │   ├── Sorter.swift             Folder suggestions: word overlap + on-device meaning vectors, streamed in batches
│   │   ├── FolderFinder.swift       Starter folders: groups unsorted notes and drafts their names (word vectors)
│   │   ├── TextAnalysis.swift       Word lemmas (reused taggers, remembered per note), stopwords, nouns, TF-IDF vectors
│   │   ├── Staleness.swift          "Untouched for N days" and age labels
│   │   ├── StickiesImporter.swift   Reads Apple Stickies' .rtfd notes (read only)
│   │   ├── SampleData.swift         Loads/writes the sample notes
│   │   └── Resources/SampleNotes.json   92 invented, labelled notes for demo, tuning and checking
│   ├── Sources/SorterEval/main.swift    Fits sorter and starter-folder numbers and writes docs/SORTER-EVAL.md
│   └── Tests/StickiesCoreTests/         Unit tests + Apple Stickies fixtures
├── UITests/                    XCUITest flows run against demo mode
├── scripts/
│   ├── install.sh              Release build → /Applications, then open
│   └── make_icon.swift         Draws the app icon
└── docs/
    ├── INSTRUCTIONS.md         Install, use, develop, manual checklist
    ├── SYSTEM-DESIGN.md        Architecture, flows, decisions, scale, limits
    ├── SORTER-EVAL.md          Sorter and starter-folder results vs baselines (generated)
    ├── FILE-STRUCTURE.md       This file
    ├── PROMPTS.md              Prompt log
    └── images/                 Icon and screenshots for the README
```
