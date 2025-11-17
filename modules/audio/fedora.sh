#!/usr/bin/env bash
# shellcheck shell=bash

sos_fix "install_pipewire_alsa" <<'EOF'
description: (Fedora) Instala complementos PipeWire ALSA/jack
exec: printf '%s\n' "sudo dnf install pipewire-alsa pipewire-jack wireplumber"
EOF

sos_check "pipewire_alsa_packages" <<'EOF'
category: audio
priority: low
description: "Confere se pacotes pipewire-alsa/jack estão presentes"
exec: bash -c 'if ! command -v rpm >/dev/null 2>&1; then exit 5; fi; rpm -q pipewire-alsa pipewire-jack 2>/dev/null'
expect_nonempty: true
fail_message: Pacotes pipewire-alsa/jack não encontrados.
probability: baixa
suggestions:
  - Instale com 'sudo dnf install pipewire-alsa pipewire-jack wireplumber'.
  - Reinicie a sessão gráfica após instalar para carregar os módulos.
fix: install_pipewire_alsa
EOF
