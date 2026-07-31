#!/usr/bin/env bash
# Rebuild the toolbox index.
#
# Chooses a package backend (pacman on Arch/BlackArch, the bundled catalogue
# everywhere else), asks it for  <token> \t <package> \t <binary> \t <desc>
# rows, buckets those into sections, and pre-renders every menu row so the
# launcher does zero per-tool work at click time. That pre-rendering is what
# makes opening even a 900-tool section instant instead of forking sed per row.
#
# Everything written here lives under $BAT_CACHE (XDG cache), never in the repo.

set -uo pipefail

HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/paths.sh"
# shellcheck source=/dev/null
source "$HERE/ui.sh"

SECTIONS="$BAT_DATA/sections.conf"

# ---- pick a backend ------------------------------------------------------
for b in "$BAT_LIB"/backends/*.sh; do
    # shellcheck source=/dev/null
    source "$b"
done

pick_backend() {
    if [[ "$BAT_BACKEND" != auto ]]; then
        declare -F "backend_${BAT_BACKEND}_available" >/dev/null \
            && "backend_${BAT_BACKEND}_available" \
            && { echo "$BAT_BACKEND"; return; }
        ui_warn "backend '$BAT_BACKEND' unavailable, auto-detecting"
    fi
    # Prefer pacman (highest fidelity), then the universal catalogue.
    local cand
    for cand in pacman catalog; do
        "backend_${cand}_available" 2>/dev/null && { echo "$cand"; return; }
    done
    return 1
}

BACKEND="$(pick_backend)" || ui_die "No usable backend (need BlackArch pacman groups, or data/catalog.tsv)."
echo "Indexing via backend: $("backend_${BACKEND}_label")"

# Every token referenced by the section list, comma-joined, so a backend can
# resolve them all in one pass.
ALL_TOKENS="$(awk -F'|' '/^[[:space:]]*#/||NF<3{next}{print $3}' "$SECTIONS" | paste -sd, -)"

# ---- collect all rows from the backend, once -----------------------------
RAW="$BAT_CACHE/.index.raw"
"backend_${BACKEND}_index" "$ALL_TOKENS" > "$RAW" || ui_die "Backend produced no tools."

# Union with the catalogue. On Arch this is the fix for well-known tools that
# ship OUTSIDE BlackArch's package groups -- wireshark-qt, zaproxy, ghidra,
# rz-cutter, bettercap and friends are installed but in no blackarch-* group, so
# the pacman pass alone never sees them and they were missing from the menu. The
# catalogue resolves them from PATH and slots them into the right section; the
# per-section de-dupe below drops anything the primary backend already listed.
if [[ "$BACKEND" != catalog ]] && backend_catalog_available; then
    added_before="$(wc -l < "$RAW")"
    backend_catalog_index "$ALL_TOKENS" >> "$RAW" 2>/dev/null || true
    echo "  + $(( $(wc -l < "$RAW") - added_before )) catalogue entries merged (tools outside BlackArch groups)"
fi

total_rows="$(wc -l < "$RAW")"
((total_rows)) || ui_die "No runnable tools found for this system."
echo "  $total_rows runnable tool entries"

# ---- bucket into sections + pre-render -----------------------------------
: > "$BAT_CACHE/sections.list"
rm -f "$BAT_CACHE"/section_*.list "$BAT_CACHE"/all.list

total_tools=0
while IFS='|' read -r icon name tokens; do
    [[ -z "${name// }" || "$icon" == \#* ]] && continue

    slug="$(printf '%s' "$name" | tr '[:upper:] ' '[:lower:]_' | tr -cd 'a-z0-9_')"
    out="$BAT_CACHE/section_${slug}.list"

    # Keep rows whose token is one of this section's tokens (comma-list match),
    # de-dupe, then pre-render both display columns in one awk pass.
    awk -F'\t' -v want=",$tokens," '
        index(want, "," $1 ",") { print $2 "\t" $3 "\t" $4 }
    ' "$RAW" | sort -u -t$'\t' -k2,2 \
        | awk -F'\t' -v OFS='\t' '{print $2, $1, $3}' \
        | awk -F'\t' -f "$HERE/render.awk" > "$out"
    # render.awk input is  bin \t pkg \t desc  -> we reordered above.

    n="$(wc -l < "$out")"
    if ((n == 0)); then rm -f "$out"; continue; fi
    total_tools=$((total_tools + n))
    printf '%s\t%s\t%s\t%d\n' "$icon" "$name" "$slug" "$n" >> "$BAT_CACHE/sections.list"
    printf '  %-22s %5d tools\n' "$name" "$n"
done < "$SECTIONS"

# Flat index for the "search everything" entry. De-dupe by BINARY (field 1) so a
# tool that legitimately lives in two sections is listed once here.
cat "$BAT_CACHE"/section_*.list 2>/dev/null | sort -t$'\t' -k1,1 -u > "$BAT_CACHE/all.list"

printf '%s\n' "$(date +%s)" > "$BAT_CACHE/built_at"
printf '%s\n' "$BACKEND"    > "$BAT_CACHE/backend"
rm -f "$RAW"

echo
echo "Indexed $(wc -l < "$BAT_CACHE/all.list") unique runnable tools across $(wc -l < "$BAT_CACHE/sections.list") sections."
