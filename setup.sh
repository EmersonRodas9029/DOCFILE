#!/bin/bash
# setup.sh — instalación completa: AMBxst + herramientas visuales + dotfiles

set -e
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

type() {
    local text="$1" color="${2:-$RESET}"
    echo -en "$color"
    for ((i=0; i<${#text}; i++)); do
        echo -n "${text:$i:1}"
        sleep 0.03
    done
    echo -e "$RESET"
}

step() { echo ""; type "▶ $*" "$CYAN$BOLD"; }
ok()   { type "  ✓ $*" "$GREEN"; }
warn() { type "  ⚠ $*" "$YELLOW"; }
die()  { type "  ✗ $*" "$RED"; exit 1; }

[[ $EUID -eq 0 ]] && die "No ejecutes como root."
command -v pacman &>/dev/null || die "Este script es solo para Arch Linux."

# ── Bienvenida ────────────────────────────────────────────────────────────────

clear
echo ""
type "  ╔══════════════════════════════════════════╗" "$CYAN"
type "  ║       DOCFILE — Setup Visual             ║" "$CYAN"
type "  ║  AMBxst · Fuentes · Dotfiles · Starship  ║" "$CYAN"
type "  ╚══════════════════════════════════════════╝" "$CYAN"
echo ""
sleep 0.5

# ── 0. Detectar config de Hyprland ───────────────────────────────────────────

step "0/4 — Detectando configuración de Hyprland"
HYPR_CONF="$HOME/.config/hypr/hyprland.conf"
HYPR_LUA="$HOME/.config/hypr/hyprland.lua"

if [[ -f "$HYPR_CONF" ]]; then
    HYPR_FORMAT="conf"
    ok "Encontrado: hyprland.conf"
elif [[ -f "$HYPR_LUA" ]]; then
    HYPR_FORMAT="lua"
    ok "Encontrado: hyprland.lua"
else
    die "No se encontró hyprland.conf ni hyprland.lua en ~/.config/hypr/ — ¿Hyprland está instalado?"
fi

# ── 1. AMBxst ────────────────────────────────────────────────────────────────

step "1/4 — AMBxst"
if command -v ambxst &>/dev/null; then
    ok "AMBxst ya instalado"
else
    type "  Descargando AMBxst..." "$CYAN"
    curl -L get.axeni.de/ambxst | sh
    ok "AMBxst instalado"
fi

ambxst install hyprland
ok "AMBxst integrado con Hyprland (formato: $HYPR_FORMAT)"

# ── 2. Herramientas y fuentes ─────────────────────────────────────────────────

step "2/4 — Herramientas visuales y fuentes"

if ! command -v yay &>/dev/null; then
    type "  Instalando yay..." "$CYAN"
    sudo pacman -S --needed --noconfirm git base-devel
    tmp=$(mktemp -d)
    git clone https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin"
    (cd "$tmp/yay-bin" && makepkg -si --noconfirm)
    rm -rf "$tmp"
    ok "yay instalado"
fi

TOOLS=(kitty cava btop fastfetch starship)
for pkg in "${TOOLS[@]}"; do
    if command -v "$pkg" &>/dev/null; then
        ok "$pkg ya instalado"
    else
        type "  Instalando $pkg..." "$CYAN"
        yay -S --needed --noconfirm "$pkg" && ok "$pkg instalado" || warn "$pkg: falló la instalación"
    fi
done

FONTS=(
    ttf-nerd-fonts-symbols ttf-nerd-fonts-symbols-common
    ttf-phosphor-icons ttf-league-gothic
    ttf-roboto ttf-roboto-mono
    noto-fonts noto-fonts-cjk noto-fonts-emoji
    ttf-dejavu ttf-liberation
)
type "  Instalando fuentes..." "$CYAN"
sudo pacman -S --needed --noconfirm "${FONTS[@]}" && ok "Fuentes instaladas" || warn "Algunas fuentes fallaron"

# ── 3. Dotfiles ───────────────────────────────────────────────────────────────

step "3/4 — Dotfiles"
mkdir -p ~/.config
for cfg in kitty cava btop fastfetch; do
    cp -r "$REPO_DIR/.config/$cfg" ~/.config/ && ok "$cfg" || warn "$cfg: error al copiar"
done
cp "$REPO_DIR/.config/starship.toml" ~/.config/starship.toml && ok "starship.toml" || warn "starship.toml: error al copiar"

# ── Fin ───────────────────────────────────────────────────────────────────────

echo ""
sleep 0.3
type "  ╔══════════════════════════════════════════╗" "$GREEN"
type "  ║   Instalación completada con éxito.      ║" "$GREEN"
type "  ║   Ejecuta 'ambxst' para iniciar.         ║" "$GREEN"
type "  ╚══════════════════════════════════════════╝" "$GREEN"
echo ""
