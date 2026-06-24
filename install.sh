#!/bin/bash
# install.sh — instala y configura el sistema completo desde cero
# Uso: bash install.sh
# Ejecutar como usuario normal (pide sudo cuando lo necesita)

set -e

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RESET='\033[0m'

step()  { echo -e "\n${CYAN}▶ $*${RESET}"; }
ok()    { echo -e "${GREEN}✓ $*${RESET}"; }
warn()  { echo -e "${YELLOW}⚠ $*${RESET}"; }
die()   { echo -e "${RED}✗ $*${RESET}"; exit 1; }

# ── Verificaciones iniciales ──────────────────────────────────────────────────

[[ $EUID -eq 0 ]] && die "No ejecutes este script como root. Usa tu usuario normal."
command -v pacman &>/dev/null || die "Este script es solo para Arch Linux."

step "Verificando sudo..."
sudo -v || die "No se pudo obtener permisos sudo."
# Mantener sudo activo en background
while true; do sudo -n true; sleep 60; done 2>/dev/null &
SUDO_KEEPER=$!
trap "kill $SUDO_KEEPER 2>/dev/null" EXIT

# ── 1. yay ────────────────────────────────────────────────────────────────────

step "1/9 — yay (AUR helper)"
if ! command -v yay &>/dev/null; then
    sudo pacman -S --needed --noconfirm git base-devel
    tmp=$(mktemp -d)
    git clone https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin"
    (cd "$tmp/yay-bin" && makepkg -si --noconfirm)
    rm -rf "$tmp"
    ok "yay instalado"
else
    ok "yay ya está instalado"
fi

# ── 2. Paquetes ───────────────────────────────────────────────────────────────

step "2/9 — Instalando paquetes (pacman + AUR)"
echo "Esto puede tardar varios minutos..."

