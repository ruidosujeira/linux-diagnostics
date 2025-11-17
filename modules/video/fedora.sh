#!/usr/bin/env bash
# shellcheck shell=bash

sos_fix "install_mesa_vulkan" <<'EOF'
description: (Fedora) Instala drivers Mesa Vulkan adicionais
exec: printf '%s\n' "sudo dnf install mesa-vulkan-drivers mesa-dri-drivers"
EOF

sos_check "mesa_vulkan_present" <<'EOF'
category: video
priority: low
description: "Verifica se mesa-vulkan-drivers está instalado"
exec: bash -c 'if ! command -v rpm >/dev/null 2>&1; then exit 5; fi; rpm -q mesa-vulkan-drivers'
expect_exit_code: 0
fail_message: Pacote mesa-vulkan-drivers ausente.
probability: baixa
suggestions:
  - Instale com 'sudo dnf install mesa-vulkan-drivers'.
  - Reinicie o ambiente gráfico após instalar para carregar bibliotecas.
fix: install_mesa_vulkan
EOF
