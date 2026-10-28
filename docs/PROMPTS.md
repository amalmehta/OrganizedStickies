# Prompt Log

## 2026-10-26 — Build Organized Stickies from the spec

1. "OrganizedStickies: build this project. Read OrganizedStickies.md in this folder and build what it describes, following its META-INSTRUCTIONS exactly."
   → Read the spec. Ran four question rounds (real need, why not Apple Notes, sorting engine, shape, storage, delivery, look). Measured word counts of the user's Apple Stickies (25 notes, median 14 words), recorded the decisions in the spec, wrote the design doc, then built the app. Testing found and fixed: board window not opening under some launch conditions (moved to an AppKit window), suggestion buttons and the rename field hidden from VoiceOver, arrow keys not reaching the board, first sort taking 9 s for 200 notes (now 4.4 s, parallel), and loud terracotta markers in the sidebar.
2. (Answers in the question widget, summarised: pains are clutter, can't find, stale notes; build a new app that imports Stickies; on-device suggestions; one board window ("it should be within a container / backboard"), notes in a neat grid; one folder at a time; stale = 14 days, suggest only; plain files in real folders; "Muted paper" look; local build for macOS 26; public GitHub repo; import copies only; approved the macOS automation prompt for UI tests; declined screen control for hands-on testing.)
   → Each answer is recorded under DESIGN DECISIONS in the spec.

## 2026-10-27 — Checking the import, then making it smoother

1. "I'm importing my Apple Stickies now. I'll report how many suggestions were right and wrong."
   → Corrected an earlier claim: the 7 UI tests had last passed just before three small changes. Explained what to count and why folders need a few notes first.
2. "make sure data is stored correctly"
   → Ran the importer on the real Apple Stickies into a throwaway folder, printing counts only: 24 of 24 notes copied exactly, edit dates kept, no duplicates on a second run, Apple Stickies unchanged. Found the real library had no imported notes yet.
3. "I've imported. Check my library and rerun the UI tests."
   → The library still had only one typed note, and macOS logged no attempt to read Stickies. All 7 UI tests passed on the shipped build.
4. "After clicking Import it said:" (the message ended there)
   → Asked for the app's exact wording. Still open.
5. "find 10 more things to make this sexy smooth / make the background translucent so it feels "one" with the computer"
   → Pushed back on what glass costs (the board's color follows what's behind it). Built a frosted-glass board, proposed ten changes, and asked which to build. Answers: glass "More see-through"; build cards that fit their text, notes that fly to their folder, and suggestions that appear note by note. While measuring, found word analysis made a new tagger per note: reusing them is about 13× faster.
