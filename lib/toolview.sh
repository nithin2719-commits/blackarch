#!/usr/bin/env bash
# The screen a CLI tool opens into. Args: <binary> <package>
#
# Goal: never leave the user staring at a blank prompt wondering how the tool
# runs. We show, in order:
#   - the tool name as a banner (inline image under kitty, ASCII elsewhere)
#   - one-line description + version, from package metadata when available
#   - the real usage/synopsis, pulled from --help / -h / man (whichever answers)
#   - a curated quick-start for the common tools
#   - the flag list
# ...then hand over an interactive shell already scoped to that tool, with a
# prompt that shows which tool you are in and history kept per-tool.

set -uo pipefail

HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/paths.sh"
# shellcheck source=/dev/null
source "$HERE/ui.sh"
# shellcheck source=/dev/null
source "$HERE/examples.sh"

BIN="${1:?binary}"
PKG="${2:-}"
ALT="${BIN//-/_}"     # some tools install foo_bar for package foo-bar

printf '\033c'        # hard reset: clear screen + scrollback

# kitty maximizes the window a beat AFTER the shell starts, so reading the
# width immediately gives the default 80 and every rule comes out stubby. A
# short settle lets the resize land. (~150ms — imperceptible, and the
# help-gathering below overlaps it.)
[[ "$TERM" == xterm-kitty ]] && sleep 0.15

# ---- brand banner --------------------------------------------------------
# Under kitty we draw the BlackArch logo as an inline image anchored to real
# text cells (--unicode-placeholder), so it REFLOWS when the window is tiled or
# fullscreen-toggled. Everywhere else we fall back to a bold text wordmark, so
# the screen still has a clear identity in any terminal.
LOGO_IMG="$BAT_ASSETS/header_disp.png"

render_toolname() {
    TN_IMG=""
    command -v magick >/dev/null 2>&1 || return
    local out="$BAT_CACHE/tn_${BIN//[^A-Za-z0-9_.-]/_}.png" esc
    if [[ ! -f "$out" ]]; then
        esc="$(printf '%s' "$BIN" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')"
        printf '<span font="Orbitron" weight="bold" size="52000" foreground="#f0e6e6">%s</span>' "$esc" > "$BAT_CACHE/.tn.txt"
        magick -background none pango:@"$BAT_CACHE/.tn.txt" -trim +repage "$out" 2>/dev/null
        magick "$out" -resize x50 -background none -gravity west -splice 26x0 "$out" 2>/dev/null
        rm -f "$BAT_CACHE/.tn.txt"
    fi
    [[ -f "$out" ]] && TN_IMG="$out"
}

header() {
    local rc=1
    printf '\n'
    if [[ "$TERM" == xterm-kitty ]] && [[ -f "$LOGO_IMG" ]] && command -v kitty >/dev/null 2>&1; then
        kitty +kitten icat --unicode-placeholder --align left "$LOGO_IMG" 2>/dev/null && rc=0
        if ((rc == 0)); then
            printf '\n'
            render_toolname
            [[ -n "$TN_IMG" ]] && kitty +kitten icat --unicode-placeholder --align left "$TN_IMG" 2>/dev/null
        fi
    fi
    if ((rc != 0)); then
        printf '  %s%sBLACK%s%s%sARCH%s\n' "$BONE" "$BOLD" "$RESET" "$BLOOD" "$BOLD" "$RESET"
        printf '  %s%s%s%s\n\n' "$BONE" "$BOLD" "$BIN" "$RESET"
    fi
}
header

# ---- tool identity: description + package + version ----------------------
desc=""; ver=""
if [[ -n "$PKG" ]] && command -v pacman >/dev/null 2>&1; then
    while IFS= read -r line; do
        case "$line" in
            Version*)     ver="${line#*: }" ;;
            Description*) desc="${line#*: }" ;;
        esac
    done < <(pacman -Qi "$PKG" 2>/dev/null)
elif [[ -n "$PKG" ]] && command -v dpkg-query >/dev/null 2>&1; then
    ver="$(dpkg-query -W -f='${Version}' "$PKG" 2>/dev/null)"
    desc="$(dpkg-query -W -f='${binary:Summary}' "$PKG" 2>/dev/null)"
elif [[ -n "$PKG" ]] && command -v rpm >/dev/null 2>&1; then
    ver="$(rpm -q --qf '%{VERSION}' "$PKG" 2>/dev/null)"
    desc="$(rpm -q --qf '%{SUMMARY}' "$PKG" 2>/dev/null)"
fi
{
    printf '  %s%s%s' "$ASH" "${desc:-$BIN}" "$RESET"
    [[ -n "$PKG" ]] && printf '   %s·  %s%s' "$STEEL" "$PKG" "$RESET"
    [[ -n "$ver" ]] && printf '   %s·  %s%s' "$STEEL" "$ver" "$RESET"
    printf '\n'
}
echo

# ---- path actually used --------------------------------------------------
REAL="$BIN"
command -v "$BIN" >/dev/null 2>&1 || { command -v "$ALT" >/dev/null 2>&1 && REAL="$ALT"; }

# ---- usage / help (cached: first open computes, reopens are instant) -----
HELP_CACHE="$BAT_CACHE/help_${BIN//[^A-Za-z0-9_.-]/_}"
if [[ -s "$HELP_CACHE" ]]; then
    HELP="$(<"$HELP_CACHE")"
