#!/usr/bin/env bash
# Setup for engineeringfunda-coach: install → log in → load the channel → ask.
#
#   bash setup.sh                  everything, interactively (for a terminal)
#   bash setup.sh install          install the tools, then print the two login commands
#   bash setup.sh check            tools + logins + notebook status (exit 0 = ready to load, 2 = not)
#   bash setup.sh load --count N [--channel URL] [--title NAME] [--subject SUB] [--new]
#                                  scrape the channel, create a notebook, save its id, load, verify
#                                  preset subjects: dsp, edc, networks, control, digital, microprocessor, radar
#   bash setup.sh verify           count loaded vs failed ("red") sources in the saved notebook
#
# Only the plain `bash setup.sh` runs the Google logins. The subcommands never do: the logins open
# a browser and wait for sign-in, so they hang when Claude runs them from a tool call.
set -euo pipefail
cd "$(dirname "$0")"
export PATH="$HOME/.local/bin:$PATH"

DEFAULT_CHANNEL="https://www.youtube.com/@EngineeringFunda"
DEFAULT_TITLE="Engineering Funda - Study Coach"
DEFAULT_COUNT=50   # fits every NotebookLM plan (free = 50 sources per notebook, Plus/Pro = 300)

say()  { printf "\n\033[1;32m▸ %s\033[0m\n" "$*"; }
warn() { printf "  ⚠️  %s\n" "$*"; }
ask()  { local p="$1" d="$2" a; read -r -p "$p [$d]: " a || true; echo "${a:-$d}"; }
have() { command -v "$1" >/dev/null 2>&1; }

nlm_ok()      { have nlm && nlm notebook list >/dev/null 2>&1; }
nblm_ok()     { have notebooklm && notebooklm auth check >/dev/null 2>&1; }
notebook_id() { if [ -s .notebooklm-id ]; then head -1 .notebooklm-id | tr -d '[:space:]'; fi; }

print_logins() {
  cat <<EOF

Next: log in to NotebookLM twice, with the SAME Google account both times.
Each command opens a browser for Google sign-in, so run them yourself in a terminal
(Claude desktop app: the Terminal panel · Claude Code CLI: type them after a "!"):

  nlm login          # read side  — lets the coach ask the notebook questions
  notebooklm login   # write side — lets setup create the notebook and add videos

("command not found"? use ~/.local/bin/nlm login and ~/.local/bin/notebooklm login)

Then ask Claude to load the channel, e.g.:
  Load the 50 most recent public videos from $DEFAULT_CHANNEL
NotebookLM caps sources per notebook by plan: free = 50, Plus/Pro = 300.
EOF
}

install_tool() { # bin, uv package spec
  local bin="$1" pkg="$2" out
  if have "$bin"; then echo "  ✓ $bin already installed"; return; fi
  if ! out=$(uv tool install "$pkg" 2>&1); then
    # notebooklm-mcp-cli and notebooklm-py both ship a `notebooklm-mcp` shim, so the second
    # install collides. The coach only uses `nlm` and `notebooklm`, so taking it over is safe.
    if printf '%s' "$out" | grep -q "Executable already exists"; then
      uv tool install --force "$pkg" >/dev/null
    else
      printf '%s\n' "$out"; warn "Couldn't install $pkg — try: uv tool install $pkg"; exit 1
    fi
  fi
  have "$bin" || { warn "$bin installed but not on PATH — restart your terminal and re-run"; exit 1; }
  echo "  ✓ $bin installed"
}

do_install() {
  say "Installing uv (tool manager)…"
  if have uv; then echo "  ✓ uv already installed"; else curl -LsSf https://astral.sh/uv/install.sh | sh; fi
  have uv || { warn "uv didn't install — see https://docs.astral.sh/uv/"; exit 1; }

  say "Installing the NotebookLM tools…"
  install_tool nlm notebooklm-mcp-cli
  install_tool notebooklm "notebooklm-py[browser]"

  say "Installing Chromium for the notebooklm login (~100MB the first time)…"
  uvx --from "notebooklm-py[browser]" playwright install chromium \
    || warn "Chromium install failed — retry: uvx --from \"notebooklm-py[browser]\" playwright install chromium"
}

do_check() {
  local rc=0 nb
  printf '\n'
  if ! have nlm; then echo "  ✗ nlm          not installed   → bash setup.sh install"; rc=2
  elif nlm_ok;    then echo "  ✓ nlm          logged in"
  else                 echo "  ✗ nlm          not logged in   → nlm login"; rc=2; fi
  if ! have notebooklm; then echo "  ✗ notebooklm   not installed   → bash setup.sh install"; rc=2
  elif nblm_ok;          then echo "  ✓ notebooklm   logged in"
  else                        echo "  ✗ notebooklm   not logged in   → notebooklm login"; rc=2; fi
  nb=$(notebook_id)
  if [ -n "$nb" ]; then echo "  ✓ notebook     $nb"
  else                  echo "  · notebook     none yet        → bash setup.sh load --count N"; fi
  return $rc
}

