# Pre-render a tool row into its final display strings.
#
# Input : bin \t pkg \t desc
# Output: bin \t pkg \t pango \t plain
#
# Two display columns, because the menu backends do not agree on markup: rofi
# renders pango, while wofi/fuzzel/dmenu/fzf want plain text. Rendering both
# once at index time means the launcher never forks per tool -- opening a
# 900-tool section is instant either way.

function esc(s) {
    gsub(/&/, "\\&amp;",  s)   # & first, then the angle brackets
    gsub(/</, "\\&lt;",   s)
    gsub(/>/, "\\&gt;",   s)
    return s
}

BEGIN { FS = OFS = "\t"; if (namew == "") namew = 24 }
{
    bin = $1; pkg = $2; desc = $3
    # Short + precise: keep descriptions to ~30 chars so a padded name plus its
    # description still fits the compact menu without being clipped.
    d = desc
    if (length(d) > 32) d = substr(d, 1, 30) "…"

    # Both columns pad the name to a fixed width, so every description starts
    # at the same x and the list reads as two columns rather than a ragged
    # dump. The menu font is monospace, so the padding lines up exactly.
    name = sprintf("%-*s", namew, bin)

    pango = "<b>" esc(name) "</b>"
    if (length(desc) > 0)
        pango = pango "  <span foreground='#9a7d7d'>" esc(d) "</span>"

    plain = name
    if (length(desc) > 0) plain = plain "  " d

    print bin, pkg, pango, plain
}
