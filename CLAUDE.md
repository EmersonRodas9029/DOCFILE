# CLAUDE.md

This file provides guidance to Claude Code when working with this repository.

## What this repo is

Dotfiles and installation script for an Arch Linux + Hyprland visual setup.
Designed to replicate the aesthetic layer of the system on a new machine.

## Scripts

| Script | Purpose |
|--------|---------|
| `setup.sh` | Full visual setup: AMBxst, tools, fonts, dotfiles, shell integration. Run as user (not root). |
| `install-aesthetic.sh` | Minimal: installs AMBxst only and integrates with Hyprland. |

Both scripts are idempotent — safe to re-run.

## Hyprland config format

Scripts detect which config exists and act accordingly:
- `hyprland.conf` → `source = ~/.local/share/ambxst/hyprland.conf`
- `hyprland.lua` → `loadfile(os.getenv("HOME") .. "/.local/share/ambxst/hyprland.lua")()`

Always check for both files when touching Hyprland config in new steps.

## Dotfiles included

| App | Path |
|-----|------|
| Kitty | `.config/kitty/` |
| Cava | `.config/cava/` |
| Btop | `.config/btop/` |
| Fastfetch | `.config/fastfetch/` |
| Starship | `.config/starship.toml` |

## AMBxst

Installed via `curl -L get.axeni.de/ambxst | sh`.
Integrated via `ambxst install hyprland`.
Config lives at `~/.config/ambxst/`.

## Fonts installed

All from official Arch repos (pacman):
`ttf-nerd-fonts-symbols`, `ttf-phosphor-icons`, `ttf-league-gothic`,
`ttf-roboto`, `ttf-roboto-mono`, `noto-fonts`, `noto-fonts-cjk`,
`noto-fonts-emoji`, `ttf-dejavu`, `ttf-liberation`
