# Limitations & gotchas

Read this before you rely on the coach for anything important. Most of these are inherent to driving
NotebookLM from outside — they're not bugs you can fix, just things to plan around.

## Authentication

- **Two separate logins.** `nlm` (read/query) and `notebooklm` (write/load) are different projects
  with independent sessions. Both must use the **same Google account**.
- **`nlm` sessions are short (~20 min).** Mid-interview you'll eventually hit
  `Authentication expired`. Fix: run `nlm login` again. The coach is told to surface this rather
  than guess. The `notebooklm` write session lasts weeks.
- **Interactive auth only.** Both logins use a browser. Headless/cron/CI runs that can't open a
  browser will fail to authenticate.

## NotebookLM account & ingestion

- **Source cap by tier:** free = **50 sources/notebook**, Plus/Pro = **300**. A large channel with
  thousands of videos (like Engineering Funda's 3,000+ catalog) cannot fit into a single notebook.
  The recommended solution is creating subject-specific notebooks (e.g. `bash setup.sh load --subject dsp`
  or `--subject edc`) and switching `.notebooklm-id` to match your active study course.
- **Loading pacing & rate limits:** High concurrency can trigger NotebookLM rate limits (`RPCError 9`).
  `load_channel.py` uses automatic exponential retry backoff and sequential pacing (`--concurrency 1`)
  for reliable ingestion. NotebookLM also processes video transcripts in the background, which can take
  2–5 minutes before titles and quotes become searchable.
- **Unofficial tooling.** `nlm` / `notebooklm-py` automate NotebookLM's private endpoints/UI. If
  Google changes things, they can break until the upstream projects catch up.

## Citations & coverage

- **Citations are only as good as the notebook.** If your expert never covered a topic, the coach
  **will not** cite it — it says "the notebook doesn't cover this directly" and drops the claim.
  Example: the Engineering Funda notebook teaches concepts and numericals, not your university's
  previous-year question papers or generic productivity advice, so the coach won't fake a source
  for those.
- **No-fabrication means visible gaps.** This is the core design choice: the coach refuses uncited
  claims, so you'll sometimes get "I can't source that" instead of a confident answer. That's
  correct behavior, not a failure.
- **Transcript quality varies.** YouTube auto-captions can be garbled, so a verbatim `cited_text`
  quote may contain ASR errors (mis-heard words). The **source title is reliable**; treat the quote
  as "roughly what was said in this video," and click through to verify exact wording if it matters.
- **Latency.** Each live query is ~20–30s. The coach pre-fetches the core subjects once to stay
  fast, but off-topic questions, "show me the proof," and the final build still pause while it
  queries.
- **Single notebook per setup.** This template wires one notebook id. You can run a multi-expert
  setup (e.g. Engineering Funda plus a maths/problem-solving channel), but that's manual
  configuration, not built in here.

## Claude Code specifics

- **The setup hook is Claude-Code-only.** The `SessionStart` hook + project skills are Claude Code
  features. In other agents the skills still work when invoked manually.
- **Hook approval.** Claude Code may prompt before running `.claude/hooks/onboard.sh`. Review it
  (it only echoes a one-line status based on whether `.notebooklm-id` exists) and approve.
- **Setup detection** keys off `.notebooklm-id`, which `bash setup.sh load` writes. Delete it (or
  load with `--new`) to start over with a fresh notebook.

## Privacy

- **Your data and study plan are gitignored** (`data/`, `private/`, `analysis/`). Never commit
  them — the coach is personalized to you. Only the template, skill, scripts, and docs are meant to
  be public.
