#!/usr/bin/env bash
# Sanity-check the Homebrew packages the setup installs, including their dependencies.
#   ./audit.sh formula1 formula2 ... --cask cask1 cask2
# Writes a report to audit-report.txt next to this script.
# Exit code: 0 clean, 1 something flagged, 2 audit could not finish (treat as not clean).
set -uo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPORT="$DOTFILES/audit-report.txt"

formulae=(); casks=(); mode=f
for a in "$@"; do
  if [ "$a" = "--cask" ]; then mode=c
  elif [ "$mode" = f ]; then formulae+=("$a")
  else casks+=("$a"); fi
done

command -v brew >/dev/null 2>&1 || { echo "brew not found, nothing to audit"; exit 0; }
command -v python3 >/dev/null 2>&1 || { echo "python3 not found, cannot audit"; exit 2; }

tmp=$(mktemp -d) || exit 2
trap 'rm -rf "$tmp"' EXIT
echo 0 > "$tmp/status"
# Remember the worst result: 2 (incomplete) beats 1 (flagged) beats 0 (clean)
bump() { [ "$1" -gt "$(cat "$tmp/status")" ] && echo "$1" > "$tmp/status"; return 0; }
flag() { echo "  FLAG  $*"; bump 1; }

{
  echo "Package audit - $(date)"
  echo

  # --- Homebrew itself: where it updates from, and settings that redirect downloads ---
  echo "Homebrew setup:"
  origin=$(git -C "$(brew --repository)" remote get-url origin 2>/dev/null)
  case "$origin" in
    https://github.com/Homebrew/brew|https://github.com/Homebrew/brew.git) echo "  ok    brew updates from $origin" ;;
    *) flag "brew updates from '$origin', not https://github.com/Homebrew/brew" ;;
  esac
  for v in HOMEBREW_ARTIFACT_DOMAIN HOMEBREW_BOTTLE_DOMAIN HOMEBREW_API_DOMAIN \
           HOMEBREW_BREW_GIT_REMOTE HOMEBREW_CORE_GIT_REMOTE; do
    [ -n "${!v:-}" ] && flag "$v=${!v} sends downloads somewhere other than Homebrew"
  done
  case "${HOMEBREW_CASK_OPTS:-}" in
    *--no-quarantine*) flag "HOMEBREW_CASK_OPTS has --no-quarantine: macOS Gatekeeper skips cask apps" ;;
  esac
  echo

  # --- Taps: an official name pointing at an unofficial repo means tampering ---
  echo "Taps on this machine:"
  brew tap-info --json --installed 2>"$tmp/tap.err" > "$tmp/taps.json" || { cat "$tmp/tap.err"; bump 2; }
  python3 - "$tmp/taps.json" <<'PY'
import json, sys
taps = json.load(open(sys.argv[1]))
for t in taps:
    name, remote = t["name"], (t.get("remote") or "")
    if name.startswith("homebrew/"):
        ok = remote.lower().rstrip("/").removesuffix(".git") == "https://github.com/" + name.replace("homebrew/", "homebrew/homebrew-")
        print("  %s  %s (%s)" % ("ok  " if ok or not remote else "FLAG", name, remote or "API"))
        if remote and not ok: sys.exit(10)
    else:
        print("  note  %s (%s) - third-party: only matters for packages installed from it" % (name, remote))
