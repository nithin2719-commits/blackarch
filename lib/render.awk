# Pre-render a tool row into its final display strings.
#
# Input : bin \t pkg \t desc
# Output: bin \t pkg \t pango \t plain
#
# Two display columns, because the menu backends do not agree on markup: rofi
# renders pango, while wofi/fuzzel/dmenu/fzf want plain text. Rendering both
# once at index time means the launcher never forks per tool -- opening a
# 900-tool section is instant either way.

# Split every character with a zero-width non-joiner, so no typed string can
# ever match this text while it still renders exactly as written.
# gawk in a UTF-8 locale walks characters; mawk and busybox awk walk BYTES. So
# the separator is only ever inserted before a printable ASCII character. Any
# byte of a multi-byte sequence -- such as the "…" this file appends -- is left
# untouched, so it can never be split down the middle into mojibake. A plain
# [ -~] range is used rather than a \200-\277 byte range because busybox awk
# rejects the latter outright ("bad regex: Invalid regexp").
function zwnj(v,   i, c, out) {
    for (i = 1; i <= length(v); i++) {
        c = substr(v, i, 1)
        if (i > 1 && c ~ /^[ -~]$/) out = out "\342\200\214"
        out = out c
    }
    return out
}

function esc(s) {
    gsub(/&/, "\\&amp;",  s)   # & first, then the angle brackets
    gsub(/</, "\\&lt;",   s)
    gsub(/>/, "\\&gt;",   s)
    return s
}

BEGIN {
    FS = OFS = "\t"
    if (namew == "") namew = 24
    # Build the pad format instead of using sprintf("%-*s", namew, s): busybox
    # awk rejects star-widths outright ("%*x formats are not supported"), which
    # broke indexing on Alpine and anywhere else the only awk is busybox.
    padfmt = "%-" namew "s"
}
{
    bin = $1; pkg = $2; desc = $3
    # Short + precise: keep descriptions to ~30 chars so a padded name plus its
    # description still fits the compact menu without being clipped.
    d = desc
    if (length(d) > 32) d = substr(d, 1, 30) "…"

    # Both columns pad the name to a fixed width, so every description starts
    # at the same x and the list reads as two columns rather than a ragged
    # dump. The menu font is monospace, so the padding lines up exactly.
    name = sprintf(padfmt, bin)

    # The description is SHOWN but must never be SEARCHED. rofi matches the
    # whole row it is handed and has no option to match a subset of it, so
    # typing "nmap" used to return brutespray ("Brute-Forcing from Nmap
    # output"), halcyon-ide and umit -- tools whose names have nothing to do
    # with the query.
    #
    # Interleaving the description with U+200C ZERO WIDTH NON-JOINER fixes it
    # without hiding anything: the character renders as nothing, so the text
    # looks identical, but "nmap" no longer occurs as a substring of
    # "N<zwnj>m<zwnj>a<zwnj>p". The name is left intact, so it still matches
    # normally. Tried and rejected first: -display-columns (hides a column from
    # display, still matches it) and -matching prefix (matches word prefixes
    # anywhere in the row, so descriptions still match).
    dz = zwnj(d)

    pango = "<b>" esc(name) "</b>"
    if (length(desc) > 0)
        pango = pango "  <span foreground='#9a7d7d'>" esc(dz) "</span>"

    plain = name
    if (length(desc) > 0) plain = plain "  " dz

    print bin, pkg, pango, plain
}
