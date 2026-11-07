---
name: setup
description: Use when the user wants to install or set up this coach, log in to NotebookLM, or load a YouTube channel ("install it", "set me up", "Load the 100 most recent videos from @EngineeringFunda"), or when .notebooklm-id is missing. Walks install → two logins → load channel → ask.
---

# Setup: install → log in → load → ask

Four stages. Stop after each one and let the user drive the next.

## 1. Install (you run this)

```bash
bash setup.sh install
```

Use a long Bash timeout (600000) — the first Chromium download can take a few minutes. Show the
user the report it prints (it ends with the two login commands), then **stop and wait**.

## 2. Log in twice (the USER runs these)

**Never run `nlm login` or `notebooklm login` yourself** — they open a browser and wait for a Google
sign-in, so a tool call hangs. The user runs them in a terminal (Claude desktop app: the Terminal
panel; Claude Code CLI: type them after a `!`), **same Google account both times**:

```
nlm login          # read side  — the coach asks the notebook questions
notebooklm login   # write side — setup creates the notebook and adds videos
```

When they say they're done, confirm with `bash setup.sh check` (exit 0 = both logins work).

## 3. Load the channel (you run this, when the user asks)

Default channel is `https://www.youtube.com/@EngineeringFunda`. Use the number the user asks for.
If they didn't give one, ask which NotebookLM plan they're on — each notebook holds **50 sources on
free, 300 on Plus/Pro** — and use that.

```bash
bash setup.sh load --count N                        # Engineering Funda
bash setup.sh load --count N --channel <url> --title "<name>"   # a different expert
```

- It finds every video on the channel, creates a **new** notebook, saves its id to `.notebooklm-id`,
  adds the N most recent videos one at a time, then prints how many loaded and which failed.
- Loading takes a while (one video at a time on purpose). **Run it in the background** (Bash
  `run_in_background`) so it doesn't hit the tool timeout, and report back when it finishes.
- Report: how many loaded OK, and list any failed ones. If the final check says the `nlm` login
  expired, ask the user to run `nlm login` again, then run `bash setup.sh verify`.
- If `.notebooklm-id` already exists, a notebook is already loaded — `load` skips. Only pass `--new`
  if the user explicitly wants another notebook.

## 4. Ask

The coach is ready. Answer any engineering question with `python3 scripts/ask_cited.py "<question>"`
and cite only the titles and quotes it prints (see CLAUDE.md). For a personal study plan, run the
`coach-interview` skill.

## Notes
- The `nlm` login lasts ~20 min. On an auth error, the user re-runs `nlm login`.
- Prefer a terminal? `bash setup.sh` runs every stage interactively, logins included.
- Different expert: load with `--channel`/`--title`, then `cp CLAUDE.md.template CLAUDE.md`.
