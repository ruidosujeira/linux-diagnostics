#!/usr/bin/env bash
# shellcheck shell=bash

sos_fix "reinstall_gpu_stack" <<'EOF'
description: (Arch) Orienta reinstalação de drivers mesa/nvidia
exec: printf '%s\n%s\n' \
  "Mesa: sudo pacman -Syu mesa vulkan-radeon vulkan-intel" \
  "NVIDIA: sudo pacman -Syu nvidia nvidia-utils nvidia-settings"
EOF

sos_check "mkinitcpio_nvidia_hook" <<'EOF'
category: video
priority: low
description: "Confere se mkinitcpio possui módulo nvidia"
exec: bash -c 'if [[ ! -f /etc/mkinitcpio.conf ]]; then exit 5; fi; grep -n "nvidia" /etc/mkinitcpio.conf'
expect_nonempty: true
fail_message: mkinitcpio não menciona nvidia; pode faltar hook.
probability: baixa
suggestions:
  - Edite /etc/mkinitcpio.conf adicionando nvidia nvidia_modeset nvidia_uvm nvidia_drm em MODULES.
  - Recrie initramfs: sudo mkinitcpio -P.
EOF
