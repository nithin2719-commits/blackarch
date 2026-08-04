#!/usr/bin/env bash
# BlackArch Toolbox — launcher core.
#
# Two-level menu over an index of *runnable* tools (see refresh.sh):
#   section  ->  tool  ->  launch
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

# ---- section level -------------------------------------------------------
# A clean top menu: a single "Search all tools" entry first (open it to
# type-search the whole arsenal), then the section headers to browse. The full
# tool list is never dumped into the top view -- it appears only inside the
# search or a section, so the default view stays tidy.
build_sections() {
    SEC_PANGO=(); SEC_PLAIN=(); SEC_SLUG=()
    local NAMEW=20 icon name slug count ename padded
    SEC_PANGO+=("<span foreground='${EMBER}'></span>   <b>$(printf '%-*s' "$NAMEW" 'Search all tools')</b>  <span size='small' foreground='${FAINT}'>type any tool name  ›</span>")
    SEC_PLAIN+=("$(printf '  %-*s  %s' "$NAMEW" 'Search all tools' 'type any tool name')")
    SEC_SLUG+=("__search__")
    while IFS=$'\t' read -r icon name slug count; do
        padded="$(printf '%-*s' "$NAMEW" "$name")"
        ename="$(printf '%s' "$padded" | pango_escape)"
        SEC_PANGO+=("<span foreground='#ff2b2b'>${icon}</span>  <b>${ename}</b>  <span size='small' foreground='${FAINT}'>$(printf '%4s' "$count") tools  ›</span>")
        SEC_PLAIN+=("$(printf '%s %-*s  %4s tools  >' "$icon" "$NAMEW" "$name" "$count")")
        SEC_SLUG+=("$slug")
    done < "$BAT_CACHE/sections.list"
}

# ---- tool level ----------------------------------------------------------
# Section/all list rows are pre-rendered:  bin \t pkg \t pango \t plain
# One pass, no per-row forks: the display columns are already escaped and
# truncated by refresh.sh, so this is pure array loading. A single read over the
# file beats four `cut` subprocesses, so even the 4000-row "search all" list
# loads in well under a tenth of a second.
build_tools() {  # $1 = list file
    TOOL_PANGO=(); TOOL_PLAIN=(); TOOL_BIN=(); TOOL_PKG=()
    local bin pkg pango plain
    while IFS=$'\t' read -r bin pkg pango plain; do
        [[ -z "$bin" ]] && continue
        TOOL_BIN+=("$bin"); TOOL_PKG+=("$pkg")
        TOOL_PANGO+=("$pango"); TOOL_PLAIN+=("$plain")
    done < "$1"
}

top_status() {
    local n; n="$(wc -l < "$BAT_CACHE/all.list" 2>/dev/null)"
    printf "<span foreground='%s'>open <b>Search all tools</b> to find any of</span>  <span foreground='%s'><b>%s</b> tools</span>  <span foreground='%s'>·  or browse a section</span>" \
        "$DIM" "$EMBER" "${n:-0}" "$FAINT"
}

# Open a focused tool list (whole arsenal or one section) and launch the pick.
pick_and_launch() {  # $1 = listfile  $2 = prompt  $3 = mesg
    build_tools "$1"
    local tidx; tidx="$(menu_pick "$2" "$3" TOOL_PLAIN TOOL_PANGO)"
    [[ -z "$tidx" ]] && return 1
    launch_tool "${TOOL_BIN[$tidx]}" "${TOOL_PKG[$tidx]}"
}

# ---- main loop -----------------------------------------------------------
# Two clean levels: the top shows "Search all tools" + the sections; picking
# either opens a focused, type-to-filter list. The full tool list is never
# dumped into the top view.
while true; do
    build_sections
    idx="$(menu_pick "󰣇 BlackArch" "$(top_status)" SEC_PLAIN SEC_PANGO)"
    [[ -z "$idx" ]] && break
    slug="${SEC_SLUG[$idx]}"

    if [[ "$slug" == "__search__" ]]; then
        pick_and_launch "$BAT_CACHE/all.list" "󰣇 search all" "type a tool name · ESC back" || continue
        break
    fi

    listfile="$BAT_CACHE/section_${slug}.list"
    [[ -f "$listfile" ]] || continue
    title="$(awk -F'\t' -v s="$slug" '$3==s{print $2}' "$BAT_CACHE/sections.list")"
    pick_and_launch "$listfile" "󰣇 ${title:-tools}" "ESC · back to menu" || continue
    break
done
