#!/usr/bin/env bash
# Path resolution shared by every entry point.
#
# The repo is read-only once installed (it may live in /opt or /usr/local/share
# and be owned by root), so generated state is deliberately kept OUT of it and
# written under the XDG cache directory instead. That separation is what lets a
# single system-wide install serve several users, each with their own index,
# help cache and per-tool shell history.

# Root of the checkout / install, resolved through symlinks so that a
# `blackarch-toolbox` symlink dropped in ~/.local/bin still finds lib/.
_bat_resolve_root() {
    local src="${BASH_SOURCE[0]}" dir
    while [[ -L "$src" ]]; do
        dir="$(cd -P "$(dirname "$src")" && pwd)"
        src="$(readlink "$src")"
        [[ "$src" != /* ]] && src="$dir/$src"
    done
    cd -P "$(dirname "$src")/.." && pwd
}

BAT_ROOT="${BAT_ROOT:-$(_bat_resolve_root)}"
BAT_LIB="$BAT_ROOT/lib"
BAT_DATA="$BAT_ROOT/data"
BAT_ASSETS="$BAT_ROOT/assets"

BAT_CACHE="${BAT_CACHE:-${XDG_CACHE_HOME:-$HOME/.cache}/blackarch-toolbox}"
BAT_CONFIG_DIR="${BAT_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/blackarch-toolbox}"
BAT_CONFIG="$BAT_CONFIG_DIR/config"

mkdir -p "$BAT_CACHE" "$BAT_CONFIG_DIR" 2>/dev/null || true

# ---- user settings -------------------------------------------------------
# Defaults first, then the user's config file overrides them. Every one of
# these can also be exported in the environment for a one-off run, which is
# what makes `BAT_MENU=fzf blackarch-toolbox` work over SSH.
BAT_MENU="${BAT_MENU:-auto}"          # auto | rofi | wofi | fuzzel | dmenu | fzf
BAT_TERMINAL="${BAT_TERMINAL:-auto}"  # auto | kitty | alacritty | foot | ...
BAT_BACKEND="${BAT_BACKEND:-auto}"    # auto | pacman | catalog
BAT_GUI_MODE="${BAT_GUI_MODE:-auto}"  # auto | always-terminal

# shellcheck source=/dev/null
[[ -f "$BAT_CONFIG" ]] && source "$BAT_CONFIG"

# Theme files: a user copy under ~/.config wins over the shipped default, so
# customising the look survives `git pull`. The shipped templates carry an
# @@BAT_ASSETS@@ placeholder instead of an absolute path (the install location
# is not known until install time); we materialise a resolved copy in the cache
# on demand, so the toolbox runs correctly straight from a git checkout with no
# install step. The copy is regenerated whenever the source template is newer.
bat_theme_file() {  # $1 = relative path under config/
    local rel="$1" user="$BAT_CONFIG_DIR/$1" shipped="$BAT_ROOT/config/$1" src
    if [[ -f "$user" ]]; then src="$user"; else src="$shipped"; fi
    [[ -f "$src" ]] || { printf '%s' "$src"; return; }

    if ! grep -q '@@BAT_ASSETS@@' "$src" 2>/dev/null; then
        printf '%s' "$src"; return          # already concrete, use as-is
    fi
    local rendered="$BAT_CACHE/theme_${rel//\//_}"
    if [[ ! -f "$rendered" || "$src" -nt "$rendered" ]]; then
        sed "s#@@BAT_ASSETS@@#${BAT_ASSETS}#g" "$src" > "$rendered" 2>/dev/null || {
            printf '%s' "$src"; return; }
    fi
    printf '%s' "$rendered"
}
