#!/usr/bin/env python3
"""Ask the Engineering Funda NotebookLM notebook a question and print the answer with REAL citations.

Every [N] marker in the answer is resolved to the actual source title and the verbatim passage
NotebookLM quoted. This is the heart of engineeringfunda-coach: nothing it prints is from the
model's memory — titles and quotes come straight from the notebook, so the coach can cite for real.

Queries the notebook setup created for you. Resolution order:
  1. --notebook <id>
  2. $NOTEBOOKLM_ID
  3. a `.notebooklm-id` file in the repo root (first line) — written by `bash setup.sh load`
There's no built-in default: you can only query notebooks your own Google account owns, so load
the channel first. Find any notebook's id with `nlm notebook list`. See docs/SETUP.md.

Usage:
    python3 scripts/ask_cited.py "How does Engineering Funda explain the working of a PN junction diode?"
    python3 scripts/ask_cited.py --json "..."          # machine-readable (for caching)
    python3 scripts/ask_cited.py --notebook <id> "..."
"""
import json
import os
import subprocess
import sys
from pathlib import Path

NO_NOTEBOOK = """No notebook is set up yet, so there's nothing to ask.
Load Engineering Funda's channel first (after `nlm login` and `notebooklm login`):
    bash setup.sh load --count 50
That creates your notebook and saves its id to .notebooklm-id."""


def resolve_notebook(cli_arg):
    if cli_arg:
        return cli_arg
    if os.environ.get("NOTEBOOKLM_ID"):
        return os.environ["NOTEBOOKLM_ID"]
    for d in [Path.cwd(), *Path.cwd().parents]:
        f = d / ".notebooklm-id"
        if f.exists():
            lines = [ln.strip() for ln in f.read_text().splitlines()
                     if ln.strip() and not ln.strip().startswith("#")]
            if lines:
                return lines[0]
    return None


def run(cmd):
    p = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace")
    if p.returncode != 0 or not (p.stdout and p.stdout.strip()):
        sys.exit(f"command failed: {' '.join(cmd)}\n{p.stderr or p.stdout}\n"
                 "If this says auth expired, run `nlm login`.")
    return p.stdout


def main():
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    args = sys.argv[1:]
    as_json = False
    notebook_arg = None
    if "--json" in args:
        as_json = True
        args.remove("--json")
    if "--notebook" in args:
        i = args.index("--notebook")
        notebook_arg = args[i + 1]
        del args[i:i + 2]
    if not args:
        sys.exit(__doc__)
    notebook = resolve_notebook(notebook_arg)
    if not notebook:
        sys.exit(NO_NOTEBOOK)
    question = " ".join(args)

    d = json.loads(run(["nlm", "notebook", "query", notebook, question, "--json"]))
    if d.get("status") == "error" or "answer" not in d:
        sys.exit(d.get("error", "query failed — try `nlm login`"))

    titles = {s["id"]: s.get("title", "?") for s in json.loads(
        run(["nlm", "source", "list", notebook, "--json"]))}

    refs = {r["citation_number"]: r for r in d.get("references", [])}
    used = sorted(refs) or sorted(int(n) for n in d.get("citations", {}))
    sources = []
    for n in used:
        r = refs.get(n, {})
        sid = r.get("source_id") or d.get("citations", {}).get(str(n), "")
        sources.append({
            "n": n,
            "title": titles.get(sid, "UNKNOWN SOURCE — do not cite"),
            "cited_text": (r.get("cited_text") or "").strip(),
        })

    if as_json:
        print(json.dumps({"answer": d["answer"], "sources": sources}, indent=2))
        return

    print(d["answer"])
    print("\n" + "=" * 70 + "\nREAL SOURCES (verbatim from the notebook):\n")
    for s in sources:
        print(f'[{s["n"]}] 📎 {s["title"]}')
        if s["cited_text"]:
            q = s["cited_text"]
            print(f'      "{q[:240]}{"…" if len(q) > 240 else ""}"')
        print()


if __name__ == "__main__":
    main()
