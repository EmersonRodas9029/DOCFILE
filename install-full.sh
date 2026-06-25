#!/bin/bash
# install-full.sh — sistema completo desde cero (usuario, paquetes, entorno)
# Como root: crea usuario y sale → luego ejecutar como ese usuario
# Como usuario: instala todo

set -e
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; RESET='\033[0m'
step() { echo -e "\n${CYAN}▶ $*${RESET}"; }
ok()   { echo -e "${GREEN}✓ $*${RESET}"; }
warn() { echo -e "${YELLOW}⚠ $*${RESET}"; }
die()  { echo -e "${RED}✗ $*${RESET}"; exit 1; }

command -v pacman &>/dev/null || die "Este script es solo para Arch Linux."

# ── 0. Crear usuario (solo si se ejecuta como root) ──────────────────────────

if [[ $EUID -eq 0 ]]; then
    step "0 — Crear usuario"
    read -rp "Nombre de usuario: " NEW_USER
    [[ -z "$NEW_USER" ]] && die "Nombre de usuario vacío."

    if id "$NEW_USER" &>/dev/null; then
        ok "Usuario '$NEW_USER' ya existe"
    else
        useradd -m -G wheel -s /bin/bash "$NEW_USER"
        ok "Usuario '$NEW_USER' creado"
    fi

    echo "Establece la contraseña para $NEW_USER:"
    passwd "$NEW_USER"

    # Habilitar sudo para grupo wheel
    if grep -q "^# %wheel ALL=(ALL:ALL) ALL" /etc/sudoers; then
        sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
        ok "sudo habilitado para grupo wheel"
    else
        ok "sudo para wheel ya estaba activo"
    fi

    echo ""
    echo -e "${GREEN}Usuario listo. Inicia sesión como '${NEW_USER}' y ejecuta:${RESET}"
    echo "  bash $(realpath "$0")"
    exit 0
fi

# ── A partir de aquí: usuario normal con sudo ─────────────────────────────────

step "Verificando sudo..."
sudo -v || die "No se pudo obtener permisos sudo."
while true; do sudo -n true; sleep 60; done 2>/dev/null &
SUDO_KEEPER=$!
trap "kill $SUDO_KEEPER 2>/dev/null" EXIT

# ── Detección de hardware ─────────────────────────────────────────────────────

step "Hardware — detección automática"
HAS_NVIDIA=false; HAS_INTEL_GPU=false; HAS_AMD_GPU=false
HAS_INTEL_CPU=false; HAS_AMD_CPU=false; HAS_BLUETOOTH=false