PY
  rc=$?; [ $rc = 10 ] && bump 1; [ $rc != 0 ] && [ $rc != 10 ] && bump 2
  echo

  # --- Full formula list: what we asked for plus everything pulled in as a dependency ---
  all=""
  if [ ${#formulae[@]} -gt 0 ]; then
    deps=$(brew deps --union --formula "${formulae[@]}" 2>"$tmp/deps.err") || { cat "$tmp/deps.err"; bump 2; }
    all=$(printf '%s\n' "${formulae[@]}" $deps | sort -u)
    echo "Formulae checked ($(echo "$all" | wc -l | tr -d ' ') including dependencies):"
    echo "$all" | sed 's/^/  /'
    echo
    brew info --json=v2 --formula $all > "$tmp/formulae.json" 2>"$tmp/info.err" \
      || { echo "  brew info failed:"; sed 's/^/    /' "$tmp/info.err"; bump 2; }
  fi
  if [ ${#casks[@]} -gt 0 ]; then
    brew info --json=v2 --cask "${casks[@]}" > "$tmp/casks.json" 2>"$tmp/cinfo.err" \
      || { echo "  brew info --cask failed:"; sed 's/^/    /' "$tmp/cinfo.err"; bump 2; }
  fi

  # --- Provenance / health flags per package ---
  echo "Provenance check:"
  python3 - "$tmp" "$all" "${casks[*]:-}" <<'PY'
import json, os, sys
tmp, want_f, want_c = sys.argv[1], sys.argv[2].split(), sys.argv[3].split()
flags, broken = 0, False

def load(name, key, want):
    global broken
    path = os.path.join(tmp, name)
    if not want:
        return []
    try:
        items = json.load(open(path)).get(key, [])
    except (OSError, ValueError):
        items = []
    if len(items) != len(want):
        print("  ERROR expected %d %s, brew returned %d - audit incomplete" % (len(want), key, len(items)))
        broken = True
    return items

def report(label, why, ok_text):
    global flags
    if why:
        flags += 1
        print("  FLAG  %s: %s" % (label, "; ".join(why)))
    else:
        print("  ok    %s %s" % (label, ok_text))

for fm in load("formulae.json", "formulae", want_f):
    why = []
    if fm.get("tap") != "homebrew/core": why.append("third-party tap: %s" % fm.get("tap"))
    if fm.get("deprecated"): why.append("deprecated")
    if fm.get("disabled"): why.append("DISABLED")
    if not fm.get("license"): why.append("no license listed")
    src = (fm.get("urls") or {}).get("stable") or {}
    if not str(src.get("url", "")).startswith("https://"): why.append("source URL is not https")
    if not (src.get("checksum") or src.get("revision")): why.append("source not pinned by checksum or git commit")
    inst = fm.get("installed") or []
    if not inst: why.append("not installed")
    elif not inst[-1].get("poured_from_bottle"): why.append("built from source on this machine")
    if not (fm.get("bottle") or {}).get("stable"): why.append("no prebuilt bottle offered")
    report(fm["name"], why, (fm.get("versions") or {}).get("stable"))

for c in load("casks.json", "casks", want_c):
    why = []
    if c.get("tap") != "homebrew/cask": why.append("third-party tap: %s" % c.get("tap"))
    if c.get("deprecated"): why.append("deprecated")
    if c.get("disabled"): why.append("DISABLED")
    if not str(c.get("url", "")).startswith("https://"): why.append("download URL is not https")
    if c.get("sha256") in (None, "", "no_check"): why.append("no checksum: download is not verified")
    if not c.get("installed"): why.append("not installed")
    report("cask " + c["token"], why, c.get("version"))

print()
print("  %d item(s) flagged" % flags)
sys.exit(2 if broken else 1 if flags else 0)
PY
  bump $?
  echo

  # --- Outdated: only the packages this setup cares about (old versions may miss security fixes) ---
  echo "Outdated (ours only):"
  out=""
  [ -n "$all$*" ] && out=$(brew outdated --verbose $all ${casks[@]+"${casks[@]}"} 2>/dev/null)
  [ -n "$out" ] && echo "$out" | sed 's/^/  /' || echo "  none"
  echo

  # --- Known CVEs (optional: needs grype) ---
  if command -v grype >/dev/null 2>&1; then
    echo "Known vulnerabilities with a fix available (grype, High and Critical):"
    hits=$(grype "dir:$(brew --cellar)" --only-fixed -o table 2>/dev/null | awk '/High|Critical/')
    if [ -n "$hits" ]; then echo "$hits" | sed 's/^/  FLAG  /'; bump 1; else echo "  none found"; fi
    echo "  (heuristic: Homebrew binaries are not always detected)"
  else
    echo "CVE scan skipped: install grype (brew install grype) and re-run ./audit.sh for it."
  fi
  echo

  case "$(cat "$tmp/status")" in
    0) echo "Result: CLEAN" ;;
    1) echo "Result: FLAGGED - review the FLAG lines above" ;;
    *) echo "Result: INCOMPLETE - some checks failed to run, do not treat as clean" ;;
  esac
  echo "Note: this shows provenance and known issues. It cannot prove a package is free of malicious code."
} 2>&1 | tee "$REPORT"

echo
echo "Report saved to $REPORT"
exit "$(cat "$tmp/status")"
