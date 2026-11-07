# Setup

End-to-end: get the CLIs installed and authed, build your expert's notebook in NotebookLM, then wire
the coach into Claude Code. Budget ~30–45 min the first time (most of it is NotebookLM ingesting
videos).

## 0. Prerequisites

- **Python 3.9+** and **`uv`** (`curl -LsSf https://astral.sh/uv/install.sh | sh`).
- **A NotebookLM account.** Free works but caps at **50 sources per notebook**; **Plus/Pro allows
  300** — strongly recommended for a real catalog. Same Google account will be used for both CLIs.
- **Claude Code** (for guided setup + the interview). The skills also work in other agents that
  read `SKILL.md`, but the setup hook is Claude-Code-specific.

## 1. Install the two CLIs

NotebookLM has **no public API**. Two community tools automate it via your Google session — they are
separate projects with separate logins:

```bash
# Read side — queries + source listing (this is what ask_cited.py calls)
uv tool install notebooklm-mcp-cli            # gives you `nlm`

# Write side — create notebooks + bulk-load a channel
uv tool install "notebooklm-py[browser]"      # gives you `notebooklm`
uvx --from "notebooklm-py[browser]" playwright install chromium
```

## 2. Authenticate (two logins, same Google account)

```bash
nlm login           # read side. Borrows cookies from a Chromium browser you're signed into.
                    # SESSION IS SHORT (~20 min) — you'll re-run this when queries fail.
notebooklm login    # write side. Opens its own Chromium for a fresh Google login. Lasts weeks.
```

Verify: `nlm notebook list` (an empty `[]` means authed but no notebooks yet).

> If `nlm` queries later fail with **"Authentication expired"**, just run `nlm login` again. This is
> the #1 gotcha — see [LIMITATIONS.md](LIMITATIONS.md).

## 3. Create the notebook and load Engineering Funda's channel

You build your own notebook — you can only query notebooks your own account owns. One command does
all of it (scrape → create notebook → save its id to `.notebooklm-id` → load → count loaded/failed):

```bash
bash setup.sh load --count 50      # free plan; use up to 300 on Plus/Pro
```

Or by hand — `scripts/load_channel.py` is included; swap the channel URL for any other expert:

```bash
# a) scrape the channel's videos (stdlib only)
python3 scripts/load_channel.py scrape \
  --channel "https://www.youtube.com/@EngineeringFunda" \
  --output /tmp/ef-videos.json

# b) create the notebook — note the id in the JSON it prints
notebooklm create "Engineering Funda - Study Coach" --json

# c) load the newest 300 lectures (Plus/Pro). Keep concurrency LOW to avoid failed "red" rows.
uv run --with "notebooklm-py[browser]" python3 scripts/load_channel.py load \
  --videos /tmp/ef-videos.json \
  --notebook <notebook-id> \
  --count 300 --concurrency 1
```

> `scripts/load_channel.py` ships in this repo (vendored from the
> [notebooklm-coach](https://github.com/artemnovitckii/notebooklm-coach) base skill, MIT).
> On a **free** account use `--count 50`. After loading, sanity-check how many ingested cleanly:
> ```bash
> nlm source list <notebook-id> --json | python3 -c "import json,sys;d=json.load(sys.stdin);r=[s for s in d if s['title'].strip().startswith('http')];print(f'good {len(d)-len(r)}  red {len(r)}')"
> ```

## 4. Point the coach at your notebook

`bash setup.sh load` already saved the id to `.notebooklm-id` — skip ahead. If you loaded by hand,
tell the coach which notebook to use (there's no built-in default):

```bash
nlm notebook list                       # copy your notebook's "id"
cp .notebooklm-id.example .notebooklm-id
# edit .notebooklm-id → paste just the id on line 1   (or: export NOTEBOOKLM_ID=<id>)
```

Test that citations are real:

```bash
python3 scripts/ask_cited.py "How does Engineering Funda explain the working of a PN junction diode?"
# → answer + [N] 📎 Real Lecture Title + the verbatim passage quoted
```

## 5. (Only for a different expert) Customize the persona

For Engineering Funda, the committed `CLAUDE.md` is ready to go. To adapt to another expert:

```bash
cp CLAUDE.md.template CLAUDE.md
```

Edit `CLAUDE.md`: set the expert's name, the domain (study coaching, training, product, cooking…),
where your personal data lives, and the interview spine. The **everything-cited rule and the
interview flow are already written in** — don't loosen them.

## 6. Add your own data (optional but recommended)

The coach is best when it sequences *your* syllabus against the channel's course order. Drop your
data under `data/` (gitignored) and describe it in `CLAUDE.md` (paths, columns). The Engineering
Funda example uses a syllabus CSV (`Subject,Topic,Exam Weight %,Status,Confidence 1–5`) plus an
optional study log; adapt to whatever your domain produces.

## 7. Use it in Claude Code

- **Open the folder in Claude Code.** The `SessionStart` hook tells Claude whether a notebook is
  loaded yet: if not, it guides you through setup; if so, ask anything or say **"interview me"**.
- **Enable the hook:** Claude Code reads `.claude/settings.json` from the project. The first run may
  prompt you to approve the hook command — approve it. (Hooks run local shell, so review
  `.claude/hooks/onboard.sh` first — it only echoes a one-line status based on `.notebooklm-id`.)
- **Skill location:** project skills live in `.claude/skills/`. To make the coach available in every
  project instead, copy `.claude/skills/coach-interview/` into `~/.claude/skills/`.

That's it. Say "interview me" and every claim it makes will trace to a real lecture. If something
isn't covered, it'll tell you — that's the feature, not a bug.
