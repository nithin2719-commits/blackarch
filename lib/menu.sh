#!/usr/bin/env bash
# Menu abstraction.
#
# The picker is the one piece that has to bend to the user's environment: on a
# Wayland desktop it should be a real graphical launcher; over plain SSH it must
# work in a bare terminal. Rather than hard-wire rofi (X11/Wayland only) this
# detects what is present and exposes a single `menu_pick` every caller uses.
#
# Rows are read straight from a FILE, never loaded into a bash array: the menu
# list is ~4200 rows and building an array that size was the original source of
# open-lag. The chosen row is recovered by line number, so the pretty display
# column stays fully decoupled from the value we act on -- no parsing of
# marked-up strings, ever.
#
# menu_pick prints one of:
#     <index>        a row was accepted
#     fav <index>    the favourite-toggle key was pressed on that row
#     (nothing)      cancelled
#
# Order of preference (auto): rofi > fuzzel > wofi > dmenu   [graphical]
#                             fzf                            [terminal fallback]

MENU_BACKEND=""     # resolved once by menu_init

# The one non-obvious key in the whole UI: Ctrl+S, s for star.
#
# It has to be free in the picker AND in the compositor. Alt+Return looked ideal
# -- right next to Return, which launches -- until testing showed Hyprland grabs
# it for `fullscreen`, so rofi never saw the key and starring silently did
# nothing. rofi's line editing already owns Alt+f, Control+f/e/g and
# Control+space; stealing those would break editing for anyone who uses it.
MENU_FAV_KEY_ROFI='Control+s'
MENU_FAV_KEY_FZF='ctrl-s'

menu_init() {
    local want="${BAT_MENU:-auto}"
    if [[ "$want" != auto ]]; then
        command -v "$want" >/dev/null 2>&1 \
            && { MENU_BACKEND="$want"; return 0; }
        ui_warn "menu '$want' not found, falling back to auto-detect"
    fi

    # A graphical launcher only makes sense with a display server attached.
    if [[ -n "${WAYLAND_DISPLAY:-}${DISPLAY:-}" ]]; then
        local m
        for m in rofi fuzzel wofi dmenu; do
            command -v "$m" >/dev/null 2>&1 && { MENU_BACKEND="$m"; return 0; }
        done
    fi
    # Headless / SSH / TTY: fzf is the graceful degradation.
    command -v fzf >/dev/null 2>&1 && { MENU_BACKEND="fzf"; return 0; }

    return 1
}

# Backends that can report the favourite-toggle key. The others still SHOW
# favourites -- they just cannot toggle one, so the launcher hides the hint
# rather than advertising a key that does nothing there.
menu_has_fav_key() {
    case "$MENU_BACKEND" in rofi|fzf) return 0 ;; *) return 1 ;; esac
}

# menu_pick <mesg> <listfile> <pango-col> <plain-col>
menu_pick() {
    local mesg="$1" file="$2" pcol="$3" tcol="$4"
    case "$MENU_BACKEND" in
        rofi)   _menu_rofi   "$mesg" "$file" "$pcol" ;;
        fuzzel) _menu_fuzzel "$mesg" "$file" "$tcol" ;;
        wofi)   _menu_wofi   "$mesg" "$file" "$tcol" ;;
        dmenu)  _menu_dmenu  "$mesg" "$file" "$tcol" ;;
        fzf)    _menu_fzf    "$mesg" "$file" "$tcol" ;;
        *)      return 1 ;;
    esac
}

