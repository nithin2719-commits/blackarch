# Changelog

All notable changes to BlackArch Toolbox are recorded here. This project
follows [Semantic Versioning](https://semver.org) and the
[Keep a Changelog](https://keepachangelog.com) format.

## [1.0.0] — 2026-07-31

The first public release. BlackArch Toolbox grew out of a single-machine
Hyprland launcher and became a portable tool that runs the same on any Linux
distribution, macOS, and Windows (through WSL).

### Added
- **Two-level launcher menu** — pick a section, then a tool; or search across
  every runnable tool at once. Sections are ordered like an engagement
  (recon → scan → exploit → escalate → specialist benches).
- **Only-runnable index** — every menu row is an executable that actually
  exists on the machine, so nothing opens to a dead "no such command" screen.
- **Reliable GUI launching** — a GUI tool is opened through its resolved desktop
  entry (matched even when it uses a reverse-DNS id such as
  `org.wireshark.Wireshark`) via `gio`, so windowed apps open dependably instead
  of silently failing on a raw-binary fallback.
- **Instant menus** — lists are streamed to the picker and the selection is
  recovered by row, so even the 4000-row "search all" opens with no lag.
- **Themed per-tool view** — a CLI tool opens into a red-on-black terminal that
  shows its description, one-line synopsis, a curated quick-start for common
  tools, and the cleaned `--help` flag list, then drops you into a shell scoped
  to that tool with per-tool history.
- **Pluggable package backends**
  - `pacman` reads BlackArch's own package groups for full ~4000-tool fidelity
    on Arch / BlackArch / Manjaro / EndeavourOS.
  - `catalog` resolves a curated, distro-neutral tool catalogue against `PATH`
    on Debian, Ubuntu, Kali, Parrot, Fedora, openSUSE, Alpine, macOS, and WSL —
    a tool appears however it was installed (apt, dnf, pipx, go, cargo, tarball).
- **Pluggable menu layer** — rofi, fuzzel, wofi, dmenu on a desktop; fzf as the
  terminal/SSH fallback.
- **Pluggable terminal layer** — kitty, alacritty, foot, wezterm, konsole,
  gnome-terminal, xterm, with an inline fallback for headless sessions.
- **Cross-platform installers**
  - `install.sh` (Linux/macOS/WSL): symlinks the launcher, adds a `.desktop`
    entry, and wires the **Alt+A** keybinding into Hyprland, sway, i3, or GNOME
    via a clearly-marked, fully-reversible config block. KDE gets guided steps.
  - `windows/install.ps1`: runs the toolbox through WSL, adds a Start-menu
    shortcut, and binds a global **Alt+A** hotkey via AutoHotkey.
- **Single CLI entry point** `blackarch-toolbox` with `--refresh`, `--run`,
  `--list`, `--config`, `--version`, and `--help`.
- **User configuration** via `~/.config/blackarch-toolbox/config` or environment
  variables (`BAT_MENU`, `BAT_TERMINAL`, `BAT_BACKEND`, `BAT_GUI_MODE`).
- **Documentation** — per-distro install guide and a guide for adding your own
  tools to the box.

### Notes
- Generated state (the index, help cache, per-tool history) lives under the XDG
  cache directory, never in the repo, so one system-wide install can serve
  several users, each with their own index and history.

[1.0.0]: https://github.com/nithin2719-commits/Blackarch_Toolbox/releases/tag/v1.0.0

## [1.1.0]

Search, favorites and recents — the launcher gets a front door.

### Added
- **Search all tools** is the first row of the menu: one `Enter` opens every
  indexed tool as a single organised list you filter by typing.
- **Favorites** — `Ctrl`+`S` stars the highlighted tool. Starred tools sit at
  the top of the menu and of the search list.
- **Recently used** — the last few launched tools appear under the favorites,
  automatically. No configuration, no counters.
- `tests/smoke.sh` and `tests/run-distros.sh`: the whole non-graphical surface,
  run in containers on Arch, Debian, Ubuntu, Fedora and Alpine.

### Fixed
- `sprintf("%-*s", ...)` broke indexing entirely under busybox awk, so Alpine
  could not build an index despite being a supported platform.
- `readlink -f` in the entry point is a GNU extension; on BSD/macOS the command
  would have failed on its first line.
- `grep -oP` (PCRE) is not in busybox or BSD grep.
- The BlackArch lockup changed size with the menu level, because the theme
  scales it to the prompt widget and rofi sizes that widget from its (invisible)
  prompt text.
- The tool view opened as a small tile instead of filling the workspace.
