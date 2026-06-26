#!/bin/bash
# setup.sh — instalación completa: AMBxst + herramientas visuales + dotfiles

set -e
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; CYAN='\033[0;36m'; RESET='\033[0m'
step() { echo -e "\n${CYAN}▶ $*${RESET}"; }
ok()   { echo -e "${GREEN}✓ $*${RESET}"; }
warn() { echo -e "${YELLOW}⚠ $*${RESET}"; }
die()  { echo -e "${RED}✗ $*${RESET}"; exit 1; }

[[ $EUID -eq 0 ]] && die "No ejecutes como root."
command -v pacman &>/dev/null || die "Este script es solo para Arch Linux."

# ── 1. AMBxst ────────────────────────────────────────────────────────────────

step "1/3 — AMBxst"
if command -v ambxst &>/dev/null; then
    ok "AMBxst ya instalado"
else
    curl -L get.axeni.de/ambxst | sh
    ok "AMBxst instalado"
fi

ambxst install hyprland
ok "AMBxst integrado con Hyprland"

# ── 2. Herramientas visuales ─────────────────────────────────────────────────

step "2/3 — Herramientas visuales"

# Instalar yay si no existe
if ! command -v yay &>/dev/null; then
    sudo pacman -S --needed --noconfirm git base-devel
    tmp=$(mktemp -d)
    git clone https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin"
    (cd "$tmp/yay-bin" && makepkg -si --noconfirm)
    rm -rf "$tmp"
    ok "yay instalado"
fi

TOOLS=(kitty cava btop fastfetch)
for pkg in "${TOOLS[@]}"; do
    if command -v "$pkg" &>/dev/null; then
        ok "$pkg ya instalado"
    else
        yay -S --needed --noconfirm "$pkg" && ok "$pkg instalado" || warn "$pkg: falló la instalación"
    fi
done

# ── 3. Dotfiles ───────────────────────────────────────────────────────────────

step "3/3 — Dotfiles"
mkdir -p ~/.config
for cfg in kitty cava btop fastfetch; do
    cp -r "$REPO_DIR/.config/$cfg" ~/.config/ && ok "$cfg" || warn "$cfg: error al copiar"
done

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${GREEN}  Listo. Ejecuta 'ambxst' para iniciar.${RESET}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
