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
    # Short + precise: keep descriptions to ~36 chars so they fit the compact
    # menu without the window edge clipping them.
    d = desc
    if (length(d) > 38) d = substr(d, 1, 36) "…"

    pango = "<b>" esc(bin) "</b>"
    if (length(desc) > 0)
        pango = pango "   <span foreground='#9a7d7d'>" esc(d) "</span>"

    # Plain rows pad the name to a fixed column so the descriptions line up as
    # a second column -- markup-less menus have no other way to get alignment.
    plain = sprintf("%-*s", namew, bin)
    if (length(desc) > 0) plain = plain "  " d

    print bin, pkg, pango, plain
}
