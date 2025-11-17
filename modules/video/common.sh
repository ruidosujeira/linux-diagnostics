#!/usr/bin/env bash
# shellcheck shell=bash

sos_fix "set_display_resolution" <<'EOF'
description: Guia interativo para ajustar resolução com xrandr
exec: bash -c 'if ! command -v xrandr >/dev/null 2>&1; then \
  printf "xrandr não está disponível neste ambiente.\n"; exit 1; \
fi; printf "Use: xrandr --output <nome> --mode <resolução>\n"'
EOF

sos_fix "reinstall_gpu_stack" <<'EOF'
description: Sugere reinstalar drivers Mesa/NVIDIA
exec: printf '%s\n%s\n' \
  "Verifique drivers proprietários/mesa: consulte documentação da sua distro." \
  "Em sistemas debian-like: sudo ubuntu-drivers autoinstall (NVIDIA) ou sudo apt install --reinstall xserver-xorg-video-all mesa-vulkan-drivers"
EOF

sos_check "display_resolution" <<'EOF'
category: video
priority: medium
description: "Confere se xrandr consegue ler a resolução atual"
exec: bash -c 'if ! command -v xrandr >/dev/null 2>&1; then exit 5; fi; xrandr --current'
expect_nonempty: true
fail_message: Não foi possível obter resolução atual via xrandr.
warn_message: Sem ambiente gráfico ativo (xrandr indisponível).
probability: media
suggestions:
  - Verifique se está em uma sessão gráfica (Wayland/X11) com DISPLAY exportado.
  - Tente forçar uma resolução com xrandr --output <display> --mode <res>.
  - Revise drivers proprietários ou cabos/monitores.
fix: set_display_resolution
EOF

sos_check "gpu_acceleration" <<'EOF'
category: video
priority: high
description: "Detecta aceleração GL básica via glxinfo ou vulkaninfo"
exec: bash -c 'if command -v glxinfo >/dev/null 2>&1; then glxinfo -B; exit $?; fi; if command -v vulkaninfo >/dev/null 2>&1; then vulkaninfo --summary; exit $?; fi; exit 5'
expect_exit_code: 0
fail_message: Não foi possível confirmar aceleração gráfica (GL/Vulkan).
probability: alta
suggestions:
  - Instale mesa-utils (glxinfo) ou vulkan-tools para validar drivers.
  - Para NVIDIA, use nvidia-smi e certifique-se que o módulo está carregado.
  - Em Wayland, confirme se o backend suporta aceleração (ex.: wlroots).
fix: reinstall_gpu_stack
EOF

sos_check "gpu_driver_detected" <<'EOF'
category: video
priority: medium
description: "Detecta controladores VGA/3D via lspci"
exec: bash -c 'if ! command -v lspci >/dev/null 2>&1; then exit 5; fi; lspci -nn | grep -E "VGA|3D"'
expect_nonempty: true
fail_message: Não encontramos dispositivos VGA/3D no lspci.
probability: media
suggestions:
  - Instale o pacote pciutils (fornece lspci).
  - Em VMs, habilite aceleração 3D/paravirtualização no hypervisor.
  - Confira se o kernel detecta o dispositivo com dmesg | grep -i drm.
EOF
