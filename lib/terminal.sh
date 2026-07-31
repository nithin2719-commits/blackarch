#!/usr/bin/env bash
# Terminal abstraction.
#
# A CLI tool opens into a themed terminal that shows its usage first (see
# toolview.sh). kitty is the ideal host -- it renders the inline logo images and
# reads our theme file -- but it is not everywhere, so this picks the best
# available emulator and translates the "run this command in a new window with
# this title" request into that emulator's own flag spelling, which is
# maddeningly inconsistent between them.
#
# When no emulator is found at all (e.g. a pure SSH session with no $TERM host
# to spawn into) the tool view is run in the CURRENT terminal instead, so the
# feature degrades to "it still works" rather than "nothing happens".

TERM_BACKEND=""

term_init() {
    local want="${BAT_TERMINAL:-auto}"
    if [[ "$want" != auto ]]; then
        command -v "$want" >/dev/null 2>&1 && { TERM_BACKEND="$want"; return 0; }
        ui_warn "terminal '$want' not found, auto-detecting"
    fi
    if [[ -n "${WAYLAND_DISPLAY:-}${DISPLAY:-}" ]]; then
        local t
        for t in kitty alacritty foot wezterm konsole gnome-terminal \
                 xfce4-terminal x-terminal-emulator xterm; do
            command -v "$t" >/dev/null 2>&1 && { TERM_BACKEND="$t"; return 0; }
        done
    fi
    TERM_BACKEND="inline"   # no windowing: run in the caller's terminal
    return 0
}

# term_run <title> <command...>
term_run() {
    local title="$1"; shift
    local kitty_conf; kitty_conf="$(bat_theme_file kitty/blackarch-tool.conf)"

    case "$TERM_BACKEND" in
        kitty)
            # Full window on purpose: the tool view prints the tool's usage and
            # full flag list before handing over the shell, and that needs the
            # width. --class gives the compositor a stable handle for per-window
            # rules; --directory puts the shell in $HOME so a tool's output
            # lands somewhere sane rather than in the launcher's own directory.
            setsid kitty --config "$kitty_conf" --title "$title" \
                --class blackarch-toolview --directory "$HOME" \
                --start-as maximized -e "$@" >/dev/null 2>&1 &
            ;;
        alacritty)
            setsid alacritty --class blackarch-toolview --title "$title" \
                --working-directory "$HOME" -e "$@" >/dev/null 2>&1 & ;;
        foot)
            setsid foot --app-id blackarch-toolview --title "$title" \
                -- "$@" >/dev/null 2>&1 & ;;
        wezterm)
            setsid wezterm start --class blackarch-toolview --cwd "$HOME" \
                -- "$@" >/dev/null 2>&1 & ;;
        konsole)
            setsid konsole --title "$title" -e "$@" >/dev/null 2>&1 & ;;
        gnome-terminal)
            setsid gnome-terminal --title "$title" -- "$@" >/dev/null 2>&1 & ;;
        xfce4-terminal)
            setsid xfce4-terminal --title "$title" -x "$@" >/dev/null 2>&1 & ;;
        x-terminal-emulator|xterm)
            setsid "$TERM_BACKEND" -T "$title" -e "$@" >/dev/null 2>&1 & ;;
        inline|*)
            # No emulator to spawn: just run it here and now.
            "$@"
            return $?
            ;;
    esac
    disown 2>/dev/null || true
}
