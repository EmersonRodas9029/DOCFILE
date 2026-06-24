#!/bin/bash
sleep 2
/usr/local/bin/ambxst &

# Agregar regla para ventana flotante de cava
sleep 1
hyprctl keyword windowrule "float title:cava"
