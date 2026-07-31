#!/usr/bin/env bash
# BlackArch Toolbox — launcher core.
#
# A search-first menu over an index of *runnable* tools (see refresh.sh):
#   type a name -> launch      (the fast path: Alt+A, type, Enter)
#   or browse a category -> tool -> launch
#
# Launch policy:
#   - a tool with a GUI (.desktop entry or a binary that links a GUI toolkit)
#     opens its own window;
#   - a CLI tool opens a themed terminal that shows its usage & flags first,
#     then drops into a shell scoped to that tool (see toolview.sh).
#
# The menu and terminal are both abstracted (lib/menu.sh, lib/terminal.sh) so
# the same launcher drives rofi on Hyprland, wofi on sway, and fzf over SSH.

set -uo pipefail

HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/paths.sh"
# shellcheck source=/dev/null
source "$HERE/ui.sh"
# shellcheck source=/dev/null
source "$HERE/menu.sh"
# shellcheck source=/dev/null
source "$HERE/terminal.sh"
# shellcheck source=/dev/null
source "$HERE/state.sh"

PIDFILE="${TMPDIR:-/tmp}/blackarch-toolbox.pid"

DIM='#9a7d7d'; FAINT='#5a4848'; EMBER='#ff7a45'

# ---- single-instance toggle: a second Alt+A closes the open menu ---------
if [[ -f "$PIDFILE" ]] && kill -0 "$(cat "$PIDFILE" 2>/dev/null)" 2>/dev/null; then
    kill "$(cat "$PIDFILE")" 2>/dev/null
    rm -f "$PIDFILE"
    exit 0
fi
echo $$ > "$PIDFILE"
trap 'rm -f "$PIDFILE"' EXIT

menu_init || ui_die "No menu program found. Install one of: rofi, fuzzel, wofi, dmenu, or fzf."
term_init

# ---- build the index on first run (or if missing) ------------------------
if [[ ! -f "$BAT_CACHE/sections.list" ]]; then
    command -v notify-send >/dev/null 2>&1 && \
        notify-send "BlackArch Toolbox" "Indexing tools for the first time…" 2>/dev/null
    bash "$HERE/refresh.sh" >/dev/null 2>&1 || \
        ui_die "First-time indexing failed. Run 'blackarch-toolbox --refresh' to see why."
fi

