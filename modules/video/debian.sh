#!/usr/bin/env bash
# shellcheck shell=bash

sos_fix "reinstall_gpu_stack" <<'EOF'
description: (Debian/Ubuntu) Sugestão rápida para reinstalar drivers Mesa/NVIDIA
exec: printf '%s\n%s\n' \
  "Mesa: sudo apt install --reinstall mesa-vulkan-drivers mesa-utils" \
  "NVIDIA: sudo ubuntu-drivers autoinstall && sudo reboot"
EOF

sos_check "prime_select_state" <<'EOF'
category: video
priority: medium
description: "Verifica estado do prime-select"
exec: bash -c 'if ! command -v prime-select >/dev/null 2>&1; then exit 5; fi; prime-select query'
expect_nonempty: true
fail_message: prime-select não retornou GPU ativa.
probability: media
suggestions:
  - Use 'sudo prime-select nvidia' ou 'intel' conforme sua necessidade.
  - Reinicie após alterar para aplicar drivers proprietários.
EOF
