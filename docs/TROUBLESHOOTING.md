# Troubleshooting

Quick fixes for the things people hit most. If none of these help, run
`blackarch-toolbox --config` and open an issue with that output.

---

### A GUI tool doesn't open when I pick it

The toolbox opens GUI apps through their **desktop entry**, resolving it even
when the app uses an unusual id (for example Wireshark ships
`org.wireshark.Wireshark.desktop`, not `wireshark.desktop`). If a GUI tool still
doesn't appear:

- Make sure it's actually installed and on your `PATH`:
  `command -v <tool>`.
- Try launching it the same way the toolbox does:
  `gio launch /usr/share/applications/<its-entry>.desktop`.
- If the app has no desktop entry at all, the toolbox runs the binary directly —
  check it starts from a terminal: `<tool>`.
- Force it to open in the terminal tool-view instead:
  `BAT_GUI_MODE=always-terminal blackarch-toolbox`.

### The menu feels slow to open

- The **first** launch builds the index once — that's expected. Later launches
  read the cache and open instantly.
- Rebuild the index if it looks stale or partial:
  `blackarch-toolbox --refresh`.
- Huge lists (the 4000-row *Search all*) are streamed to the picker, so they
  should appear at once. If they don't, your menu program itself may be slow —
  try a lighter one: `BAT_MENU=fzf blackarch-toolbox`.

### No tools show up / "No usable backend"

- **On Arch/BlackArch**: confirm BlackArch groups are visible —
  `pacman -Qgq blackarch | head`. If empty, the BlackArch repo isn't set up; see
  [INSTALL ▸ Arch](INSTALL.md#arch--blackarch--manjaro--endeavouros).
- **Everywhere else**: the catalogue backend only shows tools that are on your
  `PATH`. Install some (`apt`/`dnf`/`brew`/`pipx`…) and run `--refresh`.
- Check which backend was chosen: `blackarch-toolbox --config`.

### It picked the wrong menu or terminal

Force your choice in `~/.config/blackarch-toolbox/config` or per run:

```bash
BAT_MENU=rofi BAT_TERMINAL=kitty blackarch-toolbox
```

Valid menus: `rofi`, `fuzzel`, `wofi`, `dmenu`, `fzf`.
Valid terminals: `kitty`, `alacritty`, `foot`, `wezterm`, `konsole`,
`gnome-terminal`, `xterm`.

### `Alt`+`A` does nothing

- Re-run the installer to (re)write the binding: `./install.sh`.
- Confirm the launcher is on your `PATH`: `command -v blackarch-toolbox`.
- On Wayland/Hyprland, reload the config after install:
  `hyprctl reload` (sway: `swaymsg reload`, i3: `i3-msg reload`).
- Rebind to a different key if `Alt`+`A` clashes: `./install.sh --key "SUPER B"`.

### A tool opens but says "no readable help"

Some tools print no `--help` and have no man page. The tool-view still drops you
into a shell scoped to that tool — just run it and read its own prompt, or
`man <tool>`.

### The icons look like boxes in the menu

The menu uses Nerd Font glyphs for the section icons. Install a Nerd Font (e.g.
*JetBrainsMono Nerd Font*) or ignore it — the layout still lines up without them.

---

### Resetting everything

```bash
blackarch-toolbox --refresh              # rebuild just the index
rm -rf ~/.cache/blackarch-toolbox        # wipe all generated state
./install.sh --uninstall && ./install.sh # reinstall from scratch
```
