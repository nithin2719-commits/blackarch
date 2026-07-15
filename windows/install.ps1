<#
    BlackArch Toolbox — Windows installer.

    BlackArch's tools are Linux binaries, so on Windows the toolbox runs inside
    WSL (Windows Subsystem for Linux) and this script is the Windows-side glue:

      1. verifies WSL is present (and offers the one-liner to install it);
      2. runs the normal Linux install.sh *inside* your WSL distro, so the
         launcher, index and per-tool views all live there;
      3. creates a Start-menu shortcut and an AutoHotkey script that bind
         Alt+A to pop the toolbox open in a WSL terminal from anywhere in
         Windows -- the same key as on native Linux.

    Run from PowerShell (no admin needed for the toolbox itself):
        powershell -ExecutionPolicy Bypass -File windows\install.ps1

    Flags:
        -Distro <name>   which WSL distro to install into (default: default one)
        -NoHotkey        skip the Alt+A AutoHotkey step
        -Uninstall       remove the Windows-side shortcut and hotkey
#>

param(
    [string]$Distro = "",
    [switch]$NoHotkey,
    [switch]$Uninstall
)

$ErrorActionPreference = "Stop"
$Repo = Split-Path -Parent $PSScriptRoot          # repo root (parent of windows/)
$Accent = "Red"

function Say  ($m) { Write-Host "  > $m" -ForegroundColor $Accent }
function Info ($m) { Write-Host "    $m" -ForegroundColor Gray }

function Banner {
    Write-Host ""
    Write-Host "  BLACK" -ForegroundColor White -NoNewline
    Write-Host "ARCH"    -ForegroundColor Red   -NoNewline
    Write-Host " TOOLBOX (Windows)" -ForegroundColor DarkGray
    Write-Host ""
}

# Convert a Windows repo path to the WSL mount path (C:\Users\x -> /mnt/c/Users/x).
function To-WslPath ($winPath) {
    $full = (Resolve-Path $winPath).Path
    $drive = $full.Substring(0,1).ToLower()
    $rest  = $full.Substring(2) -replace '\\','/'
    return "/mnt/$drive$rest"
}

$StartMenu = [Environment]::GetFolderPath("StartMenu")
$Shortcut  = Join-Path $StartMenu "Programs\BlackArch Toolbox.lnk"
$AhkDir    = Join-Path $env:APPDATA "BlackArchToolbox"
$AhkScript = Join-Path $AhkDir "blackarch-hotkey.ahk"

Banner

if ($Uninstall) {
    Say "Uninstalling Windows-side integration"
    if (Test-Path $Shortcut)  { Remove-Item $Shortcut  -Force; Info "removed Start-menu shortcut" }
    if (Test-Path $AhkScript) { Remove-Item $AhkScript -Force; Info "removed AutoHotkey script" }
    $run = Join-Path ([Environment]::GetFolderPath("Startup")) "BlackArchToolbox.lnk"
    if (Test-Path $run) { Remove-Item $run -Force; Info "removed startup entry" }
    Info "Run './install.sh --uninstall' inside WSL to remove the Linux side."
    Say "Done."
    return
}

# 1. WSL present? ------------------------------------------------------------
Say "Checking for WSL"
$wsl = Get-Command wsl.exe -ErrorAction SilentlyContinue
if (-not $wsl) {
    Write-Host "    WSL is not installed." -ForegroundColor Yellow
    Info "Install it (admin PowerShell), reboot, then re-run this script:"
    Info "    wsl --install -d kali-linux      # or: Ubuntu, Debian"
    return
}
Info "WSL found"

$distroArgs = @()
if ($Distro -ne "") { $distroArgs = @("-d", $Distro) }

# 2. run the Linux installer inside WSL -------------------------------------
Say "Installing the toolbox inside WSL"
$wslRepo = To-WslPath $Repo
Info "repo (WSL path): $wslRepo"
# Keybinding inside WSL's own WM is meaningless from Windows, so skip it there;
# the Windows Alt+A hotkey below is what the user actually presses.
& wsl.exe @distroArgs -- bash -lc "cd '$wslRepo' && bash install.sh --no-keybind"
if ($LASTEXITCODE -ne 0) { Write-Host "    WSL install returned $LASTEXITCODE" -ForegroundColor Yellow }

# The command Windows uses to open the toolbox: launch it in a new WSL terminal.
# Windows Terminal (wt.exe) if present -- it's the nice one -- else a bare wsl window.
$distroFlag = ""
if ($Distro -ne "") { $distroFlag = "-d $Distro " }
$openCmd = "wsl.exe $distroFlag-- bash -lc 'blackarch-toolbox || ~/.local/bin/blackarch-toolbox'"

# 3. Start-menu shortcut -----------------------------------------------------
Say "Creating Start-menu shortcut"
$shell = New-Object -ComObject WScript.Shell
$lnk = $shell.CreateShortcut($Shortcut)
if (Get-Command wt.exe -ErrorAction SilentlyContinue) {
    $lnk.TargetPath = "wt.exe"
    $lnk.Arguments  = "wsl.exe $distroFlag-- bash -lc 'blackarch-toolbox'"
} else {
    $lnk.TargetPath = "wsl.exe"
    $lnk.Arguments  = "$distroFlag-- bash -lc 'blackarch-toolbox'"
}
$lnk.IconLocation = "$PSScriptRoot\blackarch.ico"
$lnk.Description  = "Launch any BlackArch security tool from one menu"
$lnk.Save()
Info $Shortcut

# 4. Alt+A global hotkey via AutoHotkey -------------------------------------
if (-not $NoHotkey) {
    Say "Setting up the Alt+A global hotkey"
    New-Item -ItemType Directory -Force -Path $AhkDir | Out-Null
    $ahk = @"
; BlackArch Toolbox — global Alt+A hotkey (AutoHotkey v2)
; Opens the toolbox menu in WSL from anywhere in Windows.
#Requires AutoHotkey v2.0
!a:: {
    Run('$($openCmd -replace "'","''")')
}
"@
    Set-Content -Path $AhkScript -Value $ahk -Encoding UTF8
    Info $AhkScript

    if (Get-Command AutoHotkey.exe -ErrorAction SilentlyContinue) {
        # Auto-start the hotkey on login by dropping a shortcut in Startup.
        $startup = Join-Path ([Environment]::GetFolderPath("Startup")) "BlackArchToolbox.lnk"
        $s = $shell.CreateShortcut($startup)
        $s.TargetPath = (Get-Command AutoHotkey.exe).Source
        $s.Arguments  = "`"$AhkScript`""
        $s.Save()
        Start-Process (Get-Command AutoHotkey.exe).Source -ArgumentList "`"$AhkScript`""
        Info "Alt+A is live now and will start on login."
    } else {
        Write-Host "    AutoHotkey v2 not found." -ForegroundColor Yellow
        Info "Install it from https://autohotkey.com, then run the script above,"
        Info "or just use the Start-menu shortcut / pin it to the taskbar."
    }
}

Write-Host ""
Say "Installed. Press Alt+A, use the Start-menu entry, or run in WSL:"
Info "blackarch-toolbox"
Write-Host ""
