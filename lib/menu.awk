# Build the single, search-first menu list in ONE pass.
#
# Output columns:  kind \t key \t pkg \t pango \t plain
#   kind = search -> Enter opens the full, organised tool list
#   kind = tool   -> key is the binary, Enter launches it
#   kind = sec    -> key is the section slug, Enter drills into that section
#
# Row order is the whole design:
#
#   🔍 search all   one entry into the organised list of every tool
#   ★ favorites     what this user reaches for on purpose
#   ↻ recents       what they reached for last
#     categories    the 27 sections, for when the name is not known
#
# The top view is deliberately SHORT -- roughly thirty rows, all of them a
# destination. The 4000-tool list is not poured into it; it lives one Enter away
# behind "Search all tools", where it can be searched on its own. Pass
# withtools=1 to append every remaining tool (that is what the search list
# itself is built from). Favorites and recents are always removed from the tool
# block, so no list ever shows the same tool twice.
#
# Inputs, in this order:  favorites  recent  sections.list  all.list
# (the first two may be empty or missing -- callers pass /dev/null instead)

BEGIN { FS = OFS = "\t" }

# ---- favorites: one binary per line, user-curated, order preserved --------
FILENAME == favfile {
    if ($0 != "" && !($0 in isfav)) { isfav[$0] = 1; favorder[++nfav] = $0 }
    next
}

# ---- recents: most-recent-first; a favorite is never repeated here --------
FILENAME == recfile {
    if ($0 != "" && !($0 in isfav) && !($0 in isrec) && nrec < reccap) {
        isrec[$0] = 1; recorder[++nrec] = $0
    }
    next
}

# ---- sections: icon, name, slug, count -----------------------------------
FILENAME == secfile {
    n = ++nsec
    sicon[n] = $1; sname[n] = $2; sslug[n] = $3; scount[n] = $4
    next
}

# ---- all.list: bin, pkg, pango, plain (pre-rendered by render.awk) -------
{
    bin = $1
    pkg[bin] = $2; pango[bin] = $3; plain[bin] = $4
    torder[++ntool] = bin
}

# A tool row, with a 2-character marker slot. EVERY tool row carries the slot --
# blank when unmarked -- so the name column lines up whether or not a row is
# starred, instead of favorites sitting two characters out from the rest.
function tool_row(bin, mark, mcolour,   p) {
    if (!(bin in pango)) return          # indexed once, uninstalled since
    p = (mark == "") ? "   " \
        : "<span foreground='" mcolour "'>" mark "</span>  "
    print "tool", bin, pkg[bin], p pango[bin], \
          ((mark == "") ? "  " : mark " ") plain[bin]
}

END {
    # The way in. First row, always, so the fastest possible sequence is
    # Alt+A, Enter, type -- and so the top view never has to carry 4000 rows.
    if (!withtools)
        print "search", "", "", \
            "<span foreground='" ember "'>󰍉</span>  <b>" \
              sprintf("%-" namew "s", "Search all tools") "</b>" \
              "<span size='small' foreground='" faint "'>" \
              sprintf("%5s", ntool) " tools  ›</span>", \
            sprintf("%s %-" namew "s %5s tools  >", "*", "Search all tools", ntool)

    for (i = 1; i <= nfav;  i++) tool_row(favorder[i], "★", ember)
    for (i = 1; i <= nrec;  i++) tool_row(recorder[i], "↻", faint)

    # Sections read as one column of names with their tool counts, and a chevron
    # to say "this opens something" rather than launching. They belong to the
    # top view only -- the search list is tools and nothing else.
    if (!withtools)
    for (i = 1; i <= nsec; i++) {
        name = sname[i]
        # Pad FIRST, then escape. Escaping only ever lengthens the string
        # ("Passwords & Crypto" -> "...&amp;..."), so padding an already-escaped
        # name pads to the wrong visible width and the counts of every section
        # with an "&" in it drift out of the column.
        pad = sprintf("%-" namew "s", name)
        gsub(/&/, "\\&amp;", pad)
        gsub(/</, "\\&lt;",  pad)
        gsub(/>/, "\\&gt;",  pad)
        print "sec", sslug[i], "", \
            "<span foreground='" blood "'>" sicon[i] "</span>  <b>" pad "</b>" \
              "<span size='small' foreground='" faint "'>" \
              sprintf("%5s", scount[i]) " tools  ›</span>", \
            sprintf("%s %-" namew "s %5s tools  >", sicon[i], name, scount[i])
    }

    # Only for the "search all" list itself -- never for the top view.
    if (withtools)
        for (i = 1; i <= ntool; i++) {
            bin = torder[i]
            if (!(bin in isfav) && !(bin in isrec)) tool_row(bin, "", "")
        }
}