for path in /sys/bus/pci/devices/*/; do
    vendor=$(cat "$path/vendor" 2>/dev/null) || continue
    class=$(cat  "$path/class"  2>/dev/null) || continue
    [[ "$class" == 0x0300* || "$class" == 0x0302* ]] || continue
    case "$vendor" in
        0x10de) HAS_NVIDIA=true    ;;
        0x8086) HAS_INTEL_GPU=true ;;
        0x1002) HAS_AMD_GPU=true   ;;
    esac
done

grep -qi "intel" /proc/cpuinfo && HAS_INTEL_CPU=true
grep -qi "amd"   /proc/cpuinfo && HAS_AMD_CPU=true
ls /sys/class/bluetooth/ 2>/dev/null | grep -q "." && HAS_BLUETOOTH=true

$HAS_NVIDIA     && ok "  GPU NVIDIA"      || true
$HAS_INTEL_GPU  && ok "  GPU Intel"       || true
$HAS_AMD_GPU    && ok "  GPU AMD"         || true
$HAS_INTEL_CPU  && ok "  CPU Intel"       || true
$HAS_AMD_CPU    && ok "  CPU AMD"         || true
$HAS_BLUETOOTH  && ok "  Bluetooth"       || true

# ── 1. yay ───────────────────────────────────────────────────────────────────

step "1/10 — yay (AUR helper)"
if ! command -v yay &>/dev/null; then
    sudo pacman -S --needed --noconfirm git base-devel
    tmp=$(mktemp -d)
    git clone https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin"
    (cd "$tmp/yay-bin" && makepkg -si --noconfirm)
    rm -rf "$tmp"
    ok "yay instalado"
else
    ok "yay ya instalado"
fi

# ── 2. Paquetes ──────────────────────────────────────────────────────────────

step "2/10 — Paquetes (pacman + AUR)"
echo "Esto puede tardar varios minutos..."

install_pkg_list() {
    mapfile -t pkgs < <(grep -v '^\s*$' "$1" | grep -v '\-debug$')
    local failed=()
    for pkg in "${pkgs[@]}"; do
        yay -S --needed --noconfirm "$pkg" 2>/dev/null || failed+=("$pkg")
    done
    [[ ${#failed[@]} -gt 0 ]] && warn "Omitidos (no encontrados): ${failed[*]}"
}

install_pkg_list "$REPO_DIR/packages/pkgs.txt"
install_pkg_list "$REPO_DIR/packages/aur.txt"
yay -S --needed --noconfirm ttf-iosevka-nerd 2>/dev/null || warn "ttf-iosevka-nerd no disponible"

# Paquetes específicos del hardware detectado
HW_PKGS=()
$HAS_NVIDIA    && HW_PKGS+=(nvidia-open-dkms nvidia-prime)
$HAS_INTEL_GPU && HW_PKGS+=(intel-media-driver libva-intel-driver vulkan-intel)
$HAS_AMD_GPU   && HW_PKGS+=(vulkan-radeon xf86-video-amdgpu xf86-video-ati)
$HAS_INTEL_CPU && HW_PKGS+=(intel-ucode)
$HAS_AMD_CPU   && HW_PKGS+=(amd-ucode)
$HAS_BLUETOOTH && HW_PKGS+=(bluez bluez-utils blueman)
if [[ ${#HW_PKGS[@]} -gt 0 ]]; then
    for pkg in "${HW_PKGS[@]}"; do
        yay -S --needed --noconfirm "$pkg" 2>/dev/null && ok "  $pkg" || warn "  $pkg omitido"
    done
fi

ok "Paquetes instalados"

# ── 3. AMBxst ────────────────────────────────────────────────────────────────

step "3/10 — AMBxst (entorno gráfico)"
if command -v ambxst &>/dev/null; then
    ok "AMBxst ya instalado"
else
    bash <(curl -sL https://raw.githubusercontent.com/Axenide/Ambxst/main/install.sh) || { warn "AMBxst falló — instala manualmente luego"; }
    ok "AMBxst instalado"
fi

# ── 4. Dotfiles ──────────────────────────────────────────────────────────────

step "4/10 — Dotfiles"
mkdir -p ~/.config ~/.local/bin

for cfg in kitty cava fastfetch btop fish; do
    cp -r "$REPO_DIR/.config/$cfg" ~/.config/
    ok "  .config/$cfg"
done

# hypr: copiar todo excepto hyprland.conf si el usuario ya tiene hyprland.lua
mkdir -p ~/.config/hypr
cp "$REPO_DIR/.config/hypr/autostart.sh" ~/.config/hypr/
HYPR_LUA="$HOME/.config/hypr/hyprland.lua"
if [[ -f "$HYPR_LUA" ]]; then
    warn "  hyprland.lua detectado — omitiendo hyprland.conf del repo para no sobreescribir"
    warn "  Agrega manualmente al final de $HYPR_LUA:"
    warn "    hyprland.source(\"~/.local/share/ambxst/hyprland.conf\")"
    warn "  Y copia las keybinds de $REPO_DIR/.config/hypr/hyprland.conf que necesites"
else
    cp "$REPO_DIR/.config/hypr/hyprland.conf" ~/.config/hypr/
    ok "  .config/hypr"
fi

cp "$REPO_DIR/.config/starship.toml" ~/.config/starship.toml
ok "  starship.toml"

cp "$REPO_DIR/.local/bin/"* ~/.local/bin/
chmod +x ~/.local/bin/*
ok "  .local/bin/"

if [[ ! -f ~/.local/bin/xwayland-start ]]; then
    printf '#!/bin/bash\nxhost +SI:localuser:$(whoami) 2>/dev/null\n' > ~/.local/bin/xwayland-start
    chmod +x ~/.local/bin/xwayland-start
    ok "  xwayland-start creado"
fi

# ── 5. NVIDIA ─────────────────────────────────────────────────────────────────

step "5/10 — NVIDIA"
if ! $HAS_NVIDIA; then
    ok "  Sin GPU NVIDIA — omitiendo"
else
    sudo cp "$REPO_DIR/system/modprobe.d/audio-nvidia.conf" /etc/modprobe.d/audio-nvidia.conf
    ok "  audio-nvidia.conf"

    MKINIT=/etc/mkinitcpio.conf
    if ! grep -q "nvidia_drm" "$MKINIT"; then
        sudo sed -i 's/^MODULES=(\(.*\))/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' "$MKINIT"
        ok "  mkinitcpio — módulos NVIDIA agregados"
    else
        ok "  mkinitcpio — módulos NVIDIA ya presentes"
    fi
    sudo mkinitcpio -P || warn "  mkinitcpio terminó con errores — revisar manualmente"
    ok "  initramfs regenerado"

    if [[ -f /etc/default/grub ]]; then
        if ! grep -q "nvidia_drm.modeset=1" /etc/default/grub; then
            sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 nvidia_drm.modeset=1"/' /etc/default/grub
            sudo grub-mkconfig -o /boot/grub/grub.cfg || warn "  grub-mkconfig falló — regenerar manualmente: sudo grub-mkconfig -o /boot/grub/grub.cfg"
            ok "  GRUB — nvidia_drm.modeset=1 agregado"
        else
            ok "  GRUB — nvidia_drm.modeset=1 ya presente"
        fi
    else
        warn "  GRUB no detectado — agrega 'nvidia_drm.modeset=1' manualmente a tus kernel params"
    fi
fi

# ── 6. zram ──────────────────────────────────────────────────────────────────

step "6/10 — zram (swap en RAM)"
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

# ── 7. Servicios systemd ─────────────────────────────────────────────────────

step "7/10 — Servicios"
SYSTEM_SVCS=(NetworkManager sddm power-profiles-daemon)
$HAS_BLUETOOTH && SYSTEM_SVCS+=(bluetooth)
for svc in "${SYSTEM_SVCS[@]}"; do
    sudo systemctl enable --now "$svc" 2>/dev/null && ok "  $svc" || warn "  $svc — no disponible"
done
for svc in pipewire pipewire-pulse wireplumber; do
    systemctl --user enable --now "$svc" 2>/dev/null && ok "  $svc (usuario)" || warn "  $svc — no disponible"
done

# ── 8. Shell (fish) ──────────────────────────────────────────────────────────

step "8/10 — Shell"
if [[ "$(getent passwd "$USER" | cut -d: -f7)" != */fish ]]; then
    chsh -s /usr/bin/fish && ok "  Shell cambiado a fish" || warn "  Hazlo manualmente: chsh -s /usr/bin/fish"
else
    ok "  fish ya es el shell"
fi

# ── 9. SDDM ──────────────────────────────────────────────────────────────────

step "9/10 — SDDM"
if [[ ! -f /etc/sddm.conf.d/10-hyprland.conf ]]; then
    sudo mkdir -p /etc/sddm.conf.d
    sudo tee /etc/sddm.conf.d/10-hyprland.conf > /dev/null << EOF
[Autologin]
# Descomentar para autologin:
# User=$USER
# Session=hyprland

[Theme]
Current=
EOF
    ok "  sddm configurado"
else
    ok "  sddm ya configurado"
fi

# ── 10. Fin ───────────────────────────────────────────────────────────────────

step "10/10 — Listo"
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${GREEN}  Instalación completa.${RESET}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""
warn "Sin NVIDIA: edita hyprland.conf y elimina las líneas con DISPLAY=:1 y prime-run"
echo ""
read -rp "¿Reiniciar ahora? [s/N] " resp
[[ "$resp" =~ ^[sS]$ ]] && sudo reboot || echo "Reinicia con: sudo reboot"
