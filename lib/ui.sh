#!/usr/bin/env bash
# Shared look for the toolbox terminal screens.
#
# Palette keeps BlackArch's red-on-black identity but picks its neutrals
# deliberately: the greys are warmed toward the accent instead of being pure
# mid-grey, so dim text reads as part of the design rather than as washed-out
# body copy. Only two levels of red are used -- one for structure, one for
# emphasis -- so the eye has somewhere to land.

# 24-bit where the terminal advertises it; a 16-colour ramp everywhere else, so
# the same screens stay readable in tmux, the Linux console and PuTTY.
if [[ "${COLORTERM:-}" == truecolor || "${COLORTERM:-}" == 24bit ]]; then
    BLOOD=$'\033[38;2;255;43;43m'    # primary accent - rules, headings
    EMBER=$'\033[38;2;255;122;69m'   # secondary - section labels, keys
    ASH=$'\033[38;2;154;125;125m'    # dim body - warm grey, biased to accent
    BONE=$'\033[38;2;240;230;230m'   # bright body
    STEEL=$'\033[38;2;90;72;72m'     # faint - rules, disabled
else
    BLOOD=$'\033[1;31m'; EMBER=$'\033[0;33m'
    ASH=$'\033[0;37m';   BONE=$'\033[1;37m'; STEEL=$'\033[1;30m'
fi
BOLD=$'\033[1m'; DIM=$'\033[2m'; RESET=$'\033[0m'

# NO_COLOR is honoured (https://no-color.org) so the screens can be piped into
# a file or a log without carrying escape sequences along.
if [[ -n "${NO_COLOR:-}" ]]; then
    BLOOD=''; EMBER=''; ASH=''; BONE=''; STEEL=''; BOLD=''; DIM=''; RESET=''
fi

ui_width() { local w="${COLUMNS:-0}"; ((w < 20)) && w=$(tput cols 2>/dev/null || echo 100); echo "$w"; }

# A horizontal rule that fills the terminal.
# Built with bash parameter expansion, NOT `tr`: tr substitutes byte-for-byte
# and cannot emit a 3-byte box glyph like the heavy rule, which produced
# mojibake instead of a line.
ui_fill() {                      # ui_fill <char> <count> -> repeated string
    local ch="$1" n="$2" pad
    printf -v pad '%*s' "$n" ''
    printf '%s' "${pad// /$ch}"
}
ui_rule() {
    local ch="${1:-─}" color="${2:-$STEEL}" w; w=$(ui_width)
    printf '%s%s%s\n' "$color" "$(ui_fill "$ch" "$w")" "$RESET"
}

# Section heading: a solid accent block + the label, no full-width rule.
# The long rules read as visual clutter; a short accent bar separates sections
# just as clearly with far less ink.
ui_head() {
    local label="$1"
    printf '  %s%s▊%s %s%s%s%s\n' "$BLOOD" "$BOLD" "$RESET" "$BLOOD" "$BOLD" "$label" "$RESET"
}

# key: value line, keys right-aligned to a common column so values line up.
ui_kv() { printf "  %s%10s%s  %s%s%s\n" "$EMBER" "$1" "$RESET" "$ASH" "$2" "$RESET"; }

# A command example: prompt marker, then the command in bright, then a comment.
ui_cmd() {
    printf "  %s%s%s %s%s%s\n" "$BLOOD" '›' "$RESET" "$BONE" "$1" "$RESET"
    [[ -n "${2:-}" ]] && printf "    %s%s%s\n" "$STEEL" "$2" "$RESET"
}

ui_note() { printf "  %s%s%s\n" "$ASH" "$1" "$RESET"; }
ui_warn() { printf "  %s%s%s\n" "$EMBER" "$1" "$RESET" >&2; }
ui_die()  { printf "  %s%s%s\n" "$BLOOD" "$1" "$RESET" >&2; exit "${2:-1}"; }
