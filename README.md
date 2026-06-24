# DOCFILE — Arch Linux + Hyprland dotfiles

Guía completa para clonar este sistema a otra PC.

## Hardware de referencia

- CPU: Intel (con iGPU Intel)
- GPU: NVIDIA (configuración PRIME — iGPU para display, dGPU para render)
- Audio: Intel HDA / ALC245
- Display server: Wayland (Hyprland) + XWayland para apps legacy

---

## 1. Instalación base de Arch

Seguir la guía oficial: https://wiki.archlinux.org/title/Installation_guide

Particionado recomendado (UEFI + BTRFS):
```
/boot/efi   → EFI partition (512 MB)
/           → BTRFS (resto)
swap        → zram (se configura después, no crear partición swap)
```

Paquetes base mínimos durante `pacstrap`:
```bash
pacstrap /mnt base base-devel linux linux-headers linux-firmware nano sudo networkmanager
```

---

## 2. Configuración post-instalación base

```bash
# Habilitar NetworkManager
systemctl enable NetworkManager

# Crear usuario
useradd -m -G wheel emerson
passwd emerson
# Descomentar %wheel ALL=(ALL:ALL) ALL en visudo
```

---

## 3. Instalar yay (AUR helper)

```bash
pacman -S --needed git base-devel
cd /tmp && git clone https://aur.archlinux.org/yay-bin.git
cd yay-bin && makepkg -si
```

---

## 4. Instalar todos los paquetes

### Paquetes oficiales
```bash
xargs -a packages/pkgs.txt yay -S --needed --noconfirm
```

### Paquetes AUR
```bash
xargs -a packages/aur.txt yay -S --needed --noconfirm
```

> **Nota:** `minecraft-launcher` es de AUR (`minecraft-launcher-debug` en la lista — instala `minecraft-launcher` normal si no quieres debug builds).

---

## 5. NVIDIA — configuración crítica

### 5.1 mkinitcpio — módulos NVIDIA en initramfs

Editar `/etc/mkinitcpio.conf`:
```
MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)
HOOKS=(base udev autodetect microcode modconf keyboard keymap consolefont block filesystems fsck)
```

Regenerar initramfs:
```bash
sudo mkinitcpio -P
```

### 5.2 Parámetros del kernel (GRUB/systemd-boot)

Agregar a los kernel params:
```
nvidia_drm.modeset=1
```

Con GRUB editar `/etc/default/grub`:
```
GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet nvidia_drm.modeset=1"
```
```bash
sudo grub-mkconfig -o /boot/grub/grub.cfg
```

### 5.3 modprobe — opciones de audio y NVIDIA

```bash
sudo cp system/modprobe.d/audio-nvidia.conf /etc/modprobe.d/audio-nvidia.conf
sudo mkinitcpio -P
```

Contenido:
```
options snd-intel-dspcfg dsp_driver=1
options snd_hda_intel dmic_detect=0
options snd_hda_intel model=alc245-fixup   # ajustar según tu modelo de audio
options nvidia_drm modeset=1
options nvidia NVreg_DynamicPowerManagement=0x02
```

> **Ajustar:** `alc245-fixup` es específico de este hardware. Si el audio no funciona, ejecutar `aplay -l` y consultar https://wiki.archlinux.org/title/Advanced_Linux_Sound_Architecture

---

## 6. SDDM (login manager)

```bash
sudo systemctl enable sddm
```

Tema opcional (adw-gtk o cualquier sddm theme):
```bash
sudo mkdir -p /etc/sddm.conf.d
sudo nano /etc/sddm.conf.d/10-theme.conf
```
```ini
[Theme]
Current=
```

---

## 7. Copiar dotfiles

Desde el directorio raíz del repo:

```bash
# Configs
cp -r .config/hypr ~/.config/
cp -r .config/kitty ~/.config/
cp -r .config/cava ~/.config/
cp -r .config/fastfetch ~/.config/
cp -r .config/btop ~/.config/
cp -r .config/fish ~/.config/
cp .config/starship.toml ~/.config/

# Scripts personalizados
cp .local/bin/* ~/.local/bin/
chmod +x ~/.local/bin/*
```

---

## 8. Fuentes requeridas

Ya instaladas por la lista de paquetes, pero verificar:
- `ttf-nerd-fonts-symbols` → iconos en starship/btop/fastfetch
- `ttf-roboto` + `ttf-roboto-mono` → UI general
- `ttf-league-gothic` → decoración
- `ttf-dejavu` + `ttf-liberation` → fallback
- **Iosevka Nerd Font** → usada en kitty. Instalar separado:
  ```bash
  yay -S ttf-iosevka-nerd
  ```

---

