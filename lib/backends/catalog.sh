#!/usr/bin/env bash
# Package backend: bundled catalogue + PATH scan (every other platform).
#
# Debian, Ubuntu, Kali, Parrot, Fedora, openSUSE, Alpine, macOS and WSL have no
# equivalent of BlackArch's package groups -- their security tools arrive from a
# dozen different sources (apt, dnf, pipx, go install, cargo, a tarball dropped
# in ~/.local/bin) and carry no category metadata at all. Classifying by
# *package* is therefore impossible off Arch.
#
# So this backend inverts the question: instead of asking the package manager
# what is installed and where it belongs, it takes the curated catalogue in
# data/catalog.tsv -- binary, category, description -- and keeps the entries
# whose binary is actually resolvable on PATH. The result is the same contract
# as the pacman backend, works identically no matter how a tool was installed,
# and never shows a menu row that cannot run.
#
# Package names are enriched from the native package manager in ONE batched
# call where that is cheap; a tool installed outside the package manager simply
# shows no package, which is accurate rather than wrong.
#
# Emits, on stdout:  <token> \t <package> \t <binary> \t <description>

backend_catalog_available() { [[ -r "$BAT_DATA/catalog.tsv" ]]; }

backend_catalog_label() {
    local mgr
    for mgr in apt-get dnf zypper apk brew pacman; do
        command -v "$mgr" >/dev/null 2>&1 && { printf 'catalogue + %s' "$mgr"; return; }
    done
    printf 'catalogue (PATH scan)'
}

# Batch-resolve "which package owns this file" for the whole set at once.
# Populates the caller's OWNER associative array: OWNER[/abs/path]=package.
#
# Package name is a nicety, not load-bearing: a tool with no resolvable owner
# (installed via pipx/go/cargo/tarball, or on a box whose package DB is empty)
# simply shows no package. So each helper is attempted in turn and we stop at
# the first that actually resolves something -- a manager that is installed but
# has a broken or empty database yields nothing and we fall through, rather than
# trusting it. stderr is always discarded so a DB error can never leak into a
# package field.
_catalog_owners() {  # $@ = absolute paths
    (($#)) || return 0
    _owners_dpkg "$@"  && ((${#OWNER[@]})) && return 0
    _owners_pacman "$@" && ((${#OWNER[@]})) && return 0
    _owners_rpm "$@"   && ((${#OWNER[@]})) && return 0
    return 0
}

_owners_dpkg() {
    command -v dpkg-query >/dev/null 2>&1 || return 1
    local line path pkg
    # dpkg -S prints "package: /path" (or "pkg1, pkg2: /path" for diversions).
    while IFS= read -r line; do
        [[ "$line" == *": /"* ]] || continue
        pkg="${line%%:*}"; path="${line##*: }"
        OWNER["$path"]="${pkg%%,*}"               # first owner is enough
    done < <(dpkg-query -S "$@" 2>/dev/null)
}

_owners_pacman() {
    command -v pacman >/dev/null 2>&1 || return 1
    local line path pkg
    while IFS= read -r line; do
        [[ "$line" == *" is owned by "* ]] || continue
        path="${line%% is owned by *}"
        pkg="${line##* is owned by }"
        OWNER["$path"]="${pkg%% *}"
    done < <(pacman -Qo "$@" 2>/dev/null)
}

_owners_rpm() {
    command -v rpm >/dev/null 2>&1 || return 1
    # rpm -qf answers in input order, one line per path, so index by position.
    # stdout only -- "not owned" / DB errors go to stderr and are dropped.
    local -a paths=("$@") out
    mapfile -t out < <(rpm -qf --queryformat '%{NAME}\n' "$@" 2>/dev/null)
    local i
    for i in "${!paths[@]}"; do
        [[ -n "${out[$i]:-}" ]] && OWNER["${paths[$i]}"]="${out[$i]}"
    done
}

backend_catalog_index() {  # $1 = comma-separated list of every token in use
    local wanted=",$1,"
    local -A OWNER=()
    local -a bins=() tokens=() descs=() paths=()
    local bin token desc path

    while IFS=$'\t' read -r bin token desc; do
        [[ -z "$bin" || "$bin" == \#* ]] && continue
        # Only keep categories this section list actually renders, so an
        # unused catalogue row can never produce an orphaned menu entry.
        [[ "$wanted" == *",$token,"* ]] || continue
        path="$(command -v "$bin" 2>/dev/null)" || continue
        [[ -x "$path" ]] || continue
        bins+=("$bin"); tokens+=("$token"); descs+=("$desc"); paths+=("$path")
    done < "$BAT_DATA/catalog.tsv"

    ((${#bins[@]})) || return 1
    _catalog_owners "${paths[@]}"

    local i
    for i in "${!bins[@]}"; do
        printf '%s\t%s\t%s\t%s\n' \
            "${tokens[$i]}" "${OWNER[${paths[$i]}]:-}" "${bins[$i]}" "${descs[$i]}"
    done
}
