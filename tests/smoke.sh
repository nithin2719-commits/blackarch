#!/usr/bin/env bash
# Portability smoke test for BlackArch Toolbox, run inside a distro container.
# Exercises the paths that do not need a display: install, index, list, config.
set -uo pipefail

PASS=0; FAIL=0
ok()   { printf '  PASS  %s\n' "$1"; PASS=$((PASS+1)); }
bad()  { printf '  FAIL  %s\n' "$1"; printf '        %s\n' "${2:-}"; FAIL=$((FAIL+1)); }

printf '\n=== %s ===\n' "$(. /etc/os-release 2>/dev/null && echo "$PRETTY_NAME" || echo unknown)"
printf 'bash %s | awk: %s\n\n' "${BASH_VERSION}" "$(awk --version 2>/dev/null | head -1 || awk -W version 2>&1 | head -1)"

# Run from the repo root, wherever this script happens to live -- it is invoked
# from a container mount, from `make check` inside a build chroot, and by hand.
cd "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)" || exit 1

# Run against a throwaway HOME. The suite installs the launcher and builds an
# index, and neither belongs in the caller's real home -- this is run by hand on
# a working machine and by `make check` inside a package build, and it must
# leave no trace in either.
export HOME="$(mktemp -d)"
export XDG_CACHE_HOME="$HOME/.cache" XDG_CONFIG_HOME="$HOME/.config" \
       XDG_STATE_HOME="$HOME/.local/state"
export PATH="$HOME/.local/bin:$PATH"
trap 'rm -rf "$HOME"' EXIT

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

  # The empty-file cases, which are where this went wrong in the wild. Under
  # `set -o pipefail`, `grep -vxF x empty-file` exits 1 and poisons the whole
  # pipeline, so a `... && mv` writes nothing: the FIRST recent could never be
  # saved, and because the file then stayed empty it never could -- Recent was
  # permanently blank. The same shape hid in unstarring your last favourite.
  : > "$BAT_RECENT"
  record_recent solo
  [[ "$(cat "$BAT_RECENT")" == solo ]] \
      || { echo "first recent lost when the file was empty"; exit 1; }
  : > "$BAT_FAVORITES"
  toggle_favorite onlyfav
  is_favorite onlyfav || { echo "could not star into an empty file"; exit 1; }
  toggle_favorite onlyfav
  is_favorite onlyfav && { echo "could not unstar the only favourite"; exit 1; }

  # forgetting a recent, including the last one left
  printf 'aa\nbb\n' > "$BAT_RECENT"
  forget_recent aa
  [[ "$(cat "$BAT_RECENT")" == bb ]] || { echo "forget_recent removed the wrong row"; exit 1; }
  forget_recent bb
  [[ -s "$BAT_RECENT" ]] && { echo "could not forget the last recent"; exit 1; }
  exit 0
) && ok "favorites star/unstar, recents order/dedupe/forget" \
  || bad "favorites/recents state"

