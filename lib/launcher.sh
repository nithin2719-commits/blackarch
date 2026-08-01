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
MENU_LIST="$BAT_CACHE/menu.list"      # the main box: destinations only
LIST_FILE="$BAT_CACHE/list.list"      # whichever folder was opened

# $1 = mode (top | all | favs | recent); $2 = output file.
build_menu() {
    # awk aborts if an input file is missing, and on a fresh install neither the
    # favorites nor the recents file exists yet -- which would leave the menu
    # empty on first run. Make sure both are present (empty is fine).
    touch "$BAT_FAVORITES" "$BAT_RECENT" 2>/dev/null
    awk -f "$HERE/menu.awk" \
        -v favfile="$BAT_FAVORITES" \
        -v recfile="$BAT_RECENT" \
        -v secfile="$BAT_CACHE/sections.list" \
        -v reccap="$BAT_RECENT_MAX" -v mode="$1" \
        -v namew=20 -v blood='#ff2b2b' -v ember="$EMBER" -v faint="$FAINT" \
        "$BAT_FAVORITES" "$BAT_RECENT" \
        "$BAT_CACHE/sections.list" "$BAT_CACHE/all.list" > "$2"

    # Order the search list by name LENGTH, then alphabetically. Ordering is the
    # only lever left for relevance: rofi's -sort measures the whole row, so the
    # row with the shortest DESCRIPTION won rather than the closest name, and
    # "nmap" ranked nmap last behind wnmap and asnmap. Shortest-name-first means
    # the tool you typed the exact name of is the tool at the top, with the
    # longer names that merely contain it underneath.
    if [[ "$1" == all ]]; then
        awk -F'\t' '{ print length($2) "\t" $0 }' "$2" \
            | sort -t$'\t' -k1,1n -k3,3 | cut -f2- > "$2.sorted" \
            && mv "$2.sorted" "$2"
    fi
}

# The status strip is the only chrome, so it earns its line: how much there is
# to search, and the one key that is not guessable. Nothing else.
top_status() {
    local n; n="$(wc -l < "$BAT_CACHE/all.list" 2>/dev/null || echo 0)"
    local hint=""
    menu_has_fav_key && hint="  <span foreground='${FAINT}'>· ctrl+s star</span>"
    printf "<span foreground='%s'>%s tools</span>  <span foreground='%s'>· enter to open</span>%s" \
        "$EMBER" "${n// /}" "$FAINT" "$hint"
}

# One status line shape for every opened folder: what you are looking at, then
# the two keys that work there.
list_status() {  # $1 = label
    local hint=""
    menu_has_fav_key && hint=" · ctrl+s star"
    printf "<span foreground='%s'>%s</span>  <span foreground='%s'>· type to filter%s · esc back</span>" \
        "$EMBER" "$(printf '%s' "$1" | pango_escape)" "$FAINT" "$hint"
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

# ---- opening a folder ----------------------------------------------------
# Every folder -- search, favorites, recent, a category -- is the same thing: a
# list of tools you filter by typing. Same picker, same keys, same star toggle.
pick_from_list() {  # $1 = listfile  $2 = status  $3 = pango col  $4 = plain col  $5 = sort?
    local listfile="$1" status="$2" pcol="$3" tcol="$4" sortmode="${5:-}" choice idx bin pkg
    [[ -s "$listfile" ]] || return 1
    while true; do
        choice="$(menu_pick "$status" "$listfile" "$pcol" "$tcol" "$sortmode")"
        [[ -z "$choice" ]] && return 1              # esc -> back to the main box
        idx="${choice#* }"
        read_row "$listfile" "$idx" || return 1
        # Generated lists carry a kind column, so the binary is field 2; the
        # section lists written by refresh.sh start with the binary itself.
        if [[ "$ROW_A" == tool ]]; then bin="$ROW_B"; pkg="$ROW_C"
        else bin="$ROW_A"; pkg="$ROW_B"; fi
        # Both keys act on the row and leave you in the list: you are curating,
        # not launching, and being thrown back to the main box after every star
        # would make curating a chore.
        if [[ "$choice" == fav\ * ]]; then
            toggle_favorite "$bin"; continue
        fi
        if [[ "$choice" == del\ * ]]; then
            forget_recent "$bin"
            build_menu recent "$LIST_FILE"           # refresh in place
            continue
        fi
        record_recent "$bin"
        launch_tool "$bin" "$pkg"
        return 0
    done
}

open_generated() {  # $1 = mode  $2 = label
    build_menu "$1" "$LIST_FILE"
    pick_from_list "$LIST_FILE" "$(list_status "$2")" 4 5
}

browse_section() {  # $1 = slug
    # Two statements on purpose: `local a=$1 b=${a}` does not work, because
    # local declares every name (unset) before running any assignment, so the
    # ${a} on the same line expands to nothing -- and dies under `set -u`.
    local slug="$1"
    local listfile="$BAT_CACHE/section_${slug}.list" title
    [[ -f "$listfile" ]] || return 1
    title="$(awk -F'\t' -v s="$slug" '$3==s{print $2}' "$BAT_CACHE/sections.list")"
    pick_from_list "$listfile" "$(list_status "${title:-tools}")" 3 4
}

# ---- main loop -----------------------------------------------------------
# The main box holds destinations and nothing else: search, the folders this
# user has earned (favorites, recent), then the categories. Esc closes.
while true; do
    build_menu top "$MENU_LIST"
    choice="$(menu_pick "$(top_status)" "$MENU_LIST" 4 5)"
    [[ -z "$choice" ]] && break                      # esc -> close the launcher
    # Starring is meaningless on a folder row; ignore the key here.
    [[ "$choice" == fav\ * || "$choice" == del\ * ]] && continue

    read_row "$MENU_LIST" "$choice" || break
    case "$ROW_A" in
        search) open_generated all    "all tools"  && break ;;
        favs)   open_generated favs   "Favorites"  && break ;;
        recent) open_generated recent "Recent"     && break ;;
        sec)    browse_section "$ROW_B"            && break ;;
        *)      break ;;
    esac
done
