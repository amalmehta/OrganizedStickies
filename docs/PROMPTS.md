# Prompt Log

## 2026-10-26 — Build Organized Stickies from the spec

1. "OrganizedStickies: build this project. Read OrganizedStickies.md in this folder and build what it describes, following its META-INSTRUCTIONS exactly."
   → Read the spec. Ran four question rounds (real need, why not Apple Notes, sorting engine, shape, storage, delivery, look). Measured word counts of the user's Apple Stickies (25 notes, median 14 words), recorded the decisions in the spec, wrote the design doc, then built the app. Testing found and fixed: board window not opening under some launch conditions (moved to an AppKit window), suggestion buttons and the rename field hidden from VoiceOver, arrow keys not reaching the board, first sort taking 9 s for 200 notes (now 4.4 s, parallel), and loud terracotta markers in the sidebar.
2. (Answers in the question widget, summarised: pains are clutter, can't find, stale notes; build a new app that imports Stickies; on-device suggestions; one board window ("it should be within a container / backboard"), notes in a neat grid; one folder at a time; stale = 14 days, suggest only; plain files in real folders; "Muted paper" look; local build for macOS 26; public GitHub repo; import copies only; approved the macOS automation prompt for UI tests; declined screen control for hands-on testing.)
   → Each answer is recorded under DESIGN DECISIONS in the spec.