pango_escape() { sed -e 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g'; }

# ---- GUI detection & launch ----------------------------------------------
GUI_BINS=" burpsuite maltego wireshark autopsy ghidra zenmap armitage beef \
caido-desktop ettercap-graphical networkminer fern-wifi-cracker vega \
webscarab owasp-zap jadx-gui cutter zaproxy nwjs bloodhound "

APPDIRS=(/usr/share/applications /usr/local/share/applications
         "$HOME/.local/share/applications")

# Resolve the .desktop entry that actually launches a binary, echoing its full
# path (empty if none). Many GUI tools ship a reverse-DNS desktop id
# (wireshark -> org.wireshark.Wireshark.desktop, cutter -> re.rizin.cutter),
# so matching only "<bin>.desktop" missed them and the launcher fell back to
# spawning the raw binary -- which silently fails for apps that need the
# entry's Exec (wrappers, env, args). Here we try the obvious names first, then
# match any entry whose Exec/TryExec runs this binary. Memoised per session.
declare -A _DESKTOP_CACHE=()
resolve_desktop() {
    local bin="$1" alt="${1//-/_}" d f hit=""
    if [[ -n "${_DESKTOP_CACHE[$bin]+x}" ]]; then printf '%s' "${_DESKTOP_CACHE[$bin]}"; return; fi
    for d in "${APPDIRS[@]}"; do
        for f in "$d/$bin.desktop" "$d/$alt.desktop"; do
            [[ -f "$f" ]] && { hit="$f"; break 2; }
        done
    done
    if [[ -z "$hit" ]]; then
        for d in "${APPDIRS[@]}"; do
            [[ -d "$d" ]] || continue
            hit="$(grep -ilE "^(Try)?Exec=(/[^ ]*/)?($bin|$alt)( |\$|%)" \
                     "$d"/*.desktop 2>/dev/null | head -1)"
            [[ -n "$hit" ]] && break
        done
    fi
    _DESKTOP_CACHE[$bin]="$hit"
    printf '%s' "$hit"
}

# GUI when ANY holds: a non-terminal .desktop exists; the binary is in the
# curated list; or the ELF links a GUI toolkit. CLI tools match none.
is_gui() {
    local bin="$1" alt="${1//-/_}" desktop="${2-}" path
    [[ -z "${2+x}" ]] && desktop="$(resolve_desktop "$bin")"
    if [[ -n "$desktop" ]]; then
        grep -qiE '^\s*Terminal\s*=\s*true' "$desktop" || return 0
    fi
    [[ " $GUI_BINS " == *" $bin "* ]] && return 0
    path="$(command -v "$bin" 2>/dev/null)" || path="$(command -v "$alt" 2>/dev/null)"
    if [[ -n "$path" ]] && command -v file >/dev/null 2>&1 \
       && file -bL "$path" 2>/dev/null | grep -q 'ELF' \
       && command -v ldd >/dev/null 2>&1; then
        ldd "$path" 2>/dev/null | grep -qiE \
            'libgtk-[0-9]|libgtk-x11|libQt[0-9][A-Za-z]+\.so|libwx_|libfltk|libtk[0-9]|libcef\.so|libnw\.so' \
            && return 0
    fi
    return 1
}

# Launch a GUI tool and return immediately. Prefer `gio launch <path>` -- it
# reads the resolved entry's Exec/env/actions and is the Wayland-correct way to
# start an app detached from the launcher -- then gtk-launch by id, then the raw
# binary. Every branch is setsid+disowned so the app outlives the menu.
launch_gui() {
    local bin="$1" alt="${1//-/_}" desktop="${2-}" id
    [[ -z "${2+x}" ]] && desktop="$(resolve_desktop "$bin")"
    if [[ -n "$desktop" ]]; then
        if command -v gio >/dev/null 2>&1; then
            setsid gio launch "$desktop" >/dev/null 2>&1 &
        elif command -v gtk-launch >/dev/null 2>&1; then
            id="${desktop##*/}"; id="${id%.desktop}"
            setsid gtk-launch "$id" >/dev/null 2>&1 &
        else
            setsid "$bin" >/dev/null 2>&1 &
        fi
        disown 2>/dev/null || true
        return
    fi
    if command -v "$bin" >/dev/null 2>&1; then setsid "$bin" >/dev/null 2>&1 &
    else setsid "$alt" >/dev/null 2>&1 & fi
    disown 2>/dev/null || true
}

launch_cli() {
    local bin="$1" pkg="$2"
    term_run "BlackArch :: $bin" bash "$HERE/toolview.sh" "$bin" "$pkg"
}

launch_tool() {
    local bin="$1" pkg="${2:-}"
    command -v notify-send >/dev/null 2>&1 && \
        notify-send -t 1500 "BlackArch Toolbox" "Launching ${bin}…" 2>/dev/null
    # Resolve the desktop entry once and hand it to both helpers, so a GUI tool
    # goes from click to window with no repeated scanning.
    local desktop; desktop="$(resolve_desktop "$bin")"
    if [[ "$BAT_GUI_MODE" != always-terminal ]] && is_gui "$bin" "$desktop"; then
        launch_gui "$bin" "$desktop"
    else
        launch_cli "$bin" "$pkg"
    fi
}

# ---- the menu ------------------------------------------------------------
# One list, built in a single awk pass (see menu.awk): favorites, recents, the
# 27 sections, then every remaining tool below the fold. The default view is
# short; typing searches the whole arsenal, because the picker filters the
# entire list rather than only what is on screen. That is what makes the fast
# path Alt+A -> type -> Enter, with no intermediate "search" row to select.
MENU_LIST="$BAT_CACHE/menu.list"      # the top view: ~30 rows, all destinations
SEARCH_LIST="$BAT_CACHE/search.list"  # every tool, organised, one Enter away

# $1 = 0 for the top view, 1 for the full search list; $2 = output file.
build_menu() {
    # awk aborts if an input file is missing, and on a fresh install neither the
    # favorites nor the recents file exists yet -- which would leave the menu
    # empty on first run. Make sure both are present (empty is fine).
    touch "$BAT_FAVORITES" "$BAT_RECENT" 2>/dev/null
    awk -f "$HERE/menu.awk" \
        -v favfile="$BAT_FAVORITES" \
        -v recfile="$BAT_RECENT" \
        -v secfile="$BAT_CACHE/sections.list" \
        -v reccap="$BAT_RECENT_MAX" -v withtools="$1" \
        -v namew=20 -v blood='#ff2b2b' -v ember="$EMBER" -v faint="$FAINT" \
        "$BAT_FAVORITES" "$BAT_RECENT" \
        "$BAT_CACHE/sections.list" "$BAT_CACHE/all.list" > "$2"
}

# The status strip is the only chrome, so it earns its line: how much there is
# to search, and the one key that is not guessable. Nothing else.
top_status() {
    local n; n="$(wc -l < "$BAT_CACHE/all.list" 2>/dev/null || echo 0)"
    local hint=""
    menu_has_fav_key && hint="  <span foreground='${FAINT}'>· ctrl+s star</span>"
    printf "<span foreground='%s'>%s tools</span>  <span foreground='%s'>· enter to search</span>%s" \
        "$EMBER" "${n// /}" "$FAINT" "$hint"
}

search_status() {
    local n; n="$(wc -l < "$BAT_CACHE/all.list" 2>/dev/null || echo 0)"
    printf "<span foreground='%s'>all %s tools</span>  <span foreground='%s'>· type to search · esc back</span>" \
        "$EMBER" "${n// /}" "$FAINT"
}

section_status() {  # $1 = section title
    printf "<span foreground='%s'>%s</span>  <span foreground='%s'>· type to filter · esc back</span>" \
        "$EMBER" "$(printf '%s' "$1" | pango_escape)" "$FAINT"
}

# Read one row out of a list file by index, into ROW_*.
read_row() {  # $1 = file  $2 = index  $3.. = field names
    local line; line="$(sed -n "$(( $2 + 1 ))p" "$1")"
    [[ -z "$line" ]] && return 1
    IFS=$'\t' read -r ROW_A ROW_B ROW_C _ <<< "$line"
}

# ---- section level -------------------------------------------------------
# Browsing a category, or the full search list. Both are the same thing: a list
# of tools you filter by typing. Same picker, same keys, same star toggle.
pick_from_list() {  # $1 = listfile  $2 = status  $3 = pango col  $4 = plain col
    local listfile="$1" status="$2" pcol="$3" tcol="$4" choice idx
    while true; do
        choice="$(menu_pick "$status" "$listfile" "$pcol" "$tcol")"
        [[ -z "$choice" ]] && return 1              # esc -> back up one level
        if [[ "$choice" == fav\ * ]]; then
            idx="${choice#fav }"
            read_row "$listfile" "$idx" || continue
            # In the search list the binary is column 2; in a section list it is
            # column 1. read_row hands back the first three either way.
            if [[ "$ROW_A" == tool ]]; then toggle_favorite "$ROW_B"
            else toggle_favorite "$ROW_A"; fi
            continue                                 # stay put; starring is the point
        fi
        read_row "$listfile" "$choice" || return 1
        if [[ "$ROW_A" == tool ]]; then
            record_recent "$ROW_B"; launch_tool "$ROW_B" "$ROW_C"
        else
            record_recent "$ROW_A"; launch_tool "$ROW_A" "$ROW_B"
        fi
        return 0
    done
}

browse_section() {  # $1 = slug
    # Two statements on purpose: `local a=$1 b=${a}` does not work, because
    # local declares every name (unset) before running any assignment, so the
    # ${a} on the same line expands to nothing -- and dies under `set -u`.
    local slug="$1"
    local listfile="$BAT_CACHE/section_${slug}.list" title
    [[ -f "$listfile" ]] || return 1
    title="$(awk -F'\t' -v s="$slug" '$3==s{print $2}' "$BAT_CACHE/sections.list")"
    pick_from_list "$listfile" "$(section_status "${title:-tools}")" 3 4
}

search_all() {
    build_menu 1 "$SEARCH_LIST"
    pick_from_list "$SEARCH_LIST" "$(search_status)" 4 5
}

# ---- main loop -----------------------------------------------------------
# The top view is short and every row is a destination: search, the tools this
# user actually uses, then the categories. Esc closes.
while true; do
    build_menu 0 "$MENU_LIST"
    choice="$(menu_pick "$(top_status)" "$MENU_LIST" 4 5)"
    [[ -z "$choice" ]] && break                      # esc -> close the launcher

    if [[ "$choice" == fav\ * ]]; then
        idx="${choice#fav }"
        read_row "$MENU_LIST" "$idx" || continue
        [[ "$ROW_A" == tool ]] && toggle_favorite "$ROW_B"
        continue                                     # reopen, restacked
    fi

    read_row "$MENU_LIST" "$choice" || break
    case "$ROW_A" in
        search) search_all && break ;;               # launched from the list
        sec)    browse_section "$ROW_B" && break ;;
        tool)   record_recent "$ROW_B"
                launch_tool "$ROW_B" "$ROW_C"
                break ;;
        *)      break ;;
    esac
done
