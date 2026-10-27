<img src="docs/images/icon.png" width="96" alt="Organized Stickies icon: a sticky note tucked into a folder">

# Organized Stickies

Sticky notes for the Mac that live in folders on one board instead of scattered across your screen. New notes land in an Inbox, and an on-device sorter suggests where each one belongs. It shows why, and it only suggests when it's confident.

![The board: folders in the sidebar, notes as cards, folder suggestions on Inbox notes](docs/images/board.png)

<p>
<img src="docs/images/board-dark.png" width="49%" alt="The board in dark mode">
<img src="docs/images/folder.png" width="49%" alt="A folder with an untouched note offering Archive">
</p>

- **One board, one folder at a time.** Inbox, your folders, Archive. Each note is a plain Markdown file in `~/Documents/Organized Stickies/`.
- **Suggestions, never auto-moves.** On held-out sample notes, all 10 suggestions shown were right, and 9 of 12 longer notes got one ([evaluation](docs/SORTER-EVAL.md)). Short notes usually get "No clear match", by design.
- **Stale notes surface.** Anything untouched for 14 days or more offers **Archive**.
- **Private and free.** Sorting runs on your Mac with Apple's NaturalLanguage framework. No account, no network.
- **Imports Apple Stickies** as copies. The originals aren't changed.

```bash
./scripts/install.sh
```

Requires macOS 26 and Xcode 26.

**Docs:** [Instructions](docs/INSTRUCTIONS.md) · [System design](docs/SYSTEM-DESIGN.md) · [Sorter evaluation](docs/SORTER-EVAL.md) · [File structure](docs/FILE-STRUCTURE.md) · [Prompt log](docs/PROMPTS.md)