_menu_rofi() {
    local mesg="$1" file="$2" col="$3" out rc
    local theme; theme="$(bat_theme_file rofi/blackarch-theme.rasi)"
    local icon="/usr/share/icons/Papirus/64x64/apps/distributor-logo-blackarch.svg"

    # rofi runs as its normal layer surface so it slides in via the compositor's
    # layer animation and the theme draws its frame. (-normal-window is avoided:
    # it yields an unmanaged override-redirect window with no rules/animation.)
    #
    # -matching normal (substring), NOT fuzzy: fuzzy scatters the query letters
    # across the row and matched "mentalist" for "metasploit".
    #
    # The prompt is a constant: the theme paints the BlackArch lockup as the
    # prompt widget's background-image, scaled to that widget's width, and rofi
    # sizes the widget from its prompt TEXT -- so a varying prompt silently
    # resized the brand. The context goes in the message strip instead.
    local args=(-dmenu -i -matching normal -markup-rows -format i
        -theme "$theme" -lines 14 -p '󰣇 BlackArch'
        -kb-custom-1 "$MENU_FAV_KEY_ROFI")
    [[ -f "$icon" ]] && args+=(-window-icon "$icon")
    [[ -n "$mesg" ]] && args+=(-mesg "$mesg")

    out="$(cut -f"$col" "$file" | rofi "${args[@]}")"; rc=$?
    [[ -z "$out" ]] && return 1
    # rofi exits 10 for -kb-custom-1, 11 for -custom-2, and so on.
    if [[ $rc -eq 10 ]]; then printf 'fav %s' "$out"; else printf '%s' "$out"; fi
}

# fuzzel/wofi/dmenu have no "return the index" mode, so we prepend a hidden
# ordinal to every row, then strip it back off. The ordinal is right-padded so
# the visible columns still line up.
_menu_indexed() {  # $1 cmd-array-name  $2 file  $3 col
    local -n _cmd="$1"
    local out
    out="$(cut -f"$3" "$2" | awk '{ printf "%4d %s\n", NR-1, $0 }' | "${_cmd[@]}")" || return 1
    [[ -z "$out" ]] && return 1
    printf '%s' "${out%%$' '*}" | tr -d ' '
}

_menu_fuzzel() {
    local -a cmd=(fuzzel --dmenu --prompt 'BlackArch> ' --lines 14 --width 64)
    _menu_indexed cmd "$2" "$3"
}

_menu_wofi() {
    local -a cmd=(wofi --dmenu --prompt 'BlackArch' --insensitive --lines 14 --width 640)
    _menu_indexed cmd "$2" "$3"
}

_menu_dmenu() {
    local -a cmd=(dmenu -i -l 14 -p 'BlackArch')
    _menu_indexed cmd "$2" "$3"
}

_menu_fzf() {
    local mesg="$1" file="$2" col="$3" out key idx
    # Strip the pango markup out of the message for a terminal header.
    local header; header="$(printf '%s' "$mesg" | sed -e 's/<[^>]*>//g')"
    # Each row is prefixed with a hidden index; fzf matches on the visible
    # column only (2..) and we recover the index from the chosen line.
    # --exact keeps the substring semantics rofi has, so the two behave alike.
    out="$(cut -f"$col" "$file" \
        | awk '{ printf "%d\t%s\n", NR-1, $0 }' \
        | fzf --delimiter '\t' --with-nth 2.. --nth 2.. \
              --exact --prompt 'search> ' --header "$header" \
              --height 90% --reverse --ansi \
              --expect "$MENU_FAV_KEY_FZF" \
              --color 'fg:#f0e6e6,bg:#0a0607,hl:#ff7a45,fg+:#ffffff,bg+:#23090b,hl+:#ff2b2b,prompt:#ff2b2b,header:#ff7a45,border:#ff2b2b' \
              --border \
        )" || return 1
    [[ -z "$out" ]] && return 1
    # With --expect, fzf prints the pressed key (or an empty line) first.
    key="$(printf '%s' "$out" | head -1)"
    idx="$(printf '%s' "$out" | sed -n '2p')"; idx="${idx%%$'\t'*}"
    [[ -z "$idx" ]] && return 1
    if [[ "$key" == "$MENU_FAV_KEY_FZF" ]]; then printf 'fav %s' "$idx"
    else printf '%s' "$idx"; fi
}
