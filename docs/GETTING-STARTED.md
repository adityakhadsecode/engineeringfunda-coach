# Getting started

No coding needed. Two easy paths — pick one.

## Easiest: let Claude do it

1. Make a new, empty folder (e.g. `ai-engineering`) and open it in **Claude Code** (*Open Folder* in
   the app, or `claude` in a terminal inside it).
2. Paste the repo link and ask Claude to install it:
   ```
   https://github.com/adityakhadsecode/engineeringfunda-coach — install this
   ```
   Claude copies the coach into your folder and installs the tools.
3. **Log in twice** — same Google account both times. Each opens a browser, so run them yourself in
   a terminal (in the Claude app: the Terminal panel):
   ```bash
   nlm login
   notebooklm login
   ```
4. **Load Engineering Funda's channel** — tell Claude:
   ```
   Load the 50 most recent public videos from https://www.youtube.com/@EngineeringFunda
   ```
   It takes a few minutes; Claude reports how many loaded and which failed.
5. **Ask it anything** — *What's the difference between a BJT and a MOSFET?* — or say
   **`interview me`** for your own study plan (drop your syllabus in the folder first).

## Or: one command in a terminal

From inside the folder (after cloning the repo into it):

```bash
bash setup.sh
```

It installs everything, opens the two Google logins, loads Engineering Funda's channel, saves your
notebook id, and runs a citation test. Press Enter to accept the defaults. When it finishes, open
the folder in Claude Code and ask it anything.

---

### The two things to know

- **You need a Google account** (NotebookLM) and **Claude Code**. Free NotebookLM holds 50 videos
  per notebook; Plus/Pro holds 300 — load that many at most.
- **The NotebookLM login lasts ~20 min.** If the coach ever says "authentication expired," just run
  `nlm login` again. That's normal.

Want the manual, step-by-step version instead? See [SETUP.md](SETUP.md). Things that can break are
in [LIMITATIONS.md](LIMITATIONS.md).
