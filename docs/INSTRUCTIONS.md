# Organized Stickies: Instructions

## Install

Needs macOS 26 or later and Xcode 26 (with [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`).

```bash
./scripts/install.sh
```

This builds a Release copy, quits any running copy, replaces `/Applications/Organized Stickies.app` and opens it. The build is signed for this Mac only, so on another Mac Gatekeeper warns the first time (right-click › Open).

Try it without touching your notes:

```bash
open "/Applications/Organized Stickies.app" --args -demo
```

Demo mode opens a fresh temporary copy of the sample notes on every launch.

## Use

| To… | Do this |
|---|---|
| Write a note | **⌘N**, or the pencil button. New notes go to the folder you're looking at (Inbox from Archive). The first line is the title. |
| Stop editing | **Esc**, or click empty board space. A blank note disappears by itself. |
| Edit a note | Click it, or select it with the arrow keys and press **Return**. |
| Switch folders | Click in the sidebar, or **⌘1**…**⌘9**. **Tab** moves from the sidebar into the board. |
| File a note | Drag it onto a folder in the sidebar, or **⌥⌘1**…**⌥⌘9** (Note › Move To). |
| Reorder | Drag a card onto another card. |
| Sort the Inbox | Suggestions appear by themselves on Inbox cards. **Move to …** accepts one (**⌘Y** for the selected note); **Move N Suggested** accepts all (**⇧⌘Y**); **×** dismisses. Nothing moves until you click. |
| Archive | **Archive** on a stale note, **⇧⌘E**, or Note › Archive. |
| Delete | **⌘⌫** or right-click › Move to Trash. The file goes to the Finder Trash, so you can get it back. |
| Search | **⌘F**, or the search field. Searches every folder, Archive included. |
| Folders | **⇧⌘N** for a new one. Right-click to rename, recolor, show in Finder or delete (its notes move to Inbox first). |
| Settings | **⌘,**: text size, how many days before "untouched", suggestion strictness, import, sample notes. |
| Import Apple Stickies | Settings › Import, or the button on the first-run screen. Copies only; Apple Stickies isn't changed. Running it twice doesn't duplicate. |
| Feedback | The speech-bubble button at the bottom of the sidebar opens a pre-filled GitHub issue in your browser. |

Your notes live in `~/Documents/Organized Stickies/`, one Markdown file per note and one Finder folder per folder. Edit them in any app; changes appear when you switch back.

## Develop

```bash
cd Core && swift test                       # unit tests (logic, disk, importer, sorter done-criterion)
cd Core && swift run -c release sorter-eval --details --write ../docs/SORTER-EVAL.md   # re-fit and report the sorter
xcodegen generate && xcodebuild -project OrganizedStickies.xcodeproj -scheme OrganizedStickies -derivedDataPath build test   # UI tests
swift scripts/make_icon.swift               # redraw the icon
```

UI tests drive the real app in demo mode. macOS asks once for permission to let them control the app ("automation mode").

## Manual review checklist

Things tests can't judge. Check these after any visible change:

- [ ] **Feel**: typing in a card keeps up with fast typing, with no lag or dropped characters (try a 400-word note).
- [ ] **Smoothness**: scrolling Inbox with 40+ cards holds the frame rate. Moving a card animates without a jump. Switching folders has no flicker.
- [ ] **First open**: the welcome screen says what to do, and Import shows a clear result line.
- [ ] **Real notes**: after importing your Apple Stickies, are the suggestions you see right? Count wrong ones. If more than about 1 in 10 are wrong, switch Settings › Sorting to Careful and tell me which ones.
- [ ] **Stale**: does 14 days flag notes you'd actually archive?
- [ ] **Dark mode**: cards, chips and the sidebar stay quiet and readable.
- [ ] **Text size**: Extra large still fits titles and buttons on cards.
- [ ] **VoiceOver** (⌘F5): cards read as title, body and age, and **Move to …** is reachable.
- [ ] **Finder**: rename a note's first line, and its file name follows. Edit a file in TextEdit, switch back, and the card updates.
- [ ] **Quit mid-typing** (⌘Q right after typing): reopen, and the text is there.
