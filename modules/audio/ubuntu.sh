#!/usr/bin/env bash
# shellcheck shell=bash

sos_fix "remove_snap_pulseaudio" <<'EOF'
description: (Ubuntu) Remove conflito do snap pulseaudio
exec: printf '%s\n%s\n' \
  "sudo snap stop pulseaudio && sudo snap remove pulseaudio" \
  "Use PipeWire/PulseAudio do sistema (apt) após remover o snap."
EOF

sos_check "snap_pulseaudio_conflict" <<'EOF'
category: audio
priority: medium
description: "Detecta instalação do snap pulseaudio conflitando"
exec: bash -c 'if ! command -v snap >/dev/null 2>&1; then exit 5; fi; snap list pulseaudio 2>/dev/null'
expect_nonempty: true
fail_message: Snap pulseaudio não está instalado (sem conflito).
probability: media
suggestions:
  - Remova o snap pulseaudio e mantenha apenas PipeWire/PulseAudio do sistema.
  - Reinicie a sessão após remover o snap para recarregar serviços.
fix: remove_snap_pulseaudio
EOF
