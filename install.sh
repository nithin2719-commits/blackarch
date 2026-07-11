#!/usr/bin/env bash
# BlackArch Toolbox installer (Linux / macOS / WSL).
#
# What it does, all reversible:
#   1. symlinks bin/blackarch-toolbox onto your PATH (~/.local/bin by default);
#   2. installs a .desktop entry so it shows up in app launchers;
#   3. wires the Alt+A keybinding into whatever desktop you run -- Hyprland,
#      sway, i3, GNOME, KDE -- writing to a clearly-marked block it can later
#      remove, never editing your config blind;
#   4. builds the first tool index.
#
# It never needs root: everything lands in your home. Re-running is safe (it
# updates in place). Uninstall with:  ./install.sh --uninstall
#
# Flags:
#   --prefix DIR     where to symlink the launcher (default ~/.local/bin)
#   --key COMBO      keybinding, WM syntax-agnostic (default: Alt A)
#   --no-keybind     skip the desktop keybinding step
#   --uninstall      undo everything this installer added

set -euo pipefail

REPO="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$REPO/lib/ui.sh" 2>/dev/null || { BLOOD=''; EMBER=''; ASH=''; BONE=''; STEEL=''; BOLD=''; RESET=''; }

PREFIX="$HOME/.local/bin"
MOD="ALT"; KEY="A"
DO_KEYBIND=1
DO_UNINSTALL=0
MARK="blackarch-toolbox"     # marker used to find our lines on uninstall

while (($#)); do
    case "$1" in
        --prefix)     PREFIX="$2"; shift 2 ;;
        --key)        MOD="${2%% *}"; KEY="${2##* }"; shift 2 ;;
        --no-keybind) DO_KEYBIND=0; shift ;;
        --uninstall)  DO_UNINSTALL=1; shift ;;
        -h|--help)
            grep '^#' "$0" | sed 's/^# \{0,1\}//' | sed -n '2,40p'; exit 0 ;;
        *) ui_warn "unknown flag: $1"; exit 2 ;;
    esac
done

LINK="$PREFIX/blackarch-toolbox"
DESKTOP="$HOME/.local/share/applications/blackarch-toolbox.desktop"

say()  { printf '  %s▊%s %s\n' "$BLOOD" "$RESET" "$1"; }
step() { printf '  %s›%s %s\n' "$EMBER" "$RESET" "$1"; }

banner() {
    printf '\n  %s%sBLACK%s%s%sARCH%s %sTOOLBOX%s\n\n' \
        "$BONE" "$BOLD" "$RESET" "$BLOOD" "$BOLD" "$RESET" "$STEEL" "$RESET"
}

# ---- keybinding writers, one per desktop ---------------------------------
# Each appends a single marked block (or removes it on uninstall). We only ever
# touch lines carrying our marker, so hand-written config is never disturbed.

kb_block_add() {  # $1 file  $2 line  ; idempotent
    local file="$1" line="$2"
    mkdir -p "$(dirname "$file")"; touch "$file"
    grep -qF "$MARK" "$file" && kb_block_del "$file"
    { printf '\n# >>> %s (added by installer; remove this block to unbind) >>>\n' "$MARK"
      printf '%s\n' "$line"
      printf '# <<< %s <<<\n' "$MARK"
    } >> "$file"
}
kb_block_del() {  # $1 file
    local file="$1"
    [[ -f "$file" ]] || return 0
    sed -i "/# >>> $MARK/,/# <<< $MARK/d" "$file"
}

