#!/usr/bin/env bash
# Menu abstraction.
#
# The picker is the one piece that has to bend to the user's environment: on a
# Wayland desktop it should be a real graphical launcher; over plain SSH it must
# fall back to something that works in a bare terminal. Rather than hard-wire
# rofi (X11/Wayland only) the way the original did, this detects what is present
# and exposes a single `menu_pick` that every caller uses.
#
# Every backend returns the selected row INDEX (0-based) on stdout, empty when
# cancelled -- so the pretty display column stays fully decoupled from the value
# we act on. No parsing of marked-up strings, ever.
#
# Order of preference (auto): rofi > fuzzel > wofi > dmenu   [graphical]
#                             fzf                            [terminal fallback]

MENU_BACKEND=""     # resolved once by menu_init

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

# menu_pick <prompt> <message> <plain-lines-var> <pango-lines-var>
#   The caller passes the NAMES of two arrays (plain + pango display rows). We
#   feed whichever the chosen backend can render and echo the picked index.
menu_pick() {
    local prompt="$1" mesg="$2"
    local -n _plain="$3" _pango="$4"

    case "$MENU_BACKEND" in
        rofi)   _menu_rofi   "$prompt" "$mesg" _pango ;;
        fuzzel) _menu_fuzzel "$prompt" "$mesg" _plain ;;
        wofi)   _menu_wofi   "$prompt" "$mesg" _plain ;;
        dmenu)  _menu_dmenu  "$prompt" "$mesg" _plain ;;
        fzf)    _menu_fzf    "$prompt" "$mesg" _plain ;;
        *)      return 1 ;;
    esac
}

_menu_rofi() {
    local prompt="$1" mesg="$2"; local -n _rows="$3"
    local theme; theme="$(bat_theme_file rofi/blackarch-theme.rasi)"
    local icon="/usr/share/icons/Papirus/64x64/apps/distributor-logo-blackarch.svg"
    # rofi runs as its normal layer surface so it slides in via Hyprland's layer
    # animation and the theme draws its red frame. (-normal-window is avoided: it
    # yields an unmanaged override-redirect window with no rules/animation.)
    # -matching normal (substring), NOT fuzzy: fuzzy scatters the query letters
    # across the row and matched "mentalist" for "metasploit". Substring keeps
    # "metasp" to the metasploit family and nothing else.
    #
    # The prompt widget is where the BlackArch lockup lives: the theme paints it
    # as that widget's background-image scaled to the widget's WIDTH, and rofi
    # sizes the widget from its prompt TEXT -- which the theme renders
    # transparent. So the prompt string, invisible as it is, silently decided how
    # big the logo came out ("Recon" halved it, "search all" stretched it). Hand
    # rofi one constant prompt so the brand renders identically at every level;
    # the caller's label rides in the message strip, where it can be read. Only
    # this backend needs it -- the others draw the prompt as real text.
    local args=(-dmenu -i -matching normal -markup-rows -format i
        -theme "$theme" -lines 14 -p '󰣇 BlackArch')
    [[ -f "$icon" ]] && args+=(-window-icon "$icon")
    [[ -n "$mesg" ]] && args+=(-mesg "$mesg")
    printf '%s\n' "${_rows[@]}" | rofi "${args[@]}"
}

# fuzzel/wofi/dmenu have no "return the index" mode, so we prepend a hidden
# ordinal to every row, match on it, and strip it back off. The ordinal is
# right-padded so the visible columns still line up.
_menu_indexed() {  # $1 cmd-array-name  $2 rows-var  -> prints index
    local -n _cmd="$1" _rows="$2"
    local i out
    out="$( { for i in "${!_rows[@]}"; do printf '%4d %s\n' "$i" "${_rows[$i]}"; done; } \
            | "${_cmd[@]}" )" || return 1
    [[ -z "$out" ]] && return 1
    printf '%s' "${out%%$' '*}" | tr -d ' '
}

_menu_fuzzel() {
    local prompt="$1" mesg="$2"; local -n _rows="$3"
    local -a cmd=(fuzzel --dmenu --prompt "$prompt> " --lines 14 --width 64)
    _menu_indexed cmd _rows
}

_menu_wofi() {
    local prompt="$1" mesg="$2"; local -n _rows="$3"
    local -a cmd=(wofi --dmenu --prompt "$prompt" --insensitive --lines 14 --width 640)
    _menu_indexed cmd _rows
}

_menu_dmenu() {
    local prompt="$1" mesg="$2"; local -n _rows="$3"
    local -a cmd=(dmenu -i -l 14 -p "$prompt")
    _menu_indexed cmd _rows
}

_menu_fzf() {
    local prompt="$1" mesg="$2"; local -n _rows="$3"
    local header="$prompt"; [[ -n "$mesg" ]] && header="$prompt — $mesg"
    # Prefix each row with a tab-delimited index; fzf matches on the visible
    # column (2..) and we recover the hidden index from the chosen line.
    local i out
    out="$( { for i in "${!_rows[@]}"; do printf '%d\t%s\n' "$i" "${_rows[$i]}"; done; } \
        | fzf --delimiter '\t' --with-nth 2.. --nth 2.. \
              --prompt 'search> ' --header "$header" \
              --height 90% --reverse --ansi \
              --color 'fg:#f0e6e6,bg:#0a0607,hl:#ff7a45,fg+:#ffffff,bg+:#23090b,hl+:#ff2b2b,prompt:#ff2b2b,header:#ff7a45,border:#ff2b2b' \
              --border \
        )" || return 1
    [[ -z "$out" ]] && return 1
    printf '%s' "${out%%$'\t'*}"
}
