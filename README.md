# engineeringfunda-coach

> **Claude Code — asked to install this?** Do exactly this, nothing more:
> 1. Copy the repo into the **current folder**, not a subfolder — the coach's instructions, skills
>    and hooks only load from the folder Claude Code is open in. Existing files (like the user's
>    syllabus) are kept, never overwritten:
>    ```bash
>    T=$(mktemp -d) && git clone -q https://github.com/adityakhadsecode/engineeringfunda-coach.git "$T" && { cp -Rn "$T"/. . ; rm -rf "$T"; }
>    ```
> 2. `bash setup.sh install` (use a long timeout — the first Chromium download takes a few minutes)
> 3. Read `CLAUDE.md` and `.claude/skills/setup/SKILL.md` — they're this coach's instructions and
>    won't load on their own until the next session.
> 4. Show the user the report it prints (it ends with the two login commands), then **stop**.
>
> Do not run `nlm login` or `notebooklm login` — they open a browser and wait on Google sign-in, so
> they hang when run from a tool call. The user runs those two themselves. Don't load the channel
> until both logins are done and the user asks for it.

A personal **Engineering Funda study coach** that cites every claim for real. Built on
[Engineering Funda's](https://www.youtube.com/@EngineeringFunda) YouTube lectures loaded into your
own NotebookLM notebook, it interviews you one question at a time, maps your syllabus against the
channel's own course order, and writes you a study plan — and **every single explanation is backed
by a verbatim passage from an actual Engineering Funda lecture.** No freestyling, no made-up
sources. If Nilesh never covered something, the coach says so instead of inventing an answer.

```
You:   interview me to prep for my exams
Coach: In forward bias the depletion region narrows and the barrier potential is overcome, so
       majority carriers diffuse across the junction — that's why a silicon diode starts
       conducting around 0.7 V.
       📎 Source: "PN Junction Diode | Electronic Devices"
          "when we apply forward bias voltage, the depletion width decreases and the majority
           charge carriers cross the junction…"

       So, one question: which exam are you preparing for, and when is it?
```

> **Self-contained.** Channel-loading (`scripts/load_channel.py`) is vendored from the
> [notebooklm-coach](https://github.com/artemnovitckii/notebooklm-coach) skill (MIT) — clone this
> repo and you have everything. This is the opinionated Engineering Funda *coaching app*: the
> hard-citation interview, guided setup, the study-plan builder. Works for any expert: load a
> different channel and rewrite the persona (see [below](#use-it-for-a-different-expert)).

## Why it's different

- **Everything is cited — for real.** Every claim carries a source returned from the notebook *this
  session* via `scripts/ask_cited.py` (prints answer + real titles + verbatim quotes). Never from memory.
- **No fabrication, by design.** If the helper returns no source for a claim, the coach **drops the
  claim**. There is no uncited assertion — that's the whole point.
- **Guided setup.** A Claude Code `SessionStart` hook tells Claude whether your notebook is loaded
  yet, so it walks you through install → login → load before it starts coaching.
- **Your syllabus, sequenced against the channel's own course order** — not invented pacing.

## Setup: install → log in → load → ask

1. **Install.** Open an empty folder in **Claude Code** (e.g. `ai-engineering`), paste this repo's
   link, and say *install it*. Claude copies the coach into the folder and installs the tools.
2. **Log in twice**, same Google account both times. Each opens a browser, so you run them yourself
   in a terminal:
   ```bash
   nlm login          # read side  — the coach asks your notebook questions
   notebooklm login   # write side — setup creates the notebook and adds videos
   ```
3. **Load Engineering Funda's channel (by subject or recent).** Tell Claude:
   ```
   Load DSP videos from https://www.youtube.com/@EngineeringFunda
   ```
   NotebookLM caps sources per notebook by plan: **free = 50, Plus/Pro = 300**.
   Because Engineering Funda has over 3,000 videos across 20+ disciplines, load by **subject** so your
   notebook gets complete course coverage rather than just the latest series (see below).
4. **Ask.** *What's the difference between IIR and FIR filters?* → an answer with the exact lecture
   it came from.
5. **Get your plan.** Drop your syllabus in the folder and say **`interview me`**.

Prefer a terminal? **`bash setup.sh`** runs every step interactively, logins included. Beginner
guide: [docs/GETTING-STARTED.md](docs/GETTING-STARTED.md) · Manual reference: [docs/SETUP.md](docs/SETUP.md).

## Subject-Specific Notebooks (Overcoming NotebookLM Caps)

Engineering Funda has over **3,000 video lectures**, but Google NotebookLM limits sources per notebook:
- **Free plan**: max **50 sources/notebook**
- **Plus / Pro / Google One AI Premium**: max **300 sources/notebook**

Loading only the latest 50 videos means you only get the newest uploads (e.g. RADAR). To get full, deep
coverage of the subject you are currently studying, create subject-partitioned notebooks:

```bash
# Digital Signal Processing (filters, DFT, FFT, Z-transform, DTFT)
bash setup.sh load --subject dsp --count 184 --new

# Electronic Devices & Circuits (diodes, BJTs, MOSFETs, rectifiers)
bash setup.sh load --subject edc --count 100 --new

# Network Theory & Circuit Analysis (KVL/KCL, theorems, two-port networks)
bash setup.sh load --subject networks --count 100 --new

# Control Systems (Bode, Nyquist, root locus, transfer functions)
bash setup.sh load --subject control --count 100 --new

# Digital Electronics (logic gates, flip-flops, counters, K-maps)
bash setup.sh load --subject digital --count 50 --new

# Microprocessors (8085, 8086 architectures and instruction sets)
bash setup.sh load --subject microprocessor --count 70 --new

# Or custom keywords directly:
python3 scripts/load_channel.py load --videos videos.json --notebook <id> --filter "op-amp,transistor"
```

To switch between subjects, simply paste the desired notebook ID into `.notebooklm-id`.

## What's in here

```
engineeringfunda-coach/
├── README.md                       # this file
├── setup.sh                        # install · check · load · verify (or everything, interactively)
├── CLAUDE.md                       # the Engineering Funda coach persona/primer (the everything-cited rule)
├── CLAUDE.md.template              # blank persona for adapting to another expert
├── .notebooklm-id.example          # format of .notebooklm-id (setup writes the real one)
├── .claude/
│   ├── settings.json               # SessionStart hook — Claude Code
│   ├── hooks/onboard.sh            # tells Claude if the notebook is loaded yet
│   └── skills/
│       ├── setup/                  # install → log in → load channel → ask
│       └── coach-interview/        # the cited interview skill
├── scripts/
│   ├── ask_cited.py                # the live-citation engine (reads .notebooklm-id)
│   └── load_channel.py             # scrape a YouTube channel → bulk-load into NotebookLM
└── docs/
    ├── SETUP.md                    # full setup: NotebookLM + nlm + notebooklm-py + Claude Code
    └── LIMITATIONS.md              # auth expiry, source caps, coverage gaps, what can break
```

## The no-fabrication rule

LLMs will happily produce a plausible-sounding Engineering Funda lecture title that doesn't exist —
and that single behavior destroys the trust this tool is built on. So the rule is absolute: **a
claim is either backed by a title + quote the notebook returned this session, or it isn't made.**
The coach pre-fetches the core subjects once (so it's fast), cites from those real results, and for
anything off-topic it queries live or admits the notebook doesn't cover it. See
[docs/LIMITATIONS.md](docs/LIMITATIONS.md).

## Use it for a different expert

Nothing here is hardwired to Engineering Funda except the content:

1. Load a different channel into a new notebook:
   `bash setup.sh load --channel <url> --title "<name>" --count N` (add `--new` if you already
   loaded one). It saves the new id to `.notebooklm-id`, which `ask_cited.py` and the skills read.
2. Rewrite the persona: `cp CLAUDE.md.template CLAUDE.md` and fill in the expert, domain, and the
   interview "spine" (the core topics + pre-fetch questions for your field).

## Credit

Study-coaching layer regenerated from [@artemnovitckii](https://github.com/artemnovitckii)'s
[jeffnippard-coach](https://github.com/artemnovitckii/jeffnippard-coach). Built on
[notebooklm-coach](https://github.com/artemnovitckii/notebooklm-coach) and the
[notebooklm-mcp-cli](https://github.com/jacob-bd/notebooklm-mcp-cli) / `notebooklm-py` projects. MIT.
