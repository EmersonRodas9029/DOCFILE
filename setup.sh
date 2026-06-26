#!/bin/bash
# setup.sh — instalación completa: AMBxst + herramientas visuales + dotfiles

set -eE
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

CURRENT_STEP="inicialización"

tprint() {
    local text="$1" color="${2:-$RESET}"
    echo -en "$color"
    for ((i=0; i<${#text}; i++)); do
        echo -n "${text:$i:1}"
        sleep 0.03
    done
    echo -e "$RESET"
}

progress() {
    local current=$1 total=5 width=32 bar="" filled empty
    filled=$(( current * width / total ))
    empty=$(( width - filled ))
    for ((i=0; i<filled; i++)); do bar+="█"; done
    for ((i=0; i<empty; i++)); do bar+="░"; done
    echo -e "${CYAN}  [${bar}] ${current}/${total}${RESET}"
}

error_handler() {
    local line=$1 cmd=$2
    echo ""
    tprint "  ╔══════════════════════════════════════════╗" "$RED"
    tprint "  ║        ERROR — Instalación cancelada     ║" "$RED"
    tprint "  ╚══════════════════════════════════════════╝" "$RED"
    echo ""
    tprint "  Paso:    $CURRENT_STEP" "$RED"
    tprint "  Línea:   $line" "$RED"
    tprint "  Comando: $cmd" "$RED"
    echo ""
    tprint "  Corrige el error y vuelve a ejecutar ./setup.sh" "$YELLOW"
    echo ""
    exit 1
}

trap 'error_handler $LINENO "$BASH_COMMAND"' ERR

step() { local n=$1; shift; CURRENT_STEP="$*"; echo ""; progress "$n"; tprint "▶ $*" "$CYAN$BOLD"; }
ok()   { tprint "  ✓ $*" "$GREEN"; }
warn() { tprint "  ⚠ $*" "$YELLOW"; }
die()  { CURRENT_STEP="${CURRENT_STEP:-inicio}"; error_handler "${BASH_LINENO[0]}" "$*"; }

[[ $EUID -eq 0 ]] && die "No ejecutes como root."
command -v pacman &>/dev/null || die "Este script es solo para Arch Linux."

# ── Bienvenida ────────────────────────────────────────────────────────────────

clear
echo ""
tprint "  ╔══════════════════════════════════════════╗" "$CYAN"
tprint "  ║       DOCFILE — Setup Visual             ║" "$CYAN"
tprint "  ║  AMBxst · Fuentes · Dotfiles · Starship  ║" "$CYAN"
tprint "  ╚══════════════════════════════════════════╝" "$CYAN"
echo ""
sleep 0.5

# ── 0. Detectar config de Hyprland ───────────────────────────────────────────

step 0 "Detectando configuración de Hyprland"
HYPR_CONF="$HOME/.config/hypr/hyprland.conf"
HYPR_LUA="$HOME/.config/hypr/hyprland.lua"

if [[ -f "$HYPR_CONF" ]]; then
    HYPR_FORMAT="conf"
    HYPR_FILE="$HYPR_CONF"
    ok "Encontrado: hyprland.conf"
elif [[ -f "$HYPR_LUA" ]]; then
    HYPR_FORMAT="lua"
    HYPR_FILE="$HYPR_LUA"
    ok "Encontrado: hyprland.lua"
else
    die "No se encontró hyprland.conf ni hyprland.lua — ¿Hyprland está instalado?"
fi

# ── 1. AMBxst ────────────────────────────────────────────────────────────────

step 1 "AMBxst"
if command -v ambxst &>/dev/null; then
    ok "AMBxst ya instalado"
else
    tprint "  Descargando AMBxst..." "$CYAN"
    curl -L get.axeni.de/ambxst | sh
    ok "AMBxst instalado"
fi

ambxst install hyprland
ok "AMBxst integrado con Hyprland (formato: $HYPR_FORMAT)"

# ── 2. Herramientas y fuentes ─────────────────────────────────────────────────

step 2 "Herramientas visuales y fuentes"

if ! command -v yay &>/dev/null; then
    tprint "  Instalando yay..." "$CYAN"
    sudo pacman -S --needed --noconfirm git base-devel fakeroot debugedit
    tmp=$(mktemp -d)
    git clone https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin"
    (cd "$tmp/yay-bin" && makepkg -si --noconfirm)
    rm -rf "$tmp"
    ok "yay instalado"
fi

for pkg in kitty cava btop fastfetch starship; do
    if command -v "$pkg" &>/dev/null; then
        ok "$pkg ya instalado"
    else
        tprint "  Instalando $pkg..." "$CYAN"
        yay -S --needed --noconfirm "$pkg" && ok "$pkg instalado" || warn "$pkg: falló la instalación"
    fi
done

tprint "  Instalando fuentes..." "$CYAN"
sudo pacman -S --needed --noconfirm \
    ttf-nerd-fonts-symbols ttf-nerd-fonts-symbols-common \
    ttf-phosphor-icons ttf-league-gothic \
    ttf-roboto ttf-roboto-mono \
    noto-fonts noto-fonts-cjk noto-fonts-emoji \
    ttf-dejavu ttf-liberation \
    && ok "Fuentes instaladas" || warn "Algunas fuentes fallaron"

# ── 3. Dotfiles ───────────────────────────────────────────────────────────────

step 3 "Dotfiles"

# Backup de configs existentes
BACKUP_DIR="$HOME/.config-backup-$(date +%Y%m%d-%H%M%S)"
BACKED_UP=()
for cfg in kitty cava btop fastfetch; do
    [[ -d "$HOME/.config/$cfg" ]] && BACKED_UP+=("$cfg")
done
[[ -f "$HOME/.config/starship.toml" ]] && BACKED_UP+=("starship.toml")

if [[ ${#BACKED_UP[@]} -gt 0 ]]; then
    mkdir -p "$BACKUP_DIR"
    for cfg in kitty cava btop fastfetch; do
        [[ -d "$HOME/.config/$cfg" ]] && cp -r "$HOME/.config/$cfg" "$BACKUP_DIR/"
    done
    [[ -f "$HOME/.config/starship.toml" ]] && cp "$HOME/.config/starship.toml" "$BACKUP_DIR/"
    ok "Backup guardado en: $BACKUP_DIR"
fi

mkdir -p ~/.config
for cfg in kitty cava btop fastfetch; do
    cp -r "$REPO_DIR/.config/$cfg" ~/.config/ && ok "$cfg" || warn "$cfg: error al copiar"
done
cp "$REPO_DIR/.config/starship.toml" ~/.config/starship.toml && ok "starship.toml" || warn "starship.toml: error al copiar"

# ── 4. Integración de shell ───────────────────────────────────────────────────

step 3 "Integración de shell (Starship)"

SHELL_RC=""
if [[ "$SHELL" == */zsh ]]; then
    SHELL_RC="$HOME/.zshrc"
elif [[ "$SHELL" == */bash ]]; then
    SHELL_RC="$HOME/.bashrc"
fi

if [[ -n "$SHELL_RC" ]]; then
    if grep -q "starship init" "$SHELL_RC" 2>/dev/null; then
        ok "Starship ya está en $SHELL_RC"
    else
        echo '' >> "$SHELL_RC"
        echo 'eval "$(starship init '"${SHELL##*/}"')"' >> "$SHELL_RC"
        ok "Starship agregado a $SHELL_RC"
    fi
else
    warn "Shell no reconocido — agrega manualmente: eval \"\$(starship init <shell>)\""
fi

# ── 4. Autostart ─────────────────────────────────────────────────────────────

step 4 "Autostart al iniciar sesión"

if [[ "$HYPR_FORMAT" == "conf" ]]; then
    if ! grep -q "exec-once.*ambxst" "$HYPR_FILE"; then
        echo '' >> "$HYPR_FILE"
        echo '# Autostart AMBxst' >> "$HYPR_FILE"
        echo 'exec-once = ambxst' >> "$HYPR_FILE"
        ok "exec-once = ambxst agregado a hyprland.conf"
    else
        ok "Autostart de AMBxst ya configurado"
    fi
elif [[ "$HYPR_FORMAT" == "lua" ]]; then
    if ! grep -q "exec_once.*ambxst" "$HYPR_FILE"; then
        echo '' >> "$HYPR_FILE"
        echo '-- Autostart AMBxst' >> "$HYPR_FILE"
        echo 'hyprland.exec_once("ambxst")' >> "$HYPR_FILE"
        ok "exec_once ambxst agregado a hyprland.lua"
    else
        ok "Autostart de AMBxst ya configurado"
    fi
fi

# ── Fin ───────────────────────────────────────────────────────────────────────

echo ""
sleep 0.3
tprint "  ╔══════════════════════════════════════════╗" "$GREEN"
tprint "  ║   Instalación completada con éxito.      ║" "$GREEN"
tprint "  ║   Ejecuta 'ambxst' para iniciar.         ║" "$GREEN"
tprint "  ╚══════════════════════════════════════════╝" "$GREEN"
echo ""

# Prompt de reinicio
echo -en "${CYAN}  ¿Recargar Hyprland ahora? [s/N]: ${RESET}"
read -r respuesta
if [[ "$respuesta" =~ ^[sS]$ ]]; then
    hyprctl reload && tprint "  Hyprland recargado." "$GREEN"
else
    tprint "  Reinicia Hyprland manualmente con: hyprctl reload" "$YELLOW"
fi
echo ""
