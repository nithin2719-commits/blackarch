# Adding tools to the box

The toolbox only ever shows tools that are **installed and runnable** on your
machine — so "adding a tool" is two independent things:

1. **Install the tool** (with your package manager, pipx, go, cargo, a tarball…).
2. **Make sure the toolbox knows about it** so it appears in a section.

How step 2 works depends on which backend you are on. Check with:

```bash
blackarch-toolbox --config      # look at the "indexed … via <backend>" line
```

---

## On Arch / BlackArch (the `pacman` backend)

Nothing to do by hand. The toolbox reads BlackArch's package groups directly, so
any BlackArch tool you install is automatically in the right section:

```bash
sudo pacman -S blackarch-webapp        # a whole category
sudo pacman -S sqlmap                  # a single tool
blackarch-toolbox --refresh            # re-index
```

Your new tools show up under the section that matches their BlackArch group.

---

## On every other OS (the `catalog` backend)

Off Arch there are no BlackArch package groups, so the toolbox uses a curated
catalogue — [`data/catalog.tsv`](../data/catalog.tsv) — of well-known tools and
their categories. A catalogue entry appears in the menu **only if its binary is
found on your `PATH`**, so it never shows a tool you don't have.

### If the tool is already in the catalogue

Just install it and refresh:

```bash
pipx install semgrep        # or apt/dnf/brew/go/cargo…
blackarch-toolbox --refresh
```

### If the tool is *not* in the catalogue yet

Add one line to `data/catalog.tsv`. The format is three **tab-separated**
fields:

```
<binary>	<category>	<one-line description>
```

- **binary** — exactly what you type to run it (what `command -v` finds).
- **category** — one of the section tokens (see the list below).
- **description** — a short sentence shown next to the name in the menu.

Example — adding [`dnsx`](https://github.com/projectdiscovery/dnsx) to Recon:

```
dnsx	recon	Fast and multi-purpose DNS toolkit
```

> ⚠️ The separators **must be real tabs**, not spaces. In most editors, paste a
> tab or copy an existing line and edit it. To verify:
> `grep -P '^\tdnsx' data/catalog.tsv` should print nothing, while
> `grep -P 'dnsx\trecon' data/catalog.tsv` should print your line.

Then refresh:

```bash
blackarch-toolbox --refresh
```

### Category tokens

Use one of these in the second column (they map to the menu sections):

```
recon        fingerprint  scanner      webapp       fuzzer
exploitation cracker      crypto       windows      backdoor
malware      sniffer      proxy        wireless     bluetooth
nfc          radio        reversing    disassembler decompiler
debugger     binary       packer       forensic     anti-forensic
defensive    ids          social       mobile       networking
database     code-audit   automation   honeypot     dos
hardware     firmware     misc
```

The section each token belongs to is defined in
[`data/sections.conf`](../data/sections.conf).

---

## Keeping a tool that lives outside PATH

If a tool is a script you keep in, say, `~/tools/foo/foo.py`, symlink it onto
your `PATH` so the toolbox (and your shell) can find it:

```bash
ln -s ~/tools/foo/foo.py ~/.local/bin/foo
blackarch-toolbox --refresh
```

Now add `foo	<category>	<description>` to the catalogue as above.

---

## Adding a whole new section

Edit [`data/sections.conf`](../data/sections.conf) and add a line:

```
<icon>|<Display Name>|<token>[,<token>…]
```

- **icon** — a Nerd Font glyph (optional; leave the field empty for none).
- **Display Name** — what the menu shows.
- **tokens** — the catalogue categories (or, on Arch, BlackArch group suffixes)
  that feed this section.

Refresh, and the new section appears wherever you placed it in the file (order in
the file = order in the menu).

---

## Sharing your additions

Catalogue additions are just text — open a pull request against
`data/catalog.tsv` and everyone benefits. Please keep the file sorted by
category and keep descriptions to one short sentence.