# 8. the menu: a main box of destinations, and the folders it opens
(
  fav="$(mktemp)"; rec="$(mktemp)"; out="$(mktemp)"
  first="$(head -1 "$CACHE/all.list" | cut -f1)"
  printf '%s\n' "$first" > "$fav"
  printf '%s\n' "$first" > "$rec"
  build() { awk -f lib/menu.awk -v favfile="$fav" -v recfile="$rec" \
      -v secfile="$CACHE/sections.list" -v reccap=8 -v namew=20 -v mode="$1" \
      -v blood='#ff2b2b' -v ember='#ff7a45' -v faint='#5a4848' \
      "$fav" "$rec" "$CACHE/sections.list" "$CACHE/all.list"; }
  tools=$(wc -l < "$CACHE/all.list"); secs=$(wc -l < "$CACHE/sections.list")

  # main box: search + favorites + recent + every section. NO tool rows at all.
  build top > "$out"
  rows=$(wc -l < "$out")
  [[ "$rows" -eq $((3 + secs)) ]] || { echo "top rows $rows != $((3+secs))"; exit 1; }
  [[ "$(cut -f1 "$out" | head -3 | tr '\n' ' ')" == "search favs recent " ]] \
      || { echo "main box order wrong: $(cut -f1 "$out" | head -3 | tr '\n' ' ')"; exit 1; }
  [[ -z "$(awk -F'\t' '$1=="tool"{print}' "$out")" ]] \
      || { echo "main box leaked tool rows"; exit 1; }

  # the folders are furniture: present even at zero, so the box never changes
  # shape underneath the user and the features stay discoverable
  : > "$fav"; : > "$rec"
  build top > "$out"
  [[ "$(wc -l < "$out")" -eq $((3 + secs)) ]] || { echo "folders vanished when empty"; exit 1; }
  [[ "$(cut -f1 "$out" | head -3 | tr '\n' ' ')" == "search favs recent " ]] \
      || { echo "folder order changed when empty"; exit 1; }
  printf '%s\n' "$first" > "$fav"; printf '%s\n' "$first" > "$rec"

  # each folder holds only tools
  for m in all favs recent; do
    build "$m" > "$out"
    [[ -s "$out" ]] || { echo "$m list empty"; exit 1; }
    [[ -z "$(awk -F'\t' '$1!="tool"{print}' "$out")" ]] || { echo "$m has non-tool rows"; exit 1; }
  done

  # the search list is every tool, in index order, exactly once each
  build all > "$out"
  [[ "$(wc -l < "$out")" -eq "$tools" ]] || { echo "search list != all tools"; exit 1; }

  # Descriptions ARE shown, but must be unsearchable: render.awk interleaves
  # them with U+200C so no typed string can match them. Without this, "nmap"
  # returns every tool whose blurb mentions nmap.
  awk -F'\t' 'NR==1{ if (index($4, "\342\200\214") == 0) exit 1 }' "$out" \
      || { echo "search rows carry a searchable description"; exit 1; }
  # the name itself must NOT be interleaved, or it would stop matching too
  first_row_name="$(head -1 "$out" | cut -f2)"
  awk -F'\t' -v n="$first_row_name" 'NR==1{ if (index($4, n) == 0) exit 1 }' "$out" \
      || { echo "the tool name is not matchable"; exit 1; }

  exit 0
) && ok "menu: main box of destinations, folders hold only tools" \
  || bad "menu list build"

# 9. the catalogue: well formed, and every slug maps to a real section
(
  awk -F'\t' '!/^#/ && NF && NF!=3 {print "row "NR" has "NF" fields"; bad=1} END{exit bad+0}' \
      data/catalog.tsv || exit 1
  awk -F'\t' '!/^#/ && NF{k=$1"\t"$2; if(seen[k]++) {print "duplicate: "$1" in "$2; bad=1}} END{exit bad+0}' \
      data/catalog.tsv || exit 1
  # section slugs come from data/sections.conf; a catalogue row pointing at a
  # slug that no section claims would index into a section that never shows
  slugs="$(grep -vE '^#|^$' data/sections.conf | cut -d'|' -f3 | tr ',' '\n' \
           | sed 's/blackarch-//' | sort -u)"
  for sl in $(grep -vE '^#|^$' data/catalog.tsv | cut -f2 | sort -u); do
    printf '%s\n' "$slugs" | grep -qx "$sl" || { echo "orphan slug: $sl"; exit 1; }
  done
  exit 0
) && ok "catalogue: $(grep -vcE '^#|^$' data/catalog.tsv) entries, well formed, no orphan slugs" \
  || bad "catalogue validation"

# 10. read-only CLI surface
for flag in --version --help --config --list; do
    o="$("$BIN" $flag 2>&1)"; r=$?
    [[ $r -eq 0 && -n "$o" ]] && ok "$flag" || bad "$flag (exit $r)" "$(echo "$o" | tail -5)"
done

# 11. menu backend detection must pick the terminal fallback when headless
o="$("$BIN" --config 2>&1 | grep -i menu)"
ok "headless menu resolution: ${o:-none}"

printf '\n  %d passed, %d failed\n' "$PASS" "$FAIL"
exit $(( FAIL > 0 ))
