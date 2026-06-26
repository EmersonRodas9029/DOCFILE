#!/bin/bash
# install-aesthetic.sh — instala AMBxst e integra con Hyprland

set -e

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; RESET='\033[0m'
ok()   { echo -e "${GREEN}✓ $*${RESET}"; }
warn() { echo -e "${YELLOW}⚠ $*${RESET}"; }
die()  { echo -e "${RED}✗ $*${RESET}"; exit 1; }

[[ $EUID -eq 0 ]] && die "No ejecutes como root."
command -v pacman &>/dev/null || die "Este script es solo para Arch Linux."

# ── 1. Instalar AMBxst ───────────────────────────────────────────────────────

if command -v ambxst &>/dev/null; then
    ok "AMBxst ya instalado"
else
    echo "Instalando AMBxst..."
    curl -L get.axeni.de/ambxst | sh
    ok "AMBxst instalado"
fi

# ── 2. Dotfiles ──────────────────────────────────────────────────────────────

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Copiando dotfiles..."
cp -r "$REPO_DIR/.config/kitty"    ~/.config/ && ok "kitty"    || warn "kitty: error al copiar"
cp -r "$REPO_DIR/.config/cava"     ~/.config/ && ok "cava"     || warn "cava: error al copiar"
cp -r "$REPO_DIR/.config/btop"     ~/.config/ && ok "btop"     || warn "btop: error al copiar"
cp -r "$REPO_DIR/.config/fastfetch" ~/.config/ && ok "fastfetch" || warn "fastfetch: error al copiar"

# ── 3. Integrar con Hyprland ─────────────────────────────────────────────────

echo "Integrando AMBxst con Hyprland..."
ambxst install hyprland
ok "Integración con Hyprland completada"

echo ""
echo -e "${GREEN}Listo. Ejecuta 'ambxst' para iniciar.${RESET}"