else
    HELP=""
    declare -A seen=()
    for probe in "$REAL --help" "$REAL -h" "$ALT --help" "$ALT -h"; do
        read -r cmd flag <<<"$probe"
        command -v "$cmd" >/dev/null 2>&1 || continue
        [[ -n "${seen[$probe]:-}" ]] && continue; seen[$probe]=1
        HELP="$(timeout 3 "$cmd" "$flag" 2>&1)"
        [[ -n "$HELP" ]] && break
    done
    [[ -z "$HELP" ]] && HELP="$(man "$REAL" 2>/dev/null | col -bx | sed -n '/^SYNOPSIS/,/^[A-Z]/p' | head -40)"
    printf '%s' "$HELP" > "$HELP_CACHE" 2>/dev/null || true
fi

# Some tools crash on --help and dump a traceback instead of usage. That is not
# help -- blank it so the clean "no built-in help" panel shows instead.
if printf '%s\n' "$HELP" | grep -qE 'Traceback \(most recent call last\)|^[[:space:]]*File ".*", line [0-9]+, in|(Syntax|Import|ModuleNotFound|Name|Type|Value|Attribute|Runtime|Index|Key)Error:'; then
    HELP=""
fi

SYNOPSIS="$(printf '%s\n' "$HELP" | grep -iE '^\s*(usage|synopsis)[: ]' | head -1 | sed -E 's/^\s*(usage|synopsis)[: ]+//I')"

# ---- how to run (one-line synopsis) --------------------------------------
if [[ -n "$SYNOPSIS" ]]; then
    ui_head "HOW TO RUN"; echo
    ui_cmd "$SYNOPSIS"; echo
fi

# ---- curated quick-start (common tools only) -----------------------------
if EX="$(ba_examples "$BIN")"; then
    ui_head "QUICK START"; echo
    while IFS=$'\t' read -r cmd note; do
        [[ -z "$cmd" ]] && continue
        ui_cmd "$cmd" "$note"
    done <<<"$EX"
    echo
fi

HELP_CLEAN="$(printf '%s\n' "$HELP" | awk -f "$HERE/cleanhelp.awk" | cat -s)"
if [[ -n "${HELP_CLEAN//[[:space:]]/}" ]]; then
    ui_head "USAGE & FLAGS"; echo
    # Highlight flags (-x, --xxx) in ember; indent every line to column 2.
    printf '%s\n' "$HELP_CLEAN" | head -60 | sed -E \
        "s/([[:space:]]|^)(--?[A-Za-z][A-Za-z0-9-]*)/\1$(printf '\033')[38;2;255;122;69m\2$(printf '\033')[38;2;154;125;125m/g" \
        | sed "s/^/  $(printf '\033')[38;2;154;125;125m/"
    printf '%s\n' "$RESET"
else
    ui_head "USAGE & FLAGS"; echo
    ui_note "No usage text available — this tool returned no readable help"
    ui_note "(no --help/-h output, and no man synopsis)."
    echo
    ui_cmd "$REAL" "run it and read its own prompt / usage"
    ui_cmd "man $REAL" "open the manual page, if any"
    echo
fi

# ---- footer --------------------------------------------------------------
echo
printf "  %srun%s %s%s ...%s     %sman%s %s%s%s     %sexit%s %sclose window%s\n" \
    "$EMBER" "$RESET" "$BONE" "$REAL" "$RESET" \
    "$EMBER" "$RESET" "$BONE" "man $REAL" "$RESET" \
    "$EMBER" "$RESET" "$ASH" "$RESET"
echo

# ---- interactive shell scoped to this tool -------------------------------
TMPRC="$(mktemp "${TMPDIR:-/tmp}/ba_rc_XXXXXX")"
{
    cat <<'RC'
__ba_ps() {
    local ec=$? st
    if ((ec==0)); then st=$'\033[38;2;255;122;69m✔\033[0m'
    else st=$'\033[38;2;255;43;43m✘ '"$ec"$'\033[0m'; fi
    printf -v PS1 \
      '\[\033[38;2;90;72;72m\]┌─[\[\033[38;2;255;43;43m\]\[\033[1m\]%s\[\033[0m\]\[\033[38;2;90;72;72m\]]─[\[\033[38;2;154;125;125m\]\w\[\033[38;2;90;72;72m\]]─[%s\[\033[38;2;90;72;72m\]]─[\[\033[38;2;154;125;125m\]\t\[\033[38;2;90;72;72m\]]\n└─\[\033[38;2;255;43;43m\]❯\[\033[0m\] ' \
      "$__BA_TOOL" "$st"
}
PROMPT_COMMAND=__ba_ps
RC
    printf '__BA_TOOL=%q\n' "$BIN"
    printf 'HISTFILE=%q\n' "$BAT_CACHE/hist_${BIN//[^A-Za-z0-9_.-]/_}"
    printf 'HISTCONTROL=ignoreboth\n'
    printf 'alias help=%q\n' "$REAL --help 2>&1 | \${PAGER:-less -R}"
    printf 'alias flags=%q\n' "$REAL --help 2>&1 | grep -E '^\\s*-' | \${PAGER:-less -R}"
    printf 'alias man=%q\n' "man $REAL"
    printf 'alias run=%q\n' "$REAL"
} > "$TMPRC"

exec bash --rcfile "$TMPRC"
