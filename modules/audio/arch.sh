#!/usr/bin/env bash
# shellcheck shell=bash

sos_fix "restart_audio_stack" <<'EOF'
description: (Arch) Reinicia PipeWire + WirePlumber
exec: bash -c 'systemctl --user restart pipewire.service wireplumber.service pipewire-pulse.service 2>/dev/null || true; pactl list short sinks >/dev/null 2>&1 || true; printf "Serviços de áudio reiniciados (Arch).\n"'
EOF

sos_check "pipewire_packages" <<'EOF'
category: audio
priority: medium
description: "Verifica se pacotes pipewire/jack estão instalados"
exec: bash -c 'if ! command -v pacman >/dev/null 2>&1; then exit 5; fi; pacman -Q pipewire pipewire-pulse pipewire-alsa 2>/dev/null'
expect_nonempty: true
fail_message: Pacotes PipeWire essenciais ausentes.
probability: media
suggestions:
  - Instale com 'sudo pacman -S pipewire pipewire-alsa pipewire-pulse wireplumber'.
  - Remova PulseAudio standalone para evitar conflitos.
EOF
