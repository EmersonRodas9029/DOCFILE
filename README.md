# DOCFILE — Setup Visual

Instalador del entorno visual para Arch Linux + Hyprland.

## Requisitos

- Arch Linux
- Hyprland instalado
- Usuario con sudo (no ejecutar como root)

## Instalación

```bash
git clone <este-repo>
cd DOCFILE
./setup.sh
```

El script hace todo automáticamente:

1. Detecta si usas `hyprland.conf` o `hyprland.lua`
2. Instala **AMBxst** y lo integra con Hyprland
3. Instala herramientas visuales: `kitty`, `cava`, `btop`, `fastfetch`, `starship`
4. Instala fuentes: Nerd Fonts, Phosphor, League Gothic, Roboto, Noto
5. Copia los dotfiles (hace backup de los existentes)
6. Activa Starship en tu shell (`.bashrc` / `.zshrc`)
7. Pregunta si recargar Hyprland al terminar

## Apps incluidas

| App | Descripción |
|-----|-------------|
| **AMBxst** | Shell visual para Hyprland (barra, widgets, animaciones) |
| **Kitty** | Terminal GPU-accelerated |
| **Cava** | Visualizador de audio en terminal |
| **Btop** | Monitor del sistema |
| **Fastfetch** | Info del sistema al abrir terminal |
| **Starship** | Prompt minimalista y rápido |

## Solo AMBxst

Si solo quieres instalar AMBxst:

```bash
./install-aesthetic.sh
```

## Backup

Antes de copiar dotfiles, el script guarda los existentes en:
```
~/.config-backup-YYYYMMDD-HHMMSS/
```