do_verify() {
  local nb; nb=$(notebook_id)
  [ -n "$nb" ] || { warn "No notebook yet — load the channel first: bash setup.sh load --count N"; return 2; }
  nlm_ok || { warn "nlm login expired (it only lasts ~20 min). Run: nlm login   then: bash setup.sh verify"; return 2; }
  say "Checking what landed in the notebook…"
  nlm source list "$nb" --json | python3 -c '
import json, sys
d = json.load(sys.stdin)
red = [s for s in d if str(s.get("title", "")).strip().startswith("http")]
print(f"  {len(d) - len(red)} loaded OK · {len(red)} failed · {len(d)} total")
for s in red[:25]:
    print("   ✗", s["title"])
if red:
    print("  A failed row keeps the video URL as its title. NotebookLM can take a few minutes to")
    print("  process new videos, so re-run `bash setup.sh verify` before treating these as failed.")
'
}

do_load() {
  local ch="$DEFAULT_CHANNEL" cnt="$DEFAULT_COUNT" title="$DEFAULT_TITLE" new=0 subject="" videos nb found
  while [ $# -gt 0 ]; do
    case "$1" in
      --channel) ch="$2"; shift 2 ;;
      --count)   cnt="$2"; shift 2 ;;
      --title)   title="$2"; shift 2 ;;
      --subject) subject="$2"; shift 2 ;;
      --new)     new=1; shift ;;
      *) warn "Unknown option: $1"; exit 1 ;;
    esac
  done
  case "$cnt" in ''|*[!0-9]*) warn "--count must be a number (free = 50, Plus/Pro = 300)"; exit 1 ;; esac

  if [ -n "$subject" ] && [ "$title" = "$DEFAULT_TITLE" ]; then
    title="$title ($subject)"
  fi

  if ! nlm_ok || ! nblm_ok; then
    warn "Log in to NotebookLM first."; do_check || true; print_logins; exit 2
  fi
  if [ -n "$(notebook_id)" ] && [ "$new" != 1 ]; then
    say "A notebook is already set up ($(notebook_id)) — skipping the load. Pass --new to build another."
    do_verify || true; return
  fi

  videos=$(mktemp "${TMPDIR:-/tmp}/coach-videos.XXXXXX")
  say "Finding every video on $ch…"
  python3 scripts/load_channel.py scrape --channel "$ch" --output "$videos"
  found=$(python3 -c 'import json,sys; print(len(json.load(open(sys.argv[1]))))' "$videos")
  [ "$found" -gt 0 ] || { warn "Found no videos at $ch — check the channel URL."; exit 1; }
  [ "$cnt" -le "$found" ] || cnt="$found"

  say "Found $found videos. Creating a new notebook: \"$title\"…"
  # Take the id from create's own output — looking it up by title could pick an older notebook.
  nb=$(notebooklm create "$title" --json | python3 -c 'import json,sys; print(json.load(sys.stdin)["notebook"]["id"])') \
    || { warn "Couldn't create the notebook — check: notebooklm auth check"; exit 1; }
  echo "$nb" > .notebooklm-id
  echo "  ✓ saved to .notebooklm-id ($nb)"

  say "Adding up to $cnt videos (subject: ${subject:-all}), one at a time (slow on purpose — fewer failed adds)…"
  uv run --with "notebooklm-py[browser]" python3 scripts/load_channel.py load \
    --videos "$videos" --notebook "$nb" --count "$cnt" --concurrency 1 ${subject:+--subject "$subject"} \
    || warn "The loader reported errors — checking what actually landed…"
  rm -f "$videos"
  do_verify || true
}

do_all() {
  do_install
  if ! nlm_ok || ! nblm_ok; then
    say "Logging in to NotebookLM — a browser opens each time. Use the SAME Google account both times."
    nlm_ok  || nlm login || true
    nblm_ok || notebooklm login || true
  fi
  if ! do_check; then warn "Still not logged in."; print_logins; exit 1; fi

  if [ -z "$(notebook_id)" ]; then
    local ch title cnt subject
    ch=$(ask "Which YouTube channel?" "$DEFAULT_CHANNEL")
    title=$(ask "Notebook name" "$DEFAULT_TITLE")
    cnt=$(ask "How many videos? (free NotebookLM = 50, Plus/Pro = 300)" "$DEFAULT_COUNT")
    subject=$(ask "Subject filter (optional: dsp, edc, networks, control, digital, microprocessor, radar, or blank for all)" "")
    do_load --channel "$ch" --title "$title" --count "$cnt" ${subject:+--subject "$subject"}
  else
    say "Notebook already set up ($(notebook_id))."
  fi

  say "Testing that citations are real…"
  python3 scripts/ask_cited.py "How does Engineering Funda explain the working of a PN junction diode?" || true
  cat <<'DONE'

✅ Setup complete. Open this folder in Claude Code and ask it anything, e.g.
   "What's the difference between a BJT and a MOSFET?" — or say "interview me" for your own study plan.
   (The nlm login lasts ~20 min; if it expires, run `nlm login` again.)
DONE
}

case "${1:-}" in
  "")      do_all ;;
  install)
    do_install
    if do_check; then
      if [ -n "$(notebook_id)" ]; then say "All set — the coach is ready. Ask it anything."
      else say "Tools installed and you're logged in. Next: ask Claude to load the channel, e.g."
           echo "  Load the 50 most recent public videos from $DEFAULT_CHANNEL"; fi
    else
      print_logins
    fi ;;
  check)   do_check ;;
  load)    shift; do_load "$@" ;;
  verify)  do_verify ;;
  help|-h|--help) sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//' ;;
  *) warn "Unknown command: $1"; sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
esac
