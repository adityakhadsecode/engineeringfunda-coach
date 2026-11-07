#!/usr/bin/env bash
# Claude Code SessionStart hook: tells Claude where this folder is in setup, so it follows
# install → log in → load the channel → ask, instead of jumping ahead to the interview.
# Setup is "done" once `bash setup.sh load` has written the notebook id to .notebooklm-id.

DIR="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"

if [ ! -s "$DIR/.notebooklm-id" ]; then
  echo "COACH NOT SET UP YET — no NotebookLM notebook is loaded in this folder (.notebooklm-id is missing). Don't start the coaching interview. When the user asks to install, set up, log in, or load a channel, follow the 'setup' skill: install with 'bash setup.sh install', have the USER run 'nlm login' and 'notebooklm login' themselves (never run them — they open a browser), then load with 'bash setup.sh load --count N'."
else
  echo "COACH READY — notebook $(head -1 "$DIR/.notebooklm-id"). Answer engineering questions with 'python3 scripts/ask_cited.py \"<question>\"' and cite only the titles and quotes it returns. When the user wants a personal study plan, run the 'coach-interview' skill."
fi
