#!/usr/bin/env bash
# Favorites and recents.
#
# Both are plain newline-separated lists of binary names. Text files, because
# the user should be able to read, edit, back up or sync them with anything --
# and because that is the entire storage these two features need. No database,
# no counters, no scores: a tool is starred or it is not, and it was used or it
# was not. Anything more would be statistics, which do not help launch a tool.
#
# Sourced by the launcher and exercised directly by tests/smoke.sh.

is_favorite() { [[ -f "$BAT_FAVORITES" ]] && grep -qxF "$1" "$BAT_FAVORITES"; }

toggle_favorite() {
    local bin="$1" tmp
    [[ -n "$bin" ]] || return 1
    mkdir -p "$(dirname "$BAT_FAVORITES")" 2>/dev/null
    touch "$BAT_FAVORITES"
    if is_favorite "$bin"; then
        tmp="$(mktemp)" || return 1
        grep -vxF "$bin" "$BAT_FAVORITES" > "$tmp"
        mv "$tmp" "$BAT_FAVORITES"
        ui_notify "Unstarred ${bin}"
    else
        printf '%s\n' "$bin" >> "$BAT_FAVORITES"
        ui_notify "Starred ${bin}"
    fi
}

# Most-recent-first, deduplicated, trimmed. Rewriting a file of at most a few
# dozen lines costs nothing on a launch that is about to spawn a terminal, and
# it keeps the format trivially inspectable.
record_recent() {
    local bin="$1" tmp
    [[ -n "$bin" ]] || return 1
    mkdir -p "$(dirname "$BAT_RECENT")" 2>/dev/null
    tmp="$(mktemp)" || return 1
    {
        printf '%s\n' "$bin"
        [[ -f "$BAT_RECENT" ]] && grep -vxF "$bin" "$BAT_RECENT"
    } | head -n 50 > "$tmp"
    mv "$tmp" "$BAT_RECENT"
}

# Drop one tool from the recents. Bound to a key in the menu, because the list
# is automatic: the only control you have over it is removing something you do
# not want to see again.
forget_recent() {
    local bin="$1" tmp
    [[ -n "$bin" && -s "$BAT_RECENT" ]] || return 0
    tmp="$(mktemp)" || return 1
    # No `&&` between these: grep exits 1 when it removes the only line, and
    # under `set -o pipefail` that would skip the write and leave the entry in
    # place. Same trap that once made record_recent silently do nothing.
    grep -vxF "$bin" "$BAT_RECENT" > "$tmp"
    mv "$tmp" "$BAT_RECENT"
    ui_notify "Removed ${bin} from recent"
}
