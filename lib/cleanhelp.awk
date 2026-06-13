# Clean a tool's --help text for the USAGE & FLAGS panel.
#
# Tools often print their OWN banner + a metadata block (name, author, contact,
# version, homepage) before the real usage. We already show a clean name banner
# and a one-line description above, so that preamble is pure noise -- and it is
# tall enough to push the header off-screen. So: drop everything before the
# first real "options/usage/synopsis" anchor, then strip any art/warning lines.

function is_art(s,   i, ch, letters, arts, len) {
    len = length(s)
    if (len < 8) return 0
    letters = 0; arts = 0
    for (i = 1; i <= len; i++) {
        ch = substr(s, i, 1)
        if (ch ~ /[A-Za-z]/)                                    letters++
        else if (ch == " " || ch ~ /[\/\\|_=+*<>()\[\]~.,`'-]/) arts++
    }
    # Mostly symbols, almost no letters -> it's a drawn banner, not text.
    return (letters <= len * 0.25 && arts >= len * 0.55)
}

{ raw[NR] = $0 }

END {
    # Prefer to start at the flag list ("options:"); else the usage/synopsis;
    # else keep everything (some tools have no headers, just a flag list).
    ostart = 0; ustart = 0
    for (i = 1; i <= NR; i++) {
        if (!ostart && raw[i] ~ /^[[:space:]]*([Oo]ptions|OPTIONS|[Aa]rguments|ARGUMENTS)[:]?[[:space:]]*$/) ostart = i
        if (!ustart && raw[i] ~ /^[[:space:]]*([Uu]sage|USAGE|SYNOPSIS)[: ]/)                                ustart = i
    }
    start = (ostart ? ostart : (ustart ? ustart : 1))

    for (i = start; i <= NR; i++) {
        s = raw[i]
        if (s ~ /^[[:space:]]*(WARNING|INFO|DEBUG|Traceback|\[[!*+-]\])[: ]/) continue
        if (is_art(s)) continue
        print s
    }
}