install_pkg_list() {
    local file="$1"
    # Filtra líneas vacías y paquetes -debug (son símbolos de debug, no instalan solos)
    mapfile -t pkgs < <(grep -v '^\s*$' "$file" | grep -v '\-debug$')
    local failed=()
    for pkg in "${pkgs[@]}"; do
        yay -S --needed --noconfirm "$pkg" 2>/dev/null || failed+=("$pkg")
    done
    if [[ ${#failed[@]} -gt 0 ]]; then
        warn "No encontrados (omitidos): ${failed[*]}"
    fi
}

install_pkg_list "$REPO_DIR/packages/pkgs.txt"
install_pkg_list "$REPO_DIR/packages/aur.txt"

# Fuente Iosevka (usada en kitty, no está en la lista base)
yay -S --needed --noconfirm ttf-iosevka-nerd 2>/dev/null || warn "ttf-iosevka-nerd no disponible, instalar manualmente si kitty muestra caracteres rotos"

ok "Paquetes instalados"

# ── 3. Dotfiles ───────────────────────────────────────────────────────────────

step "3/9 — Copiando dotfiles"

mkdir -p ~/.config ~/.local/bin

configs=(hypr kitty cava fastfetch btop fish)
for cfg in "${configs[@]}"; do
    cp -r "$REPO_DIR/.config/$cfg" ~/.config/
    ok "  .config/$cfg"
done

cp "$REPO_DIR/.config/starship.toml" ~/.config/starship.toml
ok "  .config/starship.toml"

cp "$REPO_DIR/.local/bin/"* ~/.local/bin/
chmod +x ~/.local/bin/*
ok "  .local/bin/ (scripts)"

# ── 4. Script xwayland-start (referenciado en hyprland.conf) ─────────────────

if [[ ! -f ~/.local/bin/xwayland-start ]]; then
    cat > ~/.local/bin/xwayland-start << 'EOF'
#!/bin/bash
xhost +SI:localuser:$(whoami) 2>/dev/null
EOF
    chmod +x ~/.local/bin/xwayland-start
    ok "  xwayland-start creado"
fi

# ── 5. Configuración NVIDIA ───────────────────────────────────────────────────

step "4/9 — Configuración NVIDIA (modprobe + mkinitcpio)"

# modprobe
sudo cp "$REPO_DIR/system/modprobe.d/audio-nvidia.conf" /etc/modprobe.d/audio-nvidia.conf
ok "  /etc/modprobe.d/audio-nvidia.conf"

# mkinitcpio — agregar módulos NVIDIA si no están
MKINIT=/etc/mkinitcpio.conf
if ! grep -q "nvidia_drm" "$MKINIT"; then
    sudo sed -i 's/^MODULES=(\(.*\))/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' "$MKINIT"
    ok "  mkinitcpio.conf — módulos NVIDIA agregados"
else
    ok "  mkinitcpio.conf — módulos NVIDIA ya presentes"
fi

sudo mkinitcpio -P
ok "  initramfs regenerado"

# Kernel params: nvidia_drm.modeset=1
if [[ -f /etc/default/grub ]]; then
    if ! grep -q "nvidia_drm.modeset=1" /etc/default/grub; then
        sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 nvidia_drm.modeset=1"/' /etc/default/grub
        sudo grub-mkconfig -o /boot/grub/grub.cfg
        ok "  GRUB actualizado con nvidia_drm.modeset=1"
    else
        ok "  GRUB — nvidia_drm.modeset=1 ya presente"
    fi
else
    warn "  No se detectó GRUB. Agregar 'nvidia_drm.modeset=1' a tus kernel params manualmente."
fi

# ── 6. zram ───────────────────────────────────────────────────────────────────

step "5/9 — zram (swap en RAM)"
ZRAM_CONF=/etc/systemd/zram-generator.conf
if [[ ! -f "$ZRAM_CONF" ]]; then
    sudo tee "$ZRAM_CONF" > /dev/null << 'EOF'
[zram0]
zram-size = ram / 2
compression-algorithm = zstd
EOF
    ok "  zram configurado"
else
    ok "  zram ya configurado"
fi

# ── 7. Servicios systemd ──────────────────────────────────────────────────────

step "6/9 — Habilitando servicios"

# Sistema
for svc in NetworkManager sddm bluetooth power-profiles-daemon; do
    if systemctl list-unit-files "$svc.service" &>/dev/null; then
        sudo systemctl enable --now "$svc" 2>/dev/null && ok "  $svc" || warn "  $svc — no disponible"
    fi
done

# Usuario
for svc in pipewire pipewire-pulse wireplumber; do
    systemctl --user enable --now "$svc" 2>/dev/null && ok "  $svc (usuario)" || warn "  $svc — no disponible"
done

# ── 8. Shell ──────────────────────────────────────────────────────────────────

step "7/9 — Shell"
CURRENT_SHELL=$(getent passwd "$USER" | cut -d: -f7)
if [[ "$CURRENT_SHELL" != */fish ]] && [[ "$CURRENT_SHELL" != */zsh ]]; then
    warn "Shell actual: $CURRENT_SHELL"
    warn "Para cambiar a fish: chsh -s /usr/bin/fish"
else
    ok "  Shell: $CURRENT_SHELL"
fi

# ── 9. SDDM ──────────────────────────────────────────────────────────────────

step "8/9 — SDDM"
if [[ ! -f /etc/sddm.conf.d/10-hyprland.conf ]]; then
    sudo mkdir -p /etc/sddm.conf.d
    sudo tee /etc/sddm.conf.d/10-hyprland.conf > /dev/null << 'EOF'
[Autologin]
# Descomentar para autologin:
# User=emerson
# Session=hyprland

[Theme]
Current=
EOF
    ok "  sddm config creado"
else
    ok "  sddm ya configurado"
fi

# ── Fin ───────────────────────────────────────────────────────────────────────

step "9/9 — Listo"
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${GREEN}  Instalación completa.${RESET}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""
echo "Próximos pasos:"
echo "  1. Reiniciar: sudo reboot"
echo "  2. SDDM iniciará automáticamente → seleccionar 'Hyprland'"
echo "  3. Si el audio no funciona, revisar README.md sección 5.3"
echo "  4. AMBxst (RGB): instalar manualmente si la otra PC lo tiene"
echo ""
warn "Si no tienes NVIDIA, edita hyprland.conf y elimina las líneas 'DISPLAY=:1' y 'prime-run'"
