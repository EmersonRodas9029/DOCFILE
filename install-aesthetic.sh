#!/bin/bash
# install-aesthetic.sh — solo lo visual: AMBxst, Kitty, btop, cava, fastfetch, starship
# Requiere: Arch Linux con Hyprland ya instalado y usuario con sudo

set -e
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; RESET='\033[0m'
step() { echo -e "\n${CYAN}▶ $*${RESET}"; }
ok()   { echo -e "${GREEN}✓ $*${RESET}"; }
warn() { echo -e "${YELLOW}⚠ $*${RESET}"; }
die()  { echo -e "${RED}✗ $*${RESET}"; exit 1; }

[[ $EUID -eq 0 ]] && die "No ejecutes como root."
command -v pacman &>/dev/null || die "Este script es solo para Arch Linux."
sudo -v || die "No se pudo obtener permisos sudo."

# ── 1. Paquetes visuales ─────────────────────────────────────────────────────

step "1/4 — Paquetes visuales"

if ! command -v yay &>/dev/null; then
    sudo pacman -S --needed --noconfirm git base-devel
    tmp=$(mktemp -d)
    git clone https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin"
    (cd "$tmp/yay-bin" && makepkg -si --noconfirm)
    rm -rf "$tmp"
    ok "yay instalado"
fi

VISUAL_PKGS=(
    # Terminales y prompt
    kitty starship
    # Visualizadores
    cava btop fastfetch
    # Theming / colores
    matugen adw-gtk-theme
    # Fuentes
    ttf-iosevka-nerd ttf-phosphor-icons ttf-league-gothic
    ttf-roboto ttf-roboto-mono ttf-dejavu ttf-liberation
    ttf-nerd-fonts-symbols noto-fonts noto-fonts-cjk noto-fonts-emoji
    # Deps visuales de AMBxst/Hyprland
    brightnessctl dunst libnotify mpvpaper wlsunset
)

failed=()
for pkg in "${VISUAL_PKGS[@]}"; do
    yay -S --needed --noconfirm "$pkg" 2>/dev/null || failed+=("$pkg")
done
[[ ${#failed[@]} -gt 0 ]] && warn "Omitidos (no encontrados): ${failed[*]}"
ok "Paquetes visuales instalados"

# ── 2. AMBxst ────────────────────────────────────────────────────────────────

step "2/4 — AMBxst (entorno visual Hyprland)"
if command -v ambxst &>/dev/null; then
    ok "AMBxst ya instalado"
else
    bash <(curl -sL https://raw.githubusercontent.com/Axenide/Ambxst/main/install.sh)
    ok "AMBxst instalado"
fi

# ── 3. Dotfiles visuales ─────────────────────────────────────────────────────

step "3/4 — Configuraciones visuales"
mkdir -p ~/.config

cp -r "$REPO_DIR/.config/kitty"    ~/.config/ && ok "  kitty"
cp -r "$REPO_DIR/.config/cava"     ~/.config/ && ok "  cava"
cp -r "$REPO_DIR/.config/btop"     ~/.config/ && ok "  btop"
cp -r "$REPO_DIR/.config/fastfetch" ~/.config/ && ok "  fastfetch"
cp "$REPO_DIR/.config/starship.toml" ~/.config/starship.toml && ok "  starship.toml"

# ── 4. Integración con Hyprland ──────────────────────────────────────────────

step "4/4 — Hyprland: activar configuración visual AMBxst"
HYPR_CONF="$HOME/.config/hypr/hyprland.conf"
HYPR_LUA="$HOME/.config/hypr/hyprland.lua"

if [[ -f "$HYPR_CONF" ]]; then
    if ! grep -q "ambxst/hyprland" "$HYPR_CONF"; then
        echo '' >> "$HYPR_CONF"
        echo '# AMBxst — decoraciones, animaciones, keybinds y autostart' >> "$HYPR_CONF"
        echo 'source = ~/.local/share/ambxst/hyprland.conf' >> "$HYPR_CONF"
        ok "  source AMBxst agregado a hyprland.conf"
    else
        ok "  source AMBxst ya presente en hyprland.conf"
    fi
elif [[ -f "$HYPR_LUA" ]]; then
    # ponytail: asume la API `hyprland.source()` de hyprlang Lua; ajustar si cambia la API
    if ! grep -q "ambxst/hyprland" "$HYPR_LUA"; then
        echo '' >> "$HYPR_LUA"
        echo '-- AMBxst — decoraciones, animaciones, keybinds y autostart' >> "$HYPR_LUA"
        echo 'hyprland.source("~/.local/share/ambxst/hyprland.conf")' >> "$HYPR_LUA"
        ok "  source AMBxst agregado a hyprland.lua"
    else
        ok "  source AMBxst ya presente en hyprland.lua"
    fi
else
    warn "  No se encontró hyprland.conf ni hyprland.lua en ~/.config/hypr/"
    warn "  Agrega manualmente al final de tu config:"
    warn "    .conf:  source = ~/.local/share/ambxst/hyprland.conf"
    warn "    .lua:   hyprland.source(\"~/.local/share/ambxst/hyprland.conf\")"
fi

# ── Fin ───────────────────────────────────────────────────────────────────────

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${GREEN}  Configuración visual completa.${RESET}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""
echo "• Reinicia Hyprland (SUPER+R) para aplicar el entorno AMBxst"
echo "• Inicia cava con: cava  (o con la keybind SUPER+N)"
echo "• Fuentes activas al cerrar y volver a iniciar sesión"
