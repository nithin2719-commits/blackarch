# Installation guide

BlackArch Toolbox runs on **every Linux distribution**, **macOS**, and
**Windows** (through WSL). The launcher itself is plain Bash + awk, so the only
things you install per-distro are:

1. a **menu program** — `rofi` (recommended on a desktop) or `fzf` (works
   anywhere, including over SSH); and
2. optionally a **terminal** kitty for the richest per-tool view.

The BlackArch *tools* themselves are installed however your distro provides
them — see [Getting the tools](#getting-the-tools) at the bottom.

---

## Contents

- [Quick install (any distro)](#quick-install-any-distro)
- [Arch / BlackArch / Manjaro / EndeavourOS](#arch--blackarch--manjaro--endeavouros)
- [Debian / Ubuntu / Kali / Parrot](#debian--ubuntu--kali--parrot)
- [Fedora / RHEL / Rocky / Alma](#fedora--rhel--rocky--alma)
- [openSUSE](#opensuse)
- [Alpine](#alpine)
- [macOS](#macos)
- [Windows (WSL)](#windows-wsl)
- [Getting the tools](#getting-the-tools)
- [Uninstalling](#uninstalling)

---

## Quick install (any distro)

```bash
git clone https://github.com/nithin2719-commits/Blackarch_Toolbox.git
cd Blackarch_Toolbox
./install.sh
```

`install.sh` needs **no root**. It symlinks the launcher into `~/.local/bin`,
adds an application entry, wires **Alt+A** into your desktop, and builds the
first tool index. Then press **Alt+A** or run `blackarch-toolbox`.

Options:

| Flag | Effect |
|------|--------|
| `--prefix DIR` | where to symlink the launcher (default `~/.local/bin`) |
| `--key "ALT A"` | change the keybinding (e.g. `--key "SUPER B"`) |
| `--no-keybind` | skip the desktop keybinding step |
| `--uninstall` | undo everything the installer added |

---

## Arch / BlackArch / Manjaro / EndeavourOS

This is the highest-fidelity path: the toolbox reads BlackArch's own pacman
groups and indexes **~4000 tools**.

```bash
# menu + terminal (rofi is recommended; kitty gives the best tool view)
sudo pacman -S rofi kitty fzf

# if you are on Arch/Manjaro (not BlackArch), add the BlackArch repos first:
curl -O https://blackarch.org/strap.sh
echo "$(curl -s https://blackarch.org/strap.sh.sha1sum)" | sha1sum -c   # verify
sudo bash strap.sh

# then install the toolbox
git clone https://github.com/nithin2719-commits/Blackarch_Toolbox.git
cd Blackarch_Toolbox && ./install.sh
```

Install tool groups you want, e.g. `sudo pacman -S blackarch-webapp`, then
`blackarch-toolbox --refresh`.

---

## Debian / Ubuntu / Kali / Parrot

Uses the distro-neutral catalogue backend. On **Kali** and **Parrot** most tools
are already present, so the menu fills out immediately.

```bash
sudo apt update
sudo apt install -y rofi kitty fzf git    # rofi/kitty optional; fzf always works

git clone https://github.com/nithin2719-commits/Blackarch_Toolbox.git
cd Blackarch_Toolbox && ./install.sh
```

On plain Debian/Ubuntu, install the tools you need from `apt` (or pipx/go), then
`blackarch-toolbox --refresh`. To pull the full Kali toolset on Debian/Ubuntu:

```bash
# Kali metapackages on Debian/Ubuntu (optional)
sudo apt install -y kali-tools-top10        # or kali-linux-large, etc.
```

---

## Fedora / RHEL / Rocky / Alma

```bash
sudo dnf install -y rofi kitty fzf git
git clone https://github.com/nithin2719-commits/Blackarch_Toolbox.git
cd Blackarch_Toolbox && ./install.sh
```

Install security tools from Fedora's repos, `pipx`, `go install`, etc. The
catalogue backend picks them up from `PATH` on the next `--refresh`.

---

## openSUSE

```bash
sudo zypper install -y rofi kitty fzf git
git clone https://github.com/nithin2719-commits/Blackarch_Toolbox.git
cd Blackarch_Toolbox && ./install.sh
```

---

## Alpine

```bash
sudo apk add bash gawk fzf git      # bash + gawk are required; fzf is the menu
git clone https://github.com/nithin2719-commits/Blackarch_Toolbox.git
cd Blackarch_Toolbox && ./install.sh --no-keybind
```

Alpine is common on headless boxes — `fzf` gives you the full menu in the
terminal with no desktop needed.

---

## macOS

```bash
brew install bash gawk fzf git          # macOS ships an ancient bash; brew's is required
# optional GUI menu/terminal:
brew install --cask kitty
git clone https://github.com/nithin2719-commits/Blackarch_Toolbox.git
cd Blackarch_Toolbox && ./install.sh --no-keybind
```

Bind a hotkey with Raycast, Alfred, or `skhd` to run `blackarch-toolbox`.
Install tools with `brew` — the catalogue backend resolves them from `PATH`.

---

## Windows (WSL)

BlackArch tools are Linux binaries, so on Windows they run inside **WSL**. The
PowerShell installer sets up the Windows-side glue (Start-menu shortcut +
global **Alt+A** hotkey) and runs the Linux install inside your distro.

```powershell
# 1. install WSL once (admin PowerShell), then reboot
wsl --install -d kali-linux          # or: -d Ubuntu / -d Debian

# 2. clone the repo (inside WSL is cleanest) and run the Windows installer
#    from the repo root in normal PowerShell:
powershell -ExecutionPolicy Bypass -File windows\install.ps1
```

For the global Alt+A hotkey, install [AutoHotkey v2](https://autohotkey.com).
Without it you still get the Start-menu shortcut (pin it to the taskbar).

Flags: `-Distro <name>`, `-NoHotkey`, `-Uninstall`.

---

## Getting the tools

The toolbox is a **launcher** — it shows and opens tools that are installed. How
you install the tools depends on the distro:

| Distro | Install tools with |
|--------|--------------------|
| Arch / BlackArch | `pacman -S blackarch-<group>` (e.g. `blackarch-webapp`) |
| Debian / Ubuntu | `apt install <tool>`, or Kali metapackages |
| Kali / Parrot | mostly preinstalled; `apt install <tool>` for more |
| Fedora / openSUSE | `dnf` / `zypper`, plus `pipx` / `go install` |
| macOS | `brew install <tool>` |
| any | `pipx install`, `go install`, `cargo install`, tarballs on `PATH` |

After installing new tools, refresh the index so they appear:

```bash
blackarch-toolbox --refresh
```

To add tools that aren't in the catalogue yet, see
[ADDING-TOOLS.md](ADDING-TOOLS.md).

---

## Uninstalling

```bash
./install.sh --uninstall                 # Linux/macOS/WSL
powershell -File windows\install.ps1 -Uninstall   # Windows side
```

This removes the symlink, the application entry, and the keybinding block. To
purge the cache too: `rm -rf ~/.cache/blackarch-toolbox`.
