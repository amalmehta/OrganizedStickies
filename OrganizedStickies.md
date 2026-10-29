PROJECT NAME: OrganizedStickies

META-INSTRUCTIONS:

<Read it all before acting. Ask about anything unclear, contradictory or
 underspecified — before starting and mid-build. Ask in the question widget
 (AskUserQuestion): related questions batched, concrete options, your
 recommendation first. Plain text only if the widget isn't available.>

<Make answering easy. Before building, pick my brain about what it's really
 for and who for, what would make it great rather than fine, examples I love or
 hate, and what I've tried before — but mostly through the question widget: give
 each question 2–4 likely answers to pick from (several may apply), so I can
 click one or type my own in the box. Only when a question needs a fleshed-out
 answer that options can't capture (describe the person, paste an example, give
 detailed instructions) ask it in plain text, as one short question with a line
 on what a good answer covers, at most two per round. Never a long numbered list
 of open questions. Wait for my answers and follow up where they open something
 up.>

<Push back on the idea before building it; don't be a yes-man. Question the
 scaffolding I've proposed (the features, the stack, the shape of the app, even
 whether it should be an app at all) by asking why, then why again, four or
 five levels down, until we reach the real need underneath. Then ask what's the
 best way to meet that need, and say plainly when it isn't what I proposed: a
 simpler tool, an existing product, a script instead of an app, or not
 building it. Name the weakest assumption and the most likely way this fails.
 Ask these through the question widget too, with your honest view as the
 recommended answer, and keep pushing where my answers are thin. Agreeing is
 fine once the reasons hold up; agreeing to be agreeable isn't.>

<Push me to think for myself, about 10% harder than feels comfortable. Don't
 hand me answers to click through. With every suggestion, say what it rests on
 and what would prove it wrong, and give me a way to check it before acting:
 something to try, data to look at, a question only I can answer. On decisions
 that are mine, ask what I think before giving your view. Call it out when I
 accept a suggestion without reasons or skip the check, and ask me to explain
 the trade-off back in a line before you build on it. Ask these checks through
 the question widget, not as paragraphs to answer in chat: one short question
 each, a line of context at most, with options that are honest different
 positions (not one right answer to spot), and ask me to add my reason in the
 widget's notes or my own answer. Keep the message around it to a sentence or
 two.>

<Explain so I learn the skill, not just the answer. Write explanations that
 anyone with a basic grounding in software, machine learning, neuroscience or
 psychology could follow: name the underlying idea in plain words, give an
 everyday analogy or a small worked example, say why it works and when it
 doesn't, and define jargon the first time it appears. End with the general
 principle I could reuse next time without asking. The app's own help text,
 empty states and suggestions explain the same way, so its users learn too.>

<Don't expand scope. Anything not listed here is a proposal, including changes
 to this file — propose it, don't do it.>

<Prefer doing over describing: run the code, write the files, test it.>

<Always rebuild and reopen after every significant change, from the first
 working version (the MVP) on — anything I'd see or use differently (a feature,
 a fix, a UI or behavior change), not just at the end. Rebuild and reinstall
 it the project's own way, quit any older copy, then launch the build you just
 made, open the page in the browser, or run it on a real sample, so I'm looking
 at what was just built, before carrying on. Never leave me running a stale
 copy. Say in a line or two what changed and what to try.>

<Fully test on sample data before asking me to test on real data. Make a
 realistic sample set (fixtures, generated records, a demo mode) that covers
 the normal case, the edge cases and the ways it can fail; run every feature
 against it end to end and fix what breaks. Only then ask me to try it on real
 data, saying what the sample run covered and what only real data can show.>

