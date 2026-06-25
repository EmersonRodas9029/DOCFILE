# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Dotfiles and installation scripts for an Arch Linux + Hyprland system (Intel CPU + NVIDIA GPU, PRIME offload). Used to migrate the full setup to another PC.

## Scripts

| Script | Purpose |
|--------|---------|
| `install-full.sh` | Full system from scratch: creates user (if root), installs all packages, dotfiles, NVIDIA, zram, services, shell. Run as root first, then as user. |
| `install-aesthetic.sh` | Visual layer only: installs terminal/visual packages + AMBxst, copies visual dotfiles, patches Hyprland config. Requires Hyprland already installed. |

Both scripts are idempotent — safe to re-run. Failed packages are skipped with a warning, not a fatal error (by design, some AUR packages vary by system).

## Hyprland config format

The repo stores `hyprland.conf` (classic format). Some PCs may use `hyprland.lua` instead. Both scripts detect which exists and act accordingly:

- `.conf` → `source = ~/.local/share/ambxst/hyprland.conf`
- `.lua` → `hyprland.source("~/.local/share/ambxst/hyprland.conf")`

When adding new `install-*` steps that touch the Hyprland config, always check for both `~/.config/hypr/hyprland.conf` and `~/.config/hypr/hyprland.lua`.

## Package lists

- `packages/pkgs.txt` — official repos (pacman)
- `packages/aur.txt` — AUR packages

Both are plain text, one package per line. Blank lines and lines ending in `-debug` are filtered out during install.

## AMBxst

AMBxst (`~/.local/share/ambxst/`) provides animations, decorations, and keybinds via a sourced `hyprland.conf`. The installer checks for `command -v ambxst` before installing. If AMBxst is absent, its `source =` line in hyprland.conf will produce an error at startup — comment it out if not using AMBxst.

## NVIDIA / hardware notes

- This is a PRIME offload setup: iGPU drives display, dGPU renders via `prime-run`
- Apps launched with `DISPLAY=:1` need XWayland active
- `system/modprobe.d/audio-nvidia.conf` contains `alc245-fixup` — adjust the codec model if audio fails on different hardware
- Without NVIDIA: remove `DISPLAY=:1` and `prime-run` from keybinds in `hyprland.conf`
