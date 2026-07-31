# Contributing

Thanks for helping make BlackArch Toolbox better. Most contributions are small
and welcome — a new tool in the catalogue, a fix, a doc tweak.

## Adding tools to the catalogue

The most common contribution. `data/catalog.tsv` is a tab-separated list of
`binary`, `category`, `description`. To add one:

```
dnsx	recon	Fast and multi-purpose DNS toolkit
```

- Use a **real tab** between fields, not spaces.
- Pick a `category` that exists in [`data/sections.conf`](data/sections.conf).
- Keep the description to one short sentence.
- Keep the file grouped by category and roughly alphabetical within it.

See [docs/ADDING-TOOLS.md](docs/ADDING-TOOLS.md) for the full picture.

## Code

- Everything is POSIX-friendly **Bash** + **awk**; keep it dependency-light.
- Run `bash -n` on any script you touch, and test with a throwaway cache:
  `BAT_CACHE=/tmp/bat-test blackarch-toolbox --refresh`.
- Match the existing style: clear names, comments that explain *why*, no clever
  one-liners that need decoding.
- New OS support = a new file in `lib/backends/` implementing
  `backend_<name>_available`, `_label`, and `_index`. The UI never needs to
  change.

## Pull requests

- One focused change per PR.
- Describe what you changed and how you tested it.
- For catalogue additions, mention the distro/source you installed the tool from.

## Reporting bugs

Open an issue with the output of `blackarch-toolbox --config`, your distro, and
your menu/terminal programs. Screenshots of a broken menu help.
