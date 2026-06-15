#!/usr/bin/env bash
# Package backend: pacman (Arch Linux / BlackArch / Manjaro / EndeavourOS).
#
# This is the high-fidelity path. BlackArch ships its own pacman groups
# (blackarch-recon, blackarch-webapp, ...) whose membership is maintained
# upstream, so sectioning stays correct as packages come and go instead of
# drifting from a hand-kept list. On a full BlackArch install this indexes
# 4000+ genuinely runnable tools.
#
# Emits, on stdout:  <token> \t <package> \t <binary> \t <description>

backend_pacman_available() {
    command -v pacman >/dev/null 2>&1 && pacman -Qgq blackarch >/dev/null 2>&1
}

backend_pacman_label() { printf 'pacman (BlackArch groups)'; }

backend_pacman_index() {  # $1 = comma-separated list of every token in use
    local tokens="$1"

    # One pass over every installed BlackArch package rather than one call per
    # package: 2800+ forks is minutes of wall time, this is a couple of seconds.
    local -a all_pkgs
    mapfile -t all_pkgs < <(pacman -Qgq blackarch 2>/dev/null | sort -u)
    ((${#all_pkgs[@]})) || return 1

    # package -> space-separated binaries. The old launcher listed package
    # names, but many packages ship no executable at all (nuclei-templates is
    # data, laudanum is a payload tree, python-capstone is a library), so
    # picking them opened a terminal that could only say "no help found".
    # Indexing /usr/bin entries means every row in the menu is something that
    # actually runs.
    local -A PKG_BINS=()
    local pkg path bin
    while read -r pkg path; do
        pkg="${pkg%:}"
        case "$path" in
            */) continue ;;                       # directories
            /usr/bin/*|/usr/local/bin/*)
                [[ -x "$path" ]] || continue
                bin="${path##*/}"
                PKG_BINS[$pkg]+="$bin "
                ;;
        esac
    done < <(pacman -Ql "${all_pkgs[@]}" 2>/dev/null)

    # package -> one-line description, from a single -Qi pass. This is what
    # lets the menu say what each tool does without opening it.
    local -A PKG_DESC=()
    local cur="" line
    while IFS= read -r line; do
        case "$line" in
            "Name            : "*) cur="${line#*: }" ;;
            "Description     : "*) [[ -n "$cur" ]] && PKG_DESC[$cur]="${line#*: }" ;;
        esac
    done < <(LC_ALL=C pacman -Qi "${all_pkgs[@]}" 2>/dev/null)

    local token
    local IFS=','
    for token in $tokens; do
        unset IFS
        while read -r pkg; do
            [[ -n "${PKG_BINS[$pkg]:-}" ]] || continue
            for bin in ${PKG_BINS[$pkg]}; do
                printf '%s\t%s\t%s\t%s\n' \
                    "$token" "$pkg" "$bin" "${PKG_DESC[$pkg]:-}"
            done
        done < <(pacman -Qgq "blackarch-$token" 2>/dev/null | sort -u)
        IFS=','
    done
}
