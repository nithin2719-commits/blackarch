# Build one menu list, in a single pass, for whichever view was asked for.
#
# Output columns:  kind \t key \t pkg \t pango \t plain
#   kind = tool    -> key is the binary, Enter launches it
#   kind = sec     -> key is a section slug, Enter opens that section
#   kind = search  -> Enter opens the full tool list
#   kind = favs    -> Enter opens the starred tools
#   kind = recent  -> Enter opens the recently used tools
#
# mode=top   the main box. Every row is a DESTINATION, never a tool dump:
#
#              🔍 Search all tools     every indexed tool, one Enter away
#              ★  Favorites            only when something is starred
#              ↻  Recent               only when something has been used
#                 27 categories
#
#            Favorites and Recent are folders of their own, exactly like the
#            categories, so the box stays the same short shape however many
#            tools get starred. They are omitted entirely when empty -- a row
#            that opens nothing is a row that should not be there.
#
# mode=all   every tool, left in index (alphabetical) order, starred ones
#            marked. Deliberately NOT reordered: this is the organised list you
#            search, and a stable order is what makes it searchable.
# mode=favs  the starred tools, in the order the user starred them.
# mode=recent the recently used, most recent first.
#
# Inputs, in this order:  favorites  recent  sections.list  all.list
# The first two may be empty; they must exist (awk aborts on a missing file).

BEGIN { FS = OFS = "\t"; if (mode == "") mode = "top" }

FILENAME == favfile {
    if ($0 != "" && !($0 in isfav)) { isfav[$0] = 1; favorder[++nfav] = $0 }
    next
}

FILENAME == recfile {
    if ($0 != "" && !($0 in isrec) && nrec < reccap) {
        isrec[$0] = 1; recorder[++nrec] = $0
    }
    next
}

FILENAME == secfile {
    n = ++nsec
    sicon[n] = $1; sname[n] = $2; sslug[n] = $3; scount[n] = $4
    next
}

# all.list: bin, pkg, pango, plain (pre-rendered by render.awk)
{
    bin = $1
    pkg[bin] = $2; pango[bin] = $3; plain[bin] = $4
    torder[++ntool] = bin
}

# A tool row, with a 2-character marker slot. EVERY tool row carries the slot --
# blank when unmarked -- so the name column lines up whether or not a row is
# starred, instead of starred rows sitting two characters out from the rest.
function tool_row(bin, mark, mcolour,   p) {
    if (!(bin in pango)) return          # indexed once, uninstalled since
    p = (mark == "") ? "   " \
        : "<span foreground='" mcolour "'>" mark "</span>  "
    print "tool", bin, pkg[bin], p pango[bin], \
          ((mark == "") ? "  " : mark " ") plain[bin]
}

# A row that opens another list: an icon, a padded name, and a count with a
# chevron to say "this goes somewhere" rather than "this launches".
function folder_row(kind, key, icon, icolour, name, count,   pad) {
    pad = sprintf("%-" namew "s", name)
    gsub(/&/, "\\&amp;", pad)            # pad first, then escape: escaping only
    gsub(/</, "\\&lt;",  pad)            # lengthens, so escaping first would pad
    gsub(/>/, "\\&gt;",  pad)            # to the wrong visible width
    print kind, key, "", \
        "<span foreground='" icolour "'>" icon "</span>  <b>" pad "</b>" \
          "<span size='small' foreground='" faint "'>" \
          sprintf("%5s", count) " tools  ›</span>", \
        sprintf("%s %-" namew "s %5s tools  >", icon, name, count)
}

# Starred/recent entries for tools that are no longer installed must not be
# counted, or a folder advertises rows it cannot show.
function live_count(order, n,   i, c) {
    for (i = 1; i <= n; i++) if (order[i] in pango) c++
    return c + 0
}

END {
    if (mode == "top") {
        folder_row("search", "", "󰍉", ember, "Search all tools", ntool)
        nf = live_count(favorder, nfav)
        nr = live_count(recorder, nrec)
        if (nf) folder_row("favs",   "", "★", ember, "Favorites", nf)
        if (nr) folder_row("recent", "", "↻", faint, "Recent",    nr)
        for (i = 1; i <= nsec; i++)
            folder_row("sec", sslug[i], sicon[i], blood, sname[i], scount[i])
    }
    else if (mode == "favs") {
        for (i = 1; i <= nfav; i++) tool_row(favorder[i], "★", ember)
    }
    else if (mode == "recent") {
        for (i = 1; i <= nrec; i++) tool_row(recorder[i], "↻", faint)
    }
    else {   # all
        for (i = 1; i <= ntool; i++) {
            bin = torder[i]
            if (bin in isfav) tool_row(bin, "★", ember); else tool_row(bin, "", "")
        }
    }
}
