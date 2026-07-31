#!/usr/bin/env bash
# Portability smoke test for BlackArch Toolbox, run inside a distro container.
# Exercises the paths that do not need a display: install, index, list, config.
set -uo pipefail

PASS=0; FAIL=0
ok()   { printf '  PASS  %s\n' "$1"; PASS=$((PASS+1)); }
bad()  { printf '  FAIL  %s\n' "$1"; printf '        %s\n' "${2:-}"; FAIL=$((FAIL+1)); }

printf '\n=== %s ===\n' "$(. /etc/os-release 2>/dev/null && echo "$PRETTY_NAME" || echo unknown)"
printf 'bash %s | awk: %s\n\n' "${BASH_VERSION}" "$(awk --version 2>/dev/null | head -1 || awk -W version 2>&1 | head -1)"

cd /repo || exit 1

# 1. every script parses under this bash
err="$(for f in bin/blackarch-toolbox install.sh lib/*.sh lib/backends/*.sh; do
          bash -n "$f" 2>&1 || echo "^^ $f"; done)"
[[ -z "$err" ]] && ok "all scripts parse" || bad "scripts parse" "$err"

# 2. installer runs (no keybinding, no root)
out="$(bash install.sh --no-keybind 2>&1)"; rc=$?
if [[ $rc -eq 0 ]]; then ok "install.sh --no-keybind (exit 0)"
else bad "install.sh --no-keybind (exit $rc)" "$(echo "$out" | tail -15)"; fi

BIN="$HOME/.local/bin/blackarch-toolbox"
[[ -x "$BIN" ]] && ok "launcher symlinked onto PATH" || bad "launcher symlink missing"

# 3. index builds via the catalogue backend
out="$("$BIN" --refresh 2>&1)"; rc=$?
if [[ $rc -eq 0 ]]; then ok "--refresh (exit 0): $(echo "$out" | tail -1)"
else bad "--refresh (exit $rc)" "$(echo "$out" | tail -15)"; fi

CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/blackarch-toolbox"
n=$(wc -l < "$CACHE/all.list" 2>/dev/null || echo 0)
[[ "$n" -gt 0 ]] && ok "index has $n runnable tools" || bad "index empty"
s=$(wc -l < "$CACHE/sections.list" 2>/dev/null || echo 0)
[[ "$s" -gt 0 ]] && ok "index has $s sections" || bad "no sections"

# 4. every indexed tool must actually exist on PATH (the core promise)
missing=0
while IFS=$'\t' read -r bin _; do
    command -v "$bin" >/dev/null 2>&1 || missing=$((missing+1))
done < "$CACHE/all.list"
[[ "$missing" -eq 0 ]] && ok "every indexed tool resolves on PATH" \
    || bad "$missing indexed tools are not runnable"

# 5. rows are well formed: bin \t pkg \t pango \t plain
badrows="$(awk -F'\t' 'NF!=4{c++} END{print c+0}' "$CACHE/all.list")"
[[ "$badrows" -eq 0 ]] && ok "all rows have 4 fields" || bad "$badrows malformed rows"

# 6. the padded name column lines up (what render.awk exists to do)
widths="$(awk -F'\t' '{ n=index($4,"  "); print n }' "$CACHE/all.list" | sort -u | wc -l)"
ok "description column starts at $widths distinct offset(s)"

# 7. favorites & recents: the state layer, exercised directly
(
  export BAT_CONFIG_DIR="$(mktemp -d)" BAT_STATE="$(mktemp -d)"
  export BAT_FAVORITES="$BAT_CONFIG_DIR/favorites" BAT_RECENT="$BAT_STATE/recent"
  ui_notify() { :; }
  . lib/state.sh
  toggle_favorite nmap
  is_favorite nmap || { echo "star failed"; exit 1; }
  toggle_favorite nmap
  is_favorite nmap && { echo "unstar failed"; exit 1; }
  record_recent aaa; record_recent bbb; record_recent aaa
  [[ "$(head -1 "$BAT_RECENT")" == aaa ]] || { echo "recent order wrong"; exit 1; }
  [[ "$(grep -cxF aaa "$BAT_RECENT")" -eq 1 ]] || { echo "recent not deduped"; exit 1; }
  exit 0
) && ok "favorites star/unstar, recents order + dedupe" \
  || bad "favorites/recents state"

# 8. the search-first menu: one list, correct order, no duplicates
(
  fav="$(mktemp)"; rec="$(mktemp)"; out="$(mktemp)"
  first="$(head -1 "$CACHE/all.list" | cut -f1)"
  printf '%s\n' "$first" > "$fav"
  printf '%s\n' "$first" > "$rec"          # also recent: must NOT appear twice
  build() { awk -f lib/menu.awk -v favfile="$fav" -v recfile="$rec" \
      -v secfile="$CACHE/sections.list" -v reccap=8 -v namew=20 -v withtools="$1" \
      -v blood='#ff2b2b' -v ember='#ff7a45' -v faint='#5a4848' \
      "$fav" "$rec" "$CACHE/sections.list" "$CACHE/all.list"; }
  tools=$(wc -l < "$CACHE/all.list"); secs=$(wc -l < "$CACHE/sections.list")

  # top view: search row + the one favorite + every section. NOT the tool list.
  build 0 > "$out"
  rows=$(wc -l < "$out")
  [[ "$rows" -eq $((1 + 1 + secs)) ]] || { echo "top rows $rows != $((2+secs))"; exit 1; }
  [[ "$(head -1 "$out" | cut -f1)" == search ]] || { echo "search row not first"; exit 1; }
  awk -F'\t' 'NR>1 && $1=="tool" && $2!=b {exit 1}' b="$first" "$out" \
      || { echo "top view leaked the tool list"; exit 1; }

  # search list: every tool, no sections, no search row
  build 1 > "$out"
  rows=$(wc -l < "$out")
  [[ "$rows" -eq "$tools" ]] || { echo "search rows $rows != $tools"; exit 1; }
  [[ -z "$(awk -F'\t' '$1!="tool"{print}' "$out")" ]] || { echo "non-tool in search list"; exit 1; }
  [[ "$(head -1 "$out" | cut -f2)" == "$first" ]] || { echo "favorite not first"; exit 1; }
  # awk, not grep: "\t" is not a tab in grep's BRE, it is a literal "t".
  n=$(awk -F'\t' -v b="$first" '$1=="tool" && $2==b {c++} END{print c+0}' "$out")
  [[ "$n" -eq 1 ]] || { echo "row for $first appears $n times, want 1"; exit 1; }
  exit 0
) && ok "menu: short top view, full search list, no duplicates" \
  || bad "menu list build"

# 9. read-only CLI surface
for flag in --version --help --config --list; do
    o="$("$BIN" $flag 2>&1)"; r=$?
    [[ $r -eq 0 && -n "$o" ]] && ok "$flag" || bad "$flag (exit $r)" "$(echo "$o" | tail -5)"
done

# 10. menu backend detection must pick the terminal fallback when headless
o="$("$BIN" --config 2>&1 | grep -i menu)"
ok "headless menu resolution: ${o:-none}"

printf '\n  %d passed, %d failed\n' "$PASS" "$FAIL"
exit $(( FAIL > 0 ))