detect_desktops() {
    DESKTOPS=()
    [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" || -d "$HOME/.config/hypr" ]] && DESKTOPS+=(hyprland)
    [[ -d "$HOME/.config/sway" ]] && DESKTOPS+=(sway)
    [[ -d "$HOME/.config/i3" ]]   && DESKTOPS+=(i3)
    command -v gsettings >/dev/null 2>&1 && [[ "${XDG_CURRENT_DESKTOP:-}" == *GNOME* ]] && DESKTOPS+=(gnome)
    [[ "${XDG_CURRENT_DESKTOP:-}" == *KDE* ]] && DESKTOPS+=(kde)
}

keybind_hyprland() {
    local f="$HOME/.config/hypr/keybindings.conf"
    [[ -f "$f" ]] || f="$HOME/.config/hypr/hyprland.conf"
    if ((DO_UNINSTALL)); then kb_block_del "$f"; step "Hyprland binding removed"; return; fi
    kb_block_add "$f" "bind = $MOD, $KEY, exec, $LINK"
    step "Hyprland: $MOD+$KEY -> toolbox  ($f)"
    command -v hyprctl >/dev/null 2>&1 && hyprctl reload >/dev/null 2>&1 || true
}

keybind_sway() {
    local f="$HOME/.config/sway/config"
    if ((DO_UNINSTALL)); then kb_block_del "$f"; step "sway binding removed"; return; fi
    kb_block_add "$f" "bindsym Mod1+${KEY,,} exec $LINK"
    step "sway: Mod1+${KEY,,} -> toolbox"
    command -v swaymsg >/dev/null 2>&1 && swaymsg reload >/dev/null 2>&1 || true
}

keybind_i3() {
    local f="$HOME/.config/i3/config"
    if ((DO_UNINSTALL)); then kb_block_del "$f"; step "i3 binding removed"; return; fi
    kb_block_add "$f" "bindsym Mod1+${KEY,,} exec $LINK"
    step "i3: Mod1+${KEY,,} -> toolbox"
    command -v i3-msg >/dev/null 2>&1 && i3-msg reload >/dev/null 2>&1 || true
}

keybind_gnome() {
    local base="org.gnome.settings-daemon.plugins.media-keys"
    local path="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/$MARK/"
    local key="$base.custom-keybinding:$path"
    if ((DO_UNINSTALL)); then
        gsettings reset "$key" name    2>/dev/null || true
        gsettings reset "$key" command 2>/dev/null || true
        gsettings reset "$key" binding 2>/dev/null || true
        step "GNOME binding removed"; return
    fi
    # Register the custom binding in the list, then set its three properties.
    local cur; cur="$(gsettings get "$base" custom-keybindings 2>/dev/null || echo "@as []")"
    [[ "$cur" == *"$path"* ]] || {
        if [[ "$cur" == "@as []" || "$cur" == "[]" ]]; then
            gsettings set "$base" custom-keybindings "['$path']"
        else
            gsettings set "$base" custom-keybindings "${cur%]}, '$path']"
        fi
    }
    gsettings set "$key" name    "BlackArch Toolbox"
    gsettings set "$key" command "$LINK"
    gsettings set "$key" binding "<Alt>${KEY,,}"
    step "GNOME: <Alt>${KEY,,} -> toolbox"
}

keybind_kde() {
    step "KDE detected — add the shortcut in System Settings ▸ Shortcuts ▸"
    step "  Custom Shortcuts ▸ New ▸ command: $LINK ▸ trigger: $MOD+$KEY"
    step "  (KDE stores shortcuts per-profile; a scripted edit would risk it.)"
}

apply_keybinds() {
    detect_desktops
    if ((${#DESKTOPS[@]} == 0)); then
        step "No supported desktop detected — see docs to bind $MOD+$KEY yourself."
        return
    fi
    local d
    for d in "${DESKTOPS[@]}"; do "keybind_$d"; done
}

# ==========================================================================
banner

if ((DO_UNINSTALL)); then
    say "Uninstalling BlackArch Toolbox"
    [[ -L "$LINK" ]] && { rm -f "$LINK"; step "removed launcher symlink"; }
    [[ -f "$DESKTOP" ]] && { rm -f "$DESKTOP"; step "removed .desktop entry"; }
    apply_keybinds
    step "cache/config left in place (rm -rf ~/.cache/blackarch-toolbox to purge)"
    say "Done."
    exit 0
fi

# 1. dependency sanity check --------------------------------------------------
say "Checking dependencies"
have() { command -v "$1" >/dev/null 2>&1; }
MISSING=()
have bash || MISSING+=(bash)
have awk  || MISSING+=(awk)
# a menu program
if ! have rofi && ! have fuzzel && ! have wofi && ! have dmenu && ! have fzf; then
    MISSING+=("a menu (rofi / fuzzel / wofi / dmenu / fzf)")
fi
if ((${#MISSING[@]})); then
    ui_warn "Missing: ${MISSING[*]}"
    step "Install them, then re-run. See README ▸ Requirements for per-distro names."
    ((${#MISSING[@]} == 1)) || exit 1
fi
step "core dependencies present"

# 2. symlink onto PATH --------------------------------------------------------
say "Linking launcher onto PATH"
mkdir -p "$PREFIX"
ln -sf "$REPO/bin/blackarch-toolbox" "$LINK"
step "$LINK -> $REPO/bin/blackarch-toolbox"
case ":$PATH:" in
    *":$PREFIX:"*) : ;;
    *) step "NOTE: $PREFIX is not on your PATH — add it in your shell rc." ;;
esac

# 3. desktop entry ------------------------------------------------------------
say "Installing application entry"
mkdir -p "$(dirname "$DESKTOP")"
cat > "$DESKTOP" <<EOF
[Desktop Entry]
Type=Application
Name=BlackArch Toolbox
Comment=Launch any BlackArch security tool from one menu
Exec=$LINK
Icon=distributor-logo-blackarch
Terminal=false
Categories=Security;System;Utility;
Keywords=security;pentest;blackarch;hacking;recon;
EOF
step "$DESKTOP"

# 4. keybinding ---------------------------------------------------------------
if ((DO_KEYBIND)); then
    say "Wiring the $MOD+$KEY keybinding"
    apply_keybinds
else
    step "keybinding skipped (--no-keybind)"
fi

# 5. first index --------------------------------------------------------------
say "Building the tool index (first run)"
if bash "$REPO/bin/blackarch-toolbox" --refresh; then :; else
    ui_warn "Index build reported an issue — you can re-run: blackarch-toolbox --refresh"
fi

printf '\n'
say "Installed. Press ${BOLD}$MOD+$KEY${RESET} or run ${BOLD}blackarch-toolbox${RESET}."
printf '\n'