## 9. Servicios systemd (usuario)

```bash
systemctl --user enable wireplumber
systemctl --user enable pipewire
systemctl --user enable pipewire-pulse
```

Para audio con pipewire completo:
```bash
systemctl --user start pipewire pipewire-pulse wireplumber
```

---

## 10. Scripts personalizados — descripción

| Script | Función |
|--------|---------|
| `docker-desktop-launcher` | Inicia servicio systemd de docker-desktop y lanza la GUI en `DISPLAY=:1` |
| `postman-nvidia` | Lanza Postman con NVIDIA PRIME offload en XWayland |
| `prism` | Lanza PrismLauncher (Minecraft) con PRIME offload en XWayland |
| `minecraft-fix` | Mata procesos colgados y relanza minecraft-launcher en XWayland |
| `cava-floating` | Mata cava si corre, aplica windowrule float y lo abre en kitty |

### xwayland-start (crear manualmente)

El hyprland.conf referencia `~/.local/bin/xwayland-start`. Crear con:
```bash
cat > ~/.local/bin/xwayland-start << 'EOF'
#!/bin/bash
# Configurar permisos XWayland para apps locales
xhost +SI:localuser:$(whoami) 2>/dev/null
EOF
chmod +x ~/.local/bin/xwayland-start
```

---

## 11. AMBxst (RGB controller)

El sistema usa `ambxst` para control de iluminación RGB. Se instala desde:
- `/usr/local/bin/ambxst` (binario)
- `~/.local/share/ambxst/` (config + hyprland binds)

El `autostart.sh` de hyprland lo inicia con `sleep 2` para dar tiempo al sistema.
Si no usas AMBxst, comentar en `hyprland.conf`:
```
# source = ~/.local/share/ambxst/hyprland.conf
```
Y en `autostart.sh`:
```
# /usr/local/bin/ambxst &
```

---

## 12. Teclado

El layout configurado es `us` con variante `altgr-intl` (permite acentos con AltGr).
Si usas layout diferente, editar en `hyprland.conf`:
```
input {
    kb_layout = us
    kb_variant = altgr-intl
}
```

---

## 13. zram (swap en RAM)

```bash
sudo nano /etc/systemd/zram-generator.conf
```
```ini
[zram0]
zram-size = ram / 2
compression-algorithm = zstd
```
```bash
sudo systemctl daemon-reload
sudo systemctl start systemd-zram-setup@zram0
```

---

## 14. UWSM (session manager para Hyprland)

`uwsm` está instalado para gestionar la sesión de Hyprland como servicio systemd.
Configurar SDDM para lanzar con uwsm, o iniciar manualmente:
```bash
uwsm start hyprland
```

---

## 15. Fastfetch — imagen personalizada

El fastfetch usa `~/.config/fastfetch/pngs/bocchi.png` como logo.
El archivo está incluido en el repo. Requiere kitty con protocolo de imágenes activo (ya configurado).

---

## 16. Btop — tema personalizado

El tema `kitty_jakoolit` está incluido en `.config/btop/themes/`.
Se basa en los colores exactos de kitty-colors.conf.

---

## 17. Verificación final

```bash
# Verificar que hyprland arranca
uwsm start hyprland
# o desde tty: Hyprland

# Verificar audio
pactl info | grep "Server Name"

# Verificar NVIDIA
nvidia-smi
prime-run glxinfo | grep "OpenGL renderer"

# Verificar XWayland
DISPLAY=:1 xeyes  # debe abrir una ventana
```

---

## Keybinds principales

| Tecla | Acción |
|-------|--------|
| `SUPER + Q` | Terminal (kitty) |
| `SUPER + K` | Cerrar ventana |
| `SUPER + R` | Salir de Hyprland |
| `SUPER + E` | Dolphin (archivos) |
| `SUPER + F` | Toggle flotante |
| `SUPER + B` | Brave browser |
| `SUPER + D` | Discord (XWayland) |
| `SUPER + V` | VS Code |
| `SUPER + S` | Steam (PRIME + XWayland) |
| `SUPER + N` | Cava (flotante) |
| `SUPER + A` | AnyDesk (XWayland) |
| `SUPER + P` | Postman |
| `SUPER + W` | MySQL Workbench (XWayland) |
| `SUPER + C` | Docker Desktop |
| `SUPER + O` | OnlyOffice (XWayland) |
| `SUPER + M` | PrismLauncher (Minecraft) |
| `ALT + T` | OCR (OCR4Linux) spa+eng |
| `SUPER + CTRL + flechas` | Redimensionar ventana flotante (20px) |
| `SUPER + CTRL + drag` | Redimensionar con mouse |
| `SUPER + drag` | Mover ventana flotante |
