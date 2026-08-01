<div align="center">

![BlackArch Toolbox](assets/banner.png)

**One keybinding to launch any of BlackArch's ~4000 security tools — from a clean, searchable menu, on any Linux distro, macOS, or Windows.**

[![Version](https://img.shields.io/badge/version-1.0.0-ff2b2b?style=flat-square)](CHANGELOG.md)
[![Platform](https://img.shields.io/badge/platform-Linux%20%C2%B7%20macOS%20%C2%B7%20Windows%2FWSL-ff7a45?style=flat-square)](docs/INSTALL.md)
[![Shell](https://img.shields.io/badge/built%20with-bash%20%2B%20awk-9a7d7d?style=flat-square)](lib/)
[![License](https://img.shields.io/badge/license-MIT-ff2b2b?style=flat-square)](LICENSE)

</div>

---

## What it is

BlackArch ships thousands of security tools, but finding and remembering how to
run them is its own job. **BlackArch Toolbox** turns the whole arsenal into a
single keystroke: press **`Alt`+`A`**, type any part of a tool's name, and hit
`Enter`. Don't know the name? Browse a category instead. Whatever you choose opens — a GUI tool in its own window,
a command-line tool in a themed terminal that shows you exactly how to run it
first.

<div align="center">

| The default view — favorites, recents, categories | Typing searches every tool |
|:---:|:---:|
| <img src="assets/menu.png" width="420"> | <img src="assets/menu-tools.png" width="420"> |

<img src="assets/toolview.png" width="860">

*The per-tool view: usage, flags and a shell scoped to that tool.*

</div>

It works the same everywhere: on **Arch/BlackArch** it reads BlackArch's own
package groups for full ~4000-tool fidelity; on **Debian, Ubuntu, Kali, Parrot,
Fedora, openSUSE, Alpine, macOS and Windows/WSL** it resolves a curated tool
catalogue against your `PATH`, so a tool shows up no matter how you installed it.

---

## Highlights

- **⌨️  One keybinding, everywhere** — `Alt`+`A` on Hyprland, sway, i3, GNOME,
  and Windows; a menu in any terminal over SSH.
- **🔎  Search-first** — the first row is **Search all tools**: one `Enter`
  into every indexed tool, filtered as you type.
- **⭐  Favorites & recents** — each its own folder in the main box, next to
  the categories. `Ctrl`+`S` stars whatever is highlighted, anywhere.
- **🧭  Categories when you need them** — 27 sections ordered like an engagement
  (recon → scan → exploit → escalate → specialist benches), for when you don't
  know the tool's name.
- **✅  Only runnable tools** — every entry is an executable that exists on your
  machine right now. No dead menu rows.
- **📖  Never a blank prompt** — CLI tools open into a screen with their
  description, synopsis, a curated quick-start for common tools, and a cleaned
  flag list, then a shell scoped to that tool with its own history.
- **🐧  Truly cross-distro** — pluggable package backends (pacman + a universal
  PATH catalogue) and menu backends (rofi / fuzzel / wofi / dmenu / fzf).
- **🪟  Windows via WSL** — same menu, same `Alt`+`A`, driven by a global hotkey.
- **🧩  Easy to extend** — add your own tools with a single line of text.
- **↩️  Reversible install** — no root, everything in your home, clean uninstall.

---

## Platform support

Works on any reasonably modern system. The launcher is Bash + awk, so the real
requirement is just **Bash ≥ 4** and a menu program; the table shows the
versions it's verified against and the kernel each needs.

| OS | Verified versions | Kernel | Backend | Notes |
|----|-------------------|--------|---------|-------|
| **BlackArch** | rolling | Linux ≥ 5.x | `pacman` | full ~4000-tool index |
| **Arch / Manjaro / EndeavourOS** | rolling | Linux ≥ 5.x | `pacman` | add BlackArch repo for the full set |
| **Kali Linux** | 2023.x – 2025.x | Linux ≥ 5.10 | `catalog` | most tools preinstalled |
| **Parrot OS** | 5.x / 6.x | Linux ≥ 5.10 | `catalog` | most tools preinstalled |
| **Debian** | 11 / 12 / 13 | Linux ≥ 5.10 | `catalog` | install tools via `apt` / Kali metapkgs |
| **Ubuntu** | 20.04 / 22.04 / 24.04 | Linux ≥ 5.4 | `catalog` | — |
| **Fedora** | 38 – 41 | Linux ≥ 6.x | `catalog` | — |
| **RHEL / Rocky / Alma** | 8 / 9 | Linux ≥ 4.18 | `catalog` | — |
| **openSUSE** | Leap 15.x / Tumbleweed | Linux ≥ 5.3 | `catalog` | — |
| **Alpine** | 3.18+ | Linux ≥ 5.x | `catalog` | needs `bash` + `gawk` |
| **macOS** | 12 Monterey – 15 Sequoia | Darwin (Intel/Apple Silicon) | `catalog` | Homebrew `bash` required |
| **Windows** | 10 / 11 | WSL 2 (Linux ≥ 5.15) | `catalog` | tools run inside a WSL distro |

> **Bash ≥ 4**, **awk** (gawk or busybox), and one menu (`rofi` / `fuzzel` /
> `wofi` / `dmenu` on a desktop, or `fzf` anywhere). Everything else is optional.
> Check your own versions with `bash --version`, `uname -sr`, and — after install
> — `blackarch-toolbox --version`.

## Install

> **TL;DR** — clone and run `./install.sh`. It needs no root, wires up
> `Alt`+`A`, and builds the index. Full per-distro steps (dependency package
> names for every OS) live in **[docs/INSTALL.md](docs/INSTALL.md)**.

```bash
git clone https://github.com/nithin2719-commits/Blackarch_Toolbox.git
cd Blackarch_Toolbox
./install.sh
```

Then press **`Alt`+`A`**, or run `blackarch-toolbox`.

<details>
<summary><b>Per-distro one-liners</b> (dependencies only — see the full guide for details)</summary>

```bash
# Arch / BlackArch / Manjaro / EndeavourOS
sudo pacman -S rofi kitty fzf

# Debian / Ubuntu / Kali / Parrot
sudo apt install -y rofi kitty fzf git

# Fedora / RHEL / Rocky / Alma
sudo dnf install -y rofi kitty fzf git

# openSUSE
sudo zypper install -y rofi kitty fzf git

# Alpine
sudo apk add bash gawk fzf git

# macOS (Homebrew)
brew install bash gawk fzf git && brew install --cask kitty
```

Then in every case: `git clone … && cd Blackarch_Toolbox && ./install.sh`

</details>

<details>
<summary><b>Windows (WSL)</b></summary>

BlackArch's tools are Linux binaries, so on Windows they run through WSL. The
PowerShell installer adds a Start-menu shortcut and a global `Alt`+`A` hotkey.

```powershell
wsl --install -d kali-linux          # once, then reboot (or -d Ubuntu / -d Debian)
powershell -ExecutionPolicy Bypass -File windows\install.ps1
```

Full steps: **[docs/INSTALL.md ▸ Windows](docs/INSTALL.md#windows-wsl)**.

</details>

---

## Usage

The fast path is **`Alt`+`A`, `Enter`, type** — the search list is the first
row, so it opens on the keystroke you were already pressing.

The main box holds **destinations, never tools** — so it is the same short
shape whether you have starred two tools or fifty:

```
  🔍 Search all tools   4311 tools ›    every indexed tool, one Enter away
  ★  Favorites             2 tools ›    what you starred with Ctrl+S
  ↻  Recent                3 tools ›    filled in as you launch things
     Recon                640 tools ›
     Scanner              962 tools ›   …27 categories
```

Every row opens a list of tools you filter by typing. **Favorites** and
**Recent** are folders exactly like the categories, and stay in place even at
zero, so the box never changes shape underneath you.

**Don't know the name?** Pick a category and browse it — same picker, same keys.
`Esc` goes back up, `Esc` again closes.

**Search matches tool names, not descriptions.** Typing `nmap` gives you `nmap`
first, then `wnmap`, `asnmap`, `lanmap2-cap` — not every tool whose blurb happens
to mention nmap. Matching is **substring**, not fuzzy (fuzzy scatters the query
letters across the row, which is how `metasploit` used to return `mentalist`),
and results are ranked by closeness, so an exact name lands at the top.

| Action | How |
|--------|-----|
| Open the menu | **`Alt`+`A`**, or `blackarch-toolbox` |
| Launch a tool by name | **`Alt`+`A`**, `Enter`, type any part of the name, `Enter` |
| Browse a category | pick a section (e.g. **Web App**) to drill into it |
| Star / unstar the highlighted tool | **`Ctrl`+`S`** (rofi and fzf) |
| Go back a level | `Esc` |
| Close the menu | `Esc` again, or press `Alt`+`A` a second time |
| Rebuild the index (after installing tools) | `blackarch-toolbox --refresh` |
| Open one tool by name | `blackarch-toolbox --run nmap` |
| List every indexed tool | `blackarch-toolbox --list` |
| Show settings & paths | `blackarch-toolbox --config` |

When you pick a **CLI tool**, it opens in a themed terminal showing its usage and
flags, then hands you a shell scoped to that tool — type `run …`, `help`,
`flags`, or `man` as shortcuts. A **GUI tool** just opens its own window (resolved
through its desktop entry, so even apps with unusual launch names open reliably).

---

## Keyboard shortcut

The installer binds the toolbox to **`Alt`+`A`** on whatever desktop you run, by
writing a single, clearly-marked block it can later remove cleanly:

| Desktop | Where the binding is written |
|---------|------------------------------|
| **Hyprland** | `~/.config/hypr/keybindings.conf` (or `hyprland.conf`) |
| **sway** | `~/.config/sway/config` |
| **i3** | `~/.config/i3/config` |
| **GNOME** | a custom shortcut via `gsettings` |
| **KDE** | guided steps (System Settings ▸ Shortcuts) |
| **Windows** | global hotkey via AutoHotkey (see [Windows install](docs/INSTALL.md#windows-wsl)) |

**Change the key** — pass `--key` at install time:

```bash
./install.sh --key "SUPER B"      # bind Super+B instead
./install.sh --no-keybind         # don't touch any config; bind it yourself
```

**Bind it by hand** (any launcher) — just run the command `blackarch-toolbox`.
For example, on Hyprland:

```ini
bind = ALT, A, exec, blackarch-toolbox
```

Pressing the key again while the menu is open closes it.

---

## The tool sections

The menu is organised into 27 sections, in the order an engagement actually
flows. On Arch/BlackArch each maps to BlackArch's package groups; elsewhere to
catalogue categories.

| | Section | What's inside |
|---|---------|---------------|
| 🔎 | **Recon** | nmap, masscan, amass, subfinder, theHarvester, recon-ng, httpx… |
| 🎯 | **Scanner** | nuclei, nikto, openvas, nessus, trivy, lynis, testssl.sh… |
| 🕸️ | **Web App** | sqlmap, gobuster, feroxbuster, wpscan, ffuf, burpsuite, ZAP… |
| 💥 | **Fuzzer** | ffuf, wfuzz, afl++, honggfuzz, radamsa, boofuzz… |
| 🧨 | **Exploitation** | metasploit, searchsploit, setoolkit, sliver, netexec… |
| 🔓 | **Cracker** | hashcat, john, hydra, medusa, ncrack, name-that-hash… |
| 🔐 | **Passwords & Crypto** | openssl, gpg, age, sops, RsaCtfTool, featherduster… |
| 🪟 | **Windows & AD** | impacket, bloodhound, certipy, kerbrute, responder, evil-winrm… |
| 🚪 | **Backdoor & Post** | weevely, msfvenom, chisel, ligolo-ng, pupy… |
| 🦠 | **Malware** | yara, clamav, capa, floss, Detect-It-Easy… |
| 👂 | **Sniffer & MitM** | wireshark, tcpdump, ettercap, bettercap, ngrep… |
| 🔀 | **Proxy** | mitmproxy, proxychains, socat, stunnel… |
| 📡 | **Wireless** | aircrack-ng, wifite, kismet, reaver, hcxdumptool, fluxion… |
| 📶 | **Bluetooth & NFC** | bluetoothctl, btscanner, mfoc, mfcuk, proxmark3… |
| 📻 | **Radio & SDR** | rtl_433, gqrx, gnuradio, multimon-ng, hackrf… |
| 🔬 | **Reversing** | ghidra, cutter, rizin, radare2, gdb, jadx… |
| 🧱 | **Binary** | pwntools, ropper, one_gadget, checksec, patchelf, upx… |
| 🧾 | **Forensic** | volatility, autopsy, sleuthkit, binwalk, foremost, steghide… |
| 🛡️ | **Defensive** | suricata, zeek, snort, fail2ban, rkhunter, chkrootkit… |
| 🕵️ | **Social & OSINT** | sherlock, maigret, holehe, spiderfoot, maltego, h8mail… |
| 📱 | **Mobile** | apktool, jadx, mobsf, frida, objection, adb, scrcpy… |
| 🌐 | **Networking** | netcat, ncat, hping3, scapy, netdiscover, arp-scan, mtr… |
| 🗄️ | **Database** | sqlmap, nosqlmap, mongoaudit, mysql, psql, redis-cli… |
| 🧑‍💻 | **Code Audit** | semgrep, bandit, gitleaks, trufflehog, brakeman, safety… |
| ⚙️ | **Automation** | reconftw, osmedeus, autorecon, sn0int… |
| 🍯 | **Honeypot** | cowrie, honeyd, opencanary, pentbox… |
| 🔩 | **Hardware & Firmware** | flashrom, openocd, sigrok, esptool, binwalk… |

*(plus **DoS** and **Misc** for everything else.)*

---

## Getting the tools themselves

The toolbox is a launcher, not a package manager — it shows what is **installed
on this machine**. So the menu grows as you install tools. Pick whichever of
these you actually need; none of it is required to use the launcher.

### Arch / BlackArch — the full arsenal

Add the BlackArch repository once, then install by category or by tool:

```bash
# add the repo (official strap script)
curl -O https://blackarch.org/strap.sh
echo "$(curl -s https://blackarch.org/strap.sh.sig | grep -o '[0-9a-f]\{40\}')  strap.sh" | sha1sum -c   # verify
sudo chmod +x strap.sh && sudo ./strap.sh

sudo pacman -Syu

# then install what you want
sudo pacman -S blackarch                 # everything (~50 GB, rarely what you want)
sudo pacman -S blackarch-webapp          # one category
sudo pacman -S blackarch-wireless        # another
sudo pacman -S nmap sqlmap hydra         # individual tools

blackarch-toolbox --refresh              # re-index
```

List the categories with `sudo pacman -Sg | grep blackarch`.

### Kali / Parrot — metapackages

```bash
sudo apt update
sudo apt install -y kali-tools-top10       # the usual suspects
sudo apt install -y kali-tools-wireless    # or a category
sudo apt install -y kali-linux-large       # a lot of it
blackarch-toolbox --refresh
```

### Debian / Ubuntu

Most classics are in the normal repositories:

```bash
sudo apt update && sudo apt install -y \
  nmap masscan sqlmap nikto hydra john hashcat aircrack-ng kismet \
  wireshark tshark tcpdump ettercap-text-only dsniff \
  gobuster dirb wfuzz whatweb wafw00f dnsrecon dnsenum \
  binwalk foremost exiftool steghide radare2 gdb ltrace strace \
  smbclient enum4linux onesixtyone snmp arp-scan netdiscover hping3 \
  proxychains4 tor socat netcat-openbsd
blackarch-toolbox --refresh
```

For the Go/Python-native tools (`nuclei`, `subfinder`, `httpx`, `ffuf`,
`feroxbuster`, `netexec`, `impacket`…):

```bash
sudo apt install -y pipx golang-go && pipx ensurepath
pipx install netexec impacket sqlmap wpscan
go install -v github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest
go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest
go install -v github.com/ffuf/ffuf/v2@latest
blackarch-toolbox --refresh
```

### Fedora / RHEL / Rocky / Alma

```bash
sudo dnf install -y nmap masscan sqlmap nikto hydra john hashcat \
  aircrack-ng wireshark-cli tcpdump binwalk foremost perl-Image-ExifTool \
  radare2 gdb ltrace strace samba-client tor socat nmap-ncat
blackarch-toolbox --refresh
```

### openSUSE

```bash
sudo zypper install -y nmap sqlmap nikto hydra john hashcat aircrack-ng \
  wireshark tcpdump binwalk radare2 gdb strace samba-client tor socat
blackarch-toolbox --refresh
```

### Alpine

```bash
sudo apk add nmap nmap-scripts masscan nikto john hashcat aircrack-ng \
  tcpdump binwalk radare2 gdb strace samba-client tor socat
blackarch-toolbox --refresh
```

### macOS (Homebrew)

```bash
brew install nmap masscan sqlmap nikto hydra john-jumbo hashcat \
  aircrack-ng wireshark tcpdump binwalk exiftool radare2 gdb \
  socat tor gobuster ffuf
blackarch-toolbox --refresh
```

### Windows

The tools are Linux binaries, so they run inside WSL — install a distro, then
follow the Kali or Debian steps above inside it. See
**[docs/INSTALL.md ▸ Windows](docs/INSTALL.md#windows-wsl)**.

---

## Adding your own tools

The box shows what's installed. To add a tool it doesn't know yet, it's **one
line of text** — full guide in **[docs/ADDING-TOOLS.md](docs/ADDING-TOOLS.md)**.

**On Arch/BlackArch** there's nothing to do — install the package and refresh:

```bash
sudo pacman -S sqlmap && blackarch-toolbox --refresh
```

**Anywhere else** (and for anything outside BlackArch's groups), add a
tab-separated line to [`data/catalog.tsv`](data/catalog.tsv) —
`binary`, `category`, `description`:

```
dnsx	recon	Fast and multi-purpose DNS toolkit
```

…then `blackarch-toolbox --refresh`. The tool appears in **Recon** as soon as
`dnsx` is on your `PATH` — and never before, so the menu can't offer you
something that isn't there.

**Valid categories** are the section slugs — list them with:

```bash
cut -f2 data/catalog.tsv | grep -v '^#' | sort -u
```

**A tool that isn't on your `PATH`** (a `.jar`, a cloned repo, a script) just
needs a wrapper somewhere on `PATH`:

```bash
mkdir -p ~/.local/bin
printf '#!/bin/sh\nexec java -jar /opt/burpsuite.jar "$@"\n' > ~/.local/bin/burpsuite
chmod +x ~/.local/bin/burpsuite
blackarch-toolbox --refresh
```

---

## Configuration

Copy [`config/config.example`](config/config.example) to
`~/.config/blackarch-toolbox/config`, or set any of these as environment
variables for a one-off run:

| Variable | Values | Meaning |
|----------|--------|---------|
| `BAT_MENU` | `auto` · rofi · fuzzel · wofi · dmenu · fzf | which picker to use |
| `BAT_TERMINAL` | `auto` · kitty · alacritty · foot · … | terminal for CLI tools |
| `BAT_BACKEND` | `auto` · pacman · catalog | package backend |
| `BAT_GUI_MODE` | `auto` · always-terminal | force the terminal view for GUI tools |

```bash
BAT_MENU=fzf blackarch-toolbox        # e.g. force the terminal menu over SSH
```

---

## How it works

```
  Alt+A ─▶ bin/blackarch-toolbox ─▶ lib/launcher.sh
                                       │
              ┌────────────────────────┼─────────────────────────┐
              ▼                        ▼                          ▼
        lib/menu.sh              lib/refresh.sh              lib/terminal.sh
     (rofi/fuzzel/wofi/       builds the index via a       (kitty/alacritty/
      dmenu/fzf picker)       package backend …            foot/… + inline)
                                       │
                       ┌───────────────┴───────────────┐
                       ▼                                ▼
             lib/backends/pacman.sh          lib/backends/catalog.sh
          (BlackArch pacman groups,        (data/catalog.tsv resolved
           ~4000 tools on Arch)             against PATH, every other OS)
```

- **Backends** answer one question — *"which runnable tools exist, and in what
  category?"* — so adding OS support is adding a backend, not touching the UI.
- The index and every per-tool help/history file live under
  `~/.cache/blackarch-toolbox`, never in the repo, so one system-wide install
  serves multiple users.
- The launcher does **zero per-tool work at click time** — every menu row,
  including its pango markup and its padded name column, is pre-rendered by
  `lib/render.awk` at index time, so opening even a 900-tool section is instant.
- Picking a row returns its **index**, never its text, so the pretty display
  column stays fully decoupled from the binary that actually gets launched.

---

## Requirements

- **Bash ≥ 4** and **awk** (gawk or busybox awk) — present on essentially every
  Linux/macOS system (macOS needs Homebrew's bash).
- **A menu**: `rofi` / `fuzzel` / `wofi` / `dmenu` on a desktop, or `fzf`
  anywhere (including headless/SSH).
- **Optional**: `kitty` for the richest per-tool view; `magick` (ImageMagick)
  for the inline tool-name banner; `notify-send` for launch notifications.

---

## Uninstall

```bash
./install.sh --uninstall                            # Linux / macOS / WSL
powershell -File windows\install.ps1 -Uninstall     # Windows side
rm -rf ~/.cache/blackarch-toolbox                   # purge the cache too
```

---

## Troubleshooting

Common fixes — GUI tool won't open, menu feels slow, no tools shown, `Alt`+`A`
not working — are collected in
**[docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)**.

## Contributing

Catalogue additions are just text — open a PR against
[`data/catalog.tsv`](data/catalog.tsv) (sorted by category, one-sentence
descriptions). See **[CONTRIBUTING.md](CONTRIBUTING.md)**. Bug reports and new
backends welcome.

## License

[MIT](LICENSE) © 2026 Nithin G. BlackArch and its logo are trademarks of the
BlackArch Linux project; this is an independent launcher, not affiliated with
or endorsed by BlackArch.
