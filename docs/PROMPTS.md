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

## 2026-10-28 — Making the glass real

1. "it should feel translucent in the backend ... i.e. "one with the computer""
   → Built a capture made of only the app window and a striped stand-in wallpaper, and found the board let nothing through: every older frosted material draws as flat grey on macOS 26, and earlier window-only captures couldn't have shown it. Moved the whole window to Liquid Glass over a see-through window, and checked light and dark over the stripes.
2. "yeah its better" / "but the sticky should be a bit more oqaue"
   → Cards were already solid, so took it to mean the glass: doubled the paper wash over it (15% → 30%) and rechecked light and dark.
3. "Review the uncommitted changes, commit them in sensible commits with clear messages, and push. Don't commit secrets or build output."
   → The changes had already been committed as one commit; checked it for secrets and build output, ran the attribution checks, and pushed.
4. "commit and push"
   → Committed the new ProjectForge shortcut files and pushed.
5. "the create new sticky button should be bigger"
   → The toolbar sets the button's height, so it got wider instead: "New Note" now shows beside the icon. A larger control size changed nothing, so it was left out.

## 2026-10-29 — Starter folders, and Archive for old Inbox notes

1. "0,5,5"
   → Looked at the app, the code and the real library (counts and dates only): 2 notes, no folders, nothing imported, while Apple Stickies had 8 notes edited this month. Listed 5 things to add and 5 to improve, ranked.
2. "Build add #1 (suggested starter folders) and improve #1 (old Inbox notes get the Archive offer)."
   → Built the Archive fix (suggestion first, then the stale offer, then "No clear match"). For starter folders, the first version grouped notes badly; measuring showed why: comparing two notes with the sentence model was barely better than a coin flip (AUC 0.55–0.60). Tried the contextual model (0.65), the on-device Apple Intelligence model (not available on this Mac) and summed word vectors (0.74), and built on word vectors. Fitted on 70 sample notes, checked on 22 held out: 5 of 6 grouped notes right there. Also measured, and reported, that the sorter's later suggestions into these young folders were right only about half the time.