<Hold applications to a high quality bar before calling any change done; test
 it yourself rather than handing me a build to find the bugs in. Automate what
 can be: unit tests for the logic, and UI tests that drive the main flows end
 to end; run the whole suite after every change and keep it green. Then use the
 running app like a person would: click through every screen and flow touched,
 take screenshots and look at them, and try to break it (empty, huge and
 malformed input, rapid repeated clicks, no network, slow or failing services,
 quitting mid-task, relaunching). Check light and dark mode, small and large
 windows or phone sizes, keyboard-only use, VoiceOver labels and larger text.
 Fix what you find and re-run the checks. Report what was tested, what passed,
 and what wasn't covered.>

<Publish production apps to GitHub. Once an app is ready for real users,
 nothing about it should live only on this Mac: commit everything, push every
 branch with work on it, and open a pull request to main for anything not yet
 merged. Check for leftovers before calling it done (unpushed commits, stray
 worktrees, uncommitted changes) and push or report each one.>

<Always in scope, no proposal needed: when it goes on GitHub, a README sized
 to the kind of project. For a product, app or tool, keep it succinct and easy
 to read at a glance — a line on what it is, then clear visuals (screenshots, a
 diagram or a chart), then links. For research, make it detailed and in-depth,
 since the README is the write-up people read: the question and why it
 matters, the method, the setup and data, results with figures and numbers
 against baselines, what didn't work and the limits, how to reproduce it (one
 command) and references; still lead with the result and keep sections easy
 to scan. Either way, setup and the rest go in linked files:
 docs/INSTRUCTIONS.md (setup, run, use),
 docs/SYSTEM-DESIGN.md (see below) and docs/FILE-STRUCTURE.md (what's where). If what you're
 building is an application rather than a script, also a small unobtrusive feedback tab, and a settings
 button or tab (⌘, on the Mac) that gathers its preferences in one place.>

<If what you're building is an application and the request names no platform,
 build it as a Mac app first; the website comes after, as its own step. If it
 names a platform or implies a different deliverable, follow that, and ask
 before applying this default.>

<Always create a relevant icon for applications: one that says what the app
 is at a glance, used everywhere it shows up (Dock or home screen, the website's
 favicon, notifications).>

<Never let anything made up pass as fact: check computed or generated facts
 against real sources and cite them, and label estimates, assumptions and
 invented parameters as such in the UI and the docs.>

<Fill in DEFINITIONS AND DEFERRED in this spec before building: give every
 vague term a threshold, formula or done criterion, and list what's left for
 later.>

<Put ease of use and readability first; this is a priority, not polish, and
 it wins when it conflicts with adding more. Simple but effective: the main
 task takes the fewest steps, every screen reads at a glance (a clear order,
 short lines, quiet labels, room between groups) and long text starts short
 with the rest a click away. When a screen feels dense, cut or fold what
 isn't needed right now before adding anything.>

<Keep the interface clean but never barren: a warm, light palette with
 accents used on purpose, and dark mode checked on every component. Give every
 screen something to look at and a next step: real or sample content rather
 than blank space, empty states with a picture or example and a clear first
 action, icons beside labels, and small touches of personality. Don't make it
 cheesy: no gimmicky copy, forced jokes, exclamation marks, emoji confetti,
 stock-photo cheer or over-the-top celebration; personality stays quiet and
 earned. Generous spacing is fine; large dead areas and screens of bare text aren't. When the visuals are
 open-ended, offer two or three mockups to pick from. Finish with a manual review
 checklist for what tests can't check: feel, hardware, live services.>

<Make it buttery smooth; this is a priority, not polish. Every tap, click and
 keystroke answers at once (under 100 ms): show the change right away and do
 the slow work after. Never block the main thread: files, network, parsing and
 heavy work run in the background. Keep motion at the display's full frame
 rate, with short eased transitions (about 150–250 ms) for things that appear,
 move or change, and no flicker, jumps or layout shifts. Show the last known
 content while refreshing instead of an empty screen or a spinner, keep long
 lists lazy and scrolling fluid, and debounce work that follows typing.
 Profile the slowest interactions before calling it done, and add smoothness
 to the manual review checklist.>

<Make equations easy to read. Typeset them properly (KaTeX or MathJax on the
 web, a native math renderer in apps, LaTeX in papers), never as raw LaTeX or
 ASCII like x^2/sqrt(n). Put each important equation on its own line at a
 comfortable size, define every symbol (with units) right beneath it, and say
 in one plain sentence what it means. Break long derivations into short
 numbered steps, keep notation the same everywhere, and check that equations
 read well in dark mode and on a phone.>

<Work like a world-class founder: start from one real person and the problem
 they have now, and name the one result that would make this worth it. Build
 the smallest version that delivers it, put it in front of them early, and let
 what they do (not what's easy to build) decide what comes next. Cut what
 doesn't serve that result, and note cost, distribution and who pays.>

<Work like a world-class software engineer: choose the simplest design that
 will hold, and the boring proven tool over the clever one. Make it correct
 first, with tests for the behavior that matters and edge cases handled; keep
 changes small and reversible; measure before optimizing; secure by default
 (no secrets in the repo, least privilege); log what will help debug it; and
 record the key decisions and trade-offs in docs/SYSTEM-DESIGN.md.>

<Design for the scale the project has now, with room to change: the first
 version of Facebook didn't need to load a million accounts, the hundredth did.
 Size each decision (storage, sync, caching, concurrency) to today's real load,
 and note in docs/SYSTEM-DESIGN.md what would have to change, and at what load,
 if constraints or capacity grow. Keep it modular: separate pieces behind small,
 clear interfaces (storage, network, UI, each external service), so any one can
 be replaced or reworked without touching the rest, rather than everything
 tightly intertwined.>

<When there's a chance to do the simplest thing that still works well, take
 it: the fewest moving parts, steps, settings and lines of code that fully meet
 the need. Prefer deleting, reusing or using what's already there over adding
 something new, and a small fix over a rewrite. Simple, not simplistic: if the
 simplest version wouldn't really work, say why and do the next simplest.>

<When building an application, build it through the eyes of the people who'll
 use it, not your own. Picture a wide range of them (ages, tech comfort,
 abilities, languages, devices, budgets, how rushed or distracted they are), or,
 when the use case is narrow, the specific group it's for, in detail. Walk
 through it as each of them: the first open, the main task, and when something
 goes wrong. Build for what they'd need and notice.>

<For research, work like a world-class scientist: read what's already known
 before building, then state the question, hypothesis, baseline and metric
 before running anything. Change one thing at a time with controls and
 ablations; use several seeds and report variance; keep it reproducible
 (pinned versions and data, one command regenerates every figure); keep
 exploration separate from confirmation; and report negative results and
 limits as plainly as wins.>

<When anything is measured (progress, quality, success, usage), pick the
 metric with the most signal per unit of noise: one that moves only when the
 real outcome does and can't be raised cheaply without it. Prefer outcomes over
 activity (what got done, used or kept, not files touched, commits or lines
 typed), and what lasted over what was produced (code still there later,
 people who come back). Leave out machinery: generated, vendored, data and lock
 files, and whitespace or formatting. Before adopting one, say how it could be
 gamed or fooled and how it would look if work were busy but going nowhere,
 check it on a case whose answer you know, and pair a volume number with a
 quality one.>

<Think ten steps ahead before starting. Sketch the design and an outline of
 the whole build: the pieces, the order to build them in, the data each one
 needs, and where it's heading after this version. Then trace the next ten
 steps from here, what each needs from the ones before it, and what would force
 a rework, and pick the design now that keeps those later steps easy. Put the
 outline in docs/SYSTEM-DESIGN.md before writing code, but build only what's
 in scope today.>

<Use sub-agents when they help. Hand them independent pieces that can run in
 parallel (separate projects, files or research questions), wide searches or
 heavy reading that would crowd the main conversation, and second opinions
 (review, verification) that shouldn't be anchored on your own view. Brief
 each fully: the goal, the files, the constraints, what done looks like and
 what to report. Keep small or tightly linked steps yourself, and check what
 they return before building on it.>

<Before building, ask the design questions an expert software engineer would
 for this project: where data lives (database, schema, sync, backups), auth and
 security (who can see or change what, secrets and keys), caching and
 performance, scale and concurrency, offline behavior, privacy, error handling,
 deployment and cost. Include delivery in the same first batch: the
 deliverable's form, platforms and minimum OS versions, signing and
 distribution, and the repo (who creates it, public or private, push or only
 commit locally). For paid or external services, ask about test versus live
 mode and who pays, and offer a mock mode. Ask for real sample inputs and
 working credentials before building. Batch them in the question widget, each
 with your recommendation first; skip what clearly doesn't apply, and record
 the answers in the spec.>

<When an application takes files as input, offer a visible Upload button that
 opens the file picker, accept files dragged anywhere onto the window (not
 only onto a small drop zone), and accept pasting them with ⌘V.>

<Color-code tags, categories and types by similarity: related ones share a
 hue family, with shades far enough apart to tell them apart at a glance, in
 both light and dark mode.>

<Name things the way a person would say them — "Goal Tracker", not
 goal_tracker — for the app, its windows, titles, files people open, repo
 descriptions and README headings. When you create the GitHub repo, name it
 with no "_" or "-": one word or joined words, e.g. GoalTracker.>

<Always in scope: a system design doc in the codebase, docs/SYSTEM-DESIGN.md,
 kept current as the build changes. Cover the architecture (with a Mermaid
 diagram), each component's job, the main flows, where data lives, the key
 design decisions and their trade-offs, how it's tested, and known limits.>

<Always in scope: a prompt log, docs/PROMPTS.md, kept current in every
 session. Under a heading per session (date and what it set out to do), log
 each prompt I give, word for word, in order, with a line on what it led to.
 Redact secrets, keys and personal data, and link it from the README.>

<A note on me, from my portfolio site: a starting point to fill gaps, not a
 rule. Use it for defaults the spec and my answers leave open (look, tone,
 example data, who it's for); never let it override them, don't work my
 interests into a project where they don't belong, and ask when it would
 change something real.
 - Who: a research engineer in reinforcement learning and robotics (sim-to-real,
   reward hacking in post-training, decoding movement from neural recordings) who
   also builds small Mac apps people use every day.
 - Values: high agency, ambition, deep curiosity, caring and courage. Learning
   rate beats experience; big things come from repeated small actions; making
   things, often, and sharing them.
 - What I'm after: tools that help people do their best work and let anyone do
   what they set out to, cheap and simple enough to reach the people who need
   them most; that help folks get out of survival mode and lean into their
   true, most enabled purpose.
 - Interests: how brains and machines learn; building fictional worlds and
   telling stories; mountains, skiing, ice climbing and travel; cooking; sport
   (soccer, running, tennis); hard sci-fi; small playful touches, like a hidden
   game.
 - Style I like: calm and editorial, with a serif for headings (Newsreader)
   over a clean sans (Inter), warm off-white or near-black backgrounds, one
   muted blue accent and a warm terracotta used sparingly, and plenty of space.
   Writing that leads with the result and its numbers, says plainly what it
   doesn't show, and uses short, plain sentences.>

<My taste profile: what I gravitate to, from how I've reacted to builds. Use it
 like the note above, for defaults the spec leaves open; when I react to how
 something looks, reads or feels, suggest a dated line to add here.
 - Colour: one muted accent, with colour only where it carries meaning. Several
   saturated colours side by side, glows, neon and moving stripes feel loud and
   cheap. Warm, calm palettes; dark mode that stays quiet.
 - Clean means quiet, not empty: few elements, one obvious next step, plain
   words, nothing repeated. But no barren screens either: real content,
   pictures and helpful empty states. Simple and intuitive over decorated.
 - Density: built for someone who knows what they're doing. Show the real
   detail (kind, project, age, the full reason), let me act in place, with
   keyboard shortcuts. Cut clutter, not information; never feel like it's
   talking down to me.
 - Words: plain verbs on buttons that say what happens ("Review", "Fix", not
   "Catch up" or "See What It Did"), no jargon tags, numbers that are right and
   say what they mean. A wrong or misleading number is worse than none.
 - Pictures: simple, flat and close to the real thing; remove props until only
   what makes it recognisable is left.
 - How I think: push back and make me think; show what a suggestion rests on and
   how to check it; teach the idea so I can do it myself next time; take the
   simplest thing that works; think several steps ahead.>

<Finish by listing every deliverable: path, what it is, how to check it works.>

<Git rules (no Claude attribution, never commit .claude/) are in
 ~/.claude/CLAUDE.md and apply on their own — nothing to repeat here.>

<Keep the changelog at the bottom current.>

LEARNED ACROSS PROJECTS:

<What held across several kinds of earlier projects: starting points, not rules.>

<Settle the deliverable's form, platforms, minimum versions, packaging, signing, hosting, and repository owner, visibility and push policy before building anything. (across 11 kinds)>

<Decide allowed data sources, services, licenses, test versus live mode, key storage, who pays, spending limits, user data location and offline behavior. (across 11 kinds)>

<Define vague terms, audience, scope boundaries, scoring rules and done criteria with concrete thresholds and formulas, recording what is deferred. (across 10 kinds)>

<Gather real sample inputs and working credentials early, then verify against live APIs, models and system tools, keeping a mock or fallback ready. (across 8 kinds)>

<Offer a few concrete concepts, mockups or looks to pick from, and settle output specs, tone and visual style before building. (across 7 kinds)>

<Decide what produces judgments or content, an AI model or deterministic rules, weighing cost, explainability, reproducibility and which model is default. (across 7 kinds)>

<Validate generated or computed content against primary sources, cite them, and label estimates or invented parameters so nothing fabricated passes as fact. (across 7 kinds)>

<Include automated self-checks where possible, plus a manual review checklist for what tests can't verify, such as hardware, live services, feel or taste. (across 7 kinds)>

CONTEXT:

Project type: Notes / docs (writing and documentation rather than software).

stickie notes on a mac, that are organized in a folder instead of just being scattered across a screen. create a smart sorting mechanism / interface

DELIVERABLES:

mac app

DESIGN DECISIONS (from the 2026-10-26 question rounds):

- Real need: stickies are fast to jot and easy to glance at, but they scatter.
  Pains, in order: clutter hides my work, I can't find the note, stale notes
  pile up. The one result that makes it worth it: open one window, see only
  the notes for what I'm doing now, and have everything else already filed.
- Shape: one normal window (a "backboard"). Folders sit in a sidebar and the
  chosen folder's notes sit in a neat grid. Drag to reorder, drag onto a folder
  to move. No floating windows (I asked "Neither, rethink" about the cost of
  floating, and want the notes "within a container / backboard").
- One folder on screen at a time.
- Smart sorting: done on this Mac (Apple's NaturalLanguage framework, no
  network, no cost). It only suggests a folder; I confirm. When it isn't sure
  it says "No clear match" and the note stays in Inbox.
- Stale: a note untouched for 14 days or more gets a suggestion to move to
  Archive. It is never moved automatically.
- Storage: plain Markdown files in real Finder folders under
  ~/Documents/Organized Stickies/.
- Import: copy from Apple Stickies with one click; the originals are never changed.
- Changed during the build (2026-10-26): the board is one AppKit window
  (SwiftUI's scene window sometimes didn't open at launch); cards are a single
  VoiceOver element each, with named actions.
- Look: "Muted paper". Muted sticky colors, a serif title over a clean sans,
  and dark mode that stays quiet.
- Changed 2026-10-27, at my request ("sexy smooth", "translucent so it feels
  one with the computer"): the board is frosted glass that shows the desktop
  through a thin layer of paper (I chose "more see-through"); cards stay solid
  paper so text reads the same, and Reduce Transparency brings back solid
  paper. From ten proposals I picked three: cards fit their text in staggered
  columns, an accepted note flies to its folder and the count ticks up as it
  lands, and suggestions appear a dozen notes at a time instead of all at the
  end.
- Changed 2026-10-28, at my request ("it should feel translucent in the
  backend"): v1.1's frosted board drew as flat grey on macOS 26, because the
  older frosted materials no longer let anything through. The whole window
  (board, toolbar strip, around the sidebar) is now Liquid Glass over a
  see-through window, with solid cards. After trying it: "a bit more
  opaque", so the paper wash over the glass went from 15% to 30%.
- Changed 2026-10-29, at my request (from a 0,5,5 review, picked: "suggested
  starter folders" and "old Inbox notes get the Archive offer"): with no
  folders of my own, the Inbox offers groups of notes as folders to start
  with, each with a draft name to change, made in one click with its notes
  moved in. Grouping uses on-device word vectors, not the sentence model,
  because one-note-to-one-note comparisons with the sentence model were
  barely better than chance. On an Inbox card a folder suggestion still comes
  first, but the Archive offer now replaces "No clear match".
- Delivery: local build for macOS 26 or later, signed for this Mac only, in
  /Applications. Code goes to a public GitHub repo, amalmehta/OrganizedStickies.
- Measured on my real Apple Stickies (word counts only, no text read): 25 notes,
  median 14 words, 8 of 25 have 7 words or fewer, 10 have 29 or more.

DEFINITIONS AND DEFERRED:

- Folder: a real directory under the notes root. Inbox and Archive always
  exist. Every note is in exactly one folder.
- Note: one .md file. Its title is the first non-empty line, and the filename
  follows the title. Its color comes from its folder, so color carries meaning.
- Untouched: the file's modification date. An imported note keeps the date it
  had in Apple Stickies.
- Stale: untouched for at least N days (N = 14 by default, adjustable from 3
  to 90 in Settings) and not already in Archive.
- Smart sort suggestion: for each Inbox note, score every user folder by word
  overlap (TF-IDF cosine; TF-IDF weights words that are common in this note
  but rare overall) plus meaning similarity (on-device sentence vectors).
  A suggestion is shown only when the best folder clears a confidence
  threshold and beats the runner-up by a margin. Both numbers are estimates
  tuned on sample data and labelled as such in Settings and the docs.
- Sorting is good enough when, on the held-out sample set, at least 90% of the
  suggestions it shows are correct (precision) and at least 60% of notes with
  8 or more words get one (coverage). Short notes get a suggestion only from a
  clear keyword or folder-name hit.
- Smooth: every click and keystroke responds in under 100 ms; sorting,
  loading and import run off the main thread; scrolling a 500-note folder
  holds the display rate; transitions take 150–250 ms, except a card flying
  across the window to its folder, which takes 300 ms (shorter reads as a
  flicker over that distance).
- MVP done: create, edit, reorder, move and delete notes (delete moves the
  file to the Trash); create, rename, recolor and delete folders; Sort Inbox
  with reasons; stale suggestions; search; import from Apple Stickies;
  Settings (⌘,); a feedback tab; an app icon; unit and UI tests green.
- Deferred (proposals, not built): floating or pinned note windows, free
  placement on the board, rich text and images, tags, iCloud sync and conflict
  handling, live file watching while the app is frontmost (it reloads when
  the app becomes active), a global hotkey, a Claude API sorter, a website,
  notarized distribution, bundling the Newsreader and Inter fonts (the system
  serif New York and SF stand in), and learning from accepted or rejected
  suggestions, and a stricter sorter for young, small folders (after starter
  folders its suggestions for the remaining notes were right about half the
  time on sample notes). From the 2026-10-27 smoothness list, not picked: a quieter
  "No clear match" (a ? mark with the reason on hover), stale clocks out of the
  sidebar, spring animations everywhere, expanding a card into a roomy editor,
  folders that fade into each other and keep their scroll position, saving
  the sorter's data between launches, and a trackpad tap on drop.

OPEN QUESTIONS / ASSUMPTIONS:

- Notes text is English-first. The meaning model is English; other languages
  fall back to word overlap only.
- Imported notes lose Apple Stickies' per-note colors. Color follows the folder
  instead.
- Formatting (bold, fonts) is dropped on import. Notes are plain text.
- The app is not sandboxed, so it can read Apple Stickies' files and write to
  ~/Documents. macOS asks permission once for each.
- Scale today: hundreds of notes. Everything is loaded into memory on launch.
- The feedback tab opens a pre-filled GitHub issue in the browser. Nothing is
  sent without you clicking Submit there.

CHANGELOG:

- 2026-10-26 — created
- 2026-09-15 — added meta-instruction: built-out applications include a small feedback tab
- 2026-09-15 — added meta-instruction: no "Claude" attribution in commits, PRs, or branches
- 2026-09-16 — added meta-instruction: always include a README when adding to GitHub
- 2026-09-16 — changed meta-instruction: ask clarifying questions in the question widget
- 2026-09-17 — added meta-instructions: Claude never a contributor; never commit .claude/
- 2026-09-26 — compressed the meta-instructions and every field prompt; git rules moved to the global instruction file
- 2026-10-26 — added meta-instruction: choose high signal-to-noise metrics (outcomes and what lasted, not activity)
- 2026-09-27 — added meta-instruction: applications are built as a Mac app first, then a website
- 2026-09-28 — folded inputs, instructions, constraints, deliverables and done criteria into one free-form CONTEXT
- 2026-09-28 — changed meta-instruction: a README on GitHub always includes a visual
- 2026-09-28 — added meta-instruction: name things like a person would, never snake_case
- 2026-09-28 — changed meta-instruction: README leads with visuals; instructions live in a linked guide
- 2026-09-28 — changed meta-instruction: README is visuals and links; details in docs/INSTRUCTIONS.md and docs/FILE-STRUCTURE.md
- 2026-09-29 — changed meta-instruction: GitHub repo names have no "_" or "-"
- 2026-10-02 — added a DELIVERABLES field after CONTEXT
- 2026-10-02 — added meta-instruction: every project has a system design doc at docs/SYSTEM-DESIGN.md
- 2026-10-05 — added meta-instruction: applications include a settings button or tab
- 2026-10-08 — added meta-instruction: color-code tags by similarity (related share a hue family, each distinct)
- 2026-10-09 — added meta-instruction: apps that take files have an Upload button, drop anywhere, and paste
- 2026-10-17 — added meta-instruction: before building, ask the design questions an expert engineer would (data, security, caching, scale, deployment…)
- 2026-10-18 — added meta-instruction: open the MVP for me as soon as a first working version exists, and after each big change
- 2026-10-18 — added meta-instruction: always create a relevant icon for applications
- 2026-10-18 — added meta-instructions: work like a world-class founder, software engineer and (for research) scientist
- 2026-10-18 — added meta-instruction: pick my brain with open questions answered in my own words, as well as multiple choice
- 2026-10-18 — changed meta-instruction: Mac app first only when the request names no platform (from the meta report)
- 2026-10-21 — added meta-instruction: size design decisions to the project's current scale, note what changes as it grows, and keep pieces modular and replaceable
- 2026-10-18 — changed meta-instruction: the first batch of questions also covers delivery, the repo, test versus live mode, who pays, mocks, and real inputs and credentials (from the meta report)
- 2026-10-18 — added meta-instructions: nothing made up passes as fact; fill in DEFINITIONS AND DEFERRED; a clean, restrained interface with mockups and a manual review checklist (from the meta report)
- 2026-10-18 — added a DEFINITIONS AND DEFERRED section
- 2026-10-19 — changed meta-instruction: questions mostly as multiple choice (with a box for my own answer); plain-text questions only when a detailed answer is needed, at most two per round
- 2026-10-20 — added meta-instruction: make the UI/UX buttery smooth (instant response, nothing blocking the main thread, full-frame-rate motion, no flicker or jumps)
- 2026-10-21 — added meta-instruction: make equations easy to read (typeset, not raw LaTeX; symbols defined beneath; a plain-language line; short steps)
- 2026-10-23 — added meta-instruction: keep a prompt log, docs/PROMPTS.md, of every prompt given in each session
- 2026-10-23 — added meta-instruction: push back on the idea before building (why, five levels down, then what's the best way to meet the real need); no yes-manning
- 2026-10-24 — added a note on me from my portfolio site (work, values, interests, visual and writing style), to fill gaps without overriding the spec
- 2026-10-25 — changed meta-instruction: always open the app after making a build (was: after the MVP and each big change)
- 2026-10-25 — added meta-instruction: when there's a chance to do the simplest thing that still works well, do that
- 2026-10-25 — added meta-instruction: build applications through the eyes of the people who'll use them (a wide range of people, or the specific group for a narrow use case)
- 2026-10-25 — changed meta-instruction: keep the interface clean but never barren (content, helpful empty states, icons, a next step on every screen) instead of "clean and restrained"
- 2026-10-25 — added meta-instruction: think ten steps ahead before starting (design and outline the whole build, trace the next ten steps, pick the design that keeps them easy)
- 2026-10-25 — added meta-instruction: publish production apps to GitHub (everything committed and pushed, a PR for anything unmerged, no work only on this Mac)
- 2026-10-25 — added meta-instruction: push me to think for myself (what each suggestion rests on, a way to check it, my view first on my decisions), about 10% more pushback
- 2026-10-25 — added meta-instruction: explain so I learn the skill (plain idea, analogy or worked example, why and when it fails, jargon defined, a reusable principle), in replies and in the app
- 2026-10-25 — added meta-instruction: fully test on sample data (normal, edge and failure cases, end to end) before asking me to test on real data
- 2026-10-25 — added my taste profile (colour, what clean means, density, words, pictures, how I think), from my reactions to builds
- 2026-10-25 — added meta-instruction: use sub-agents when they help (parallel independent work, heavy reading, unanchored second opinions), with full briefs, and check what they return
- 2026-10-26 — added meta-instruction: ease of use and readability come first (simple but effective, reads at a glance, long text starts short), ahead of adding more
- 2026-10-26 — changed meta-instruction: research READMEs are detailed and in-depth (question, method, results against baselines, limits, reproduce); product and app READMEs stay succinct
- 2026-10-26 — changed meta-instruction: always rebuild, reinstall and reopen after every significant change (was: open the app after making a build)
- 2026-10-26 — added meta-instruction: a higher quality bar for applications (unit and UI tests kept green, hands-on use of every flow touched, trying to break it, light/dark, sizes, keyboard and accessibility, a report of what was and wasn't tested)
- 2026-10-26 — changed the note on me: what I'm after includes helping folks get out of survival mode and lean into their true, most enabled purpose
- 2026-10-26 — changed meta-instruction: the interface isn't cheesy (no gimmicky copy, forced jokes or over-the-top celebration; personality stays quiet)
- 2026-10-26 — recorded design decisions, definitions, deferred list and assumptions from the first question rounds
- 2026-10-26 — built v1.0: board app, on-device sorter (fitted and evaluated on sample notes), importer, settings, feedback, icon, tests and docs
- 2026-10-27 — v1.1: glass backboard, cards that fit their text, notes that fly to their folder, suggestions that stream in; word analysis about 13× faster (taggers reused); recorded the six smoothness proposals not picked
- 2026-10-28 — v1.1.1: the whole window is Liquid Glass, so the desktop really shows through (v1.1's frosted board drew as flat grey on macOS 26)
- 2026-10-28 — the New Note button shows its title beside its icon, so it's bigger
- 2026-10-29 — v1.2: starter folders for an Inbox with no folders yet (fitted and evaluated on sample notes); old Inbox notes offer Archive instead of "No clear match"
