#!/usr/bin/env bash
# shellcheck shell=bash

sos_fix "restart_audio_stack" <<'EOF'
description: (Debian/Ubuntu) Reinicia PipeWire/PulseAudio com systemctl --user
exec: bash -c '
if command -v systemctl >/dev/null 2>&1; then
  systemctl --user restart pipewire.service pipewire-pulse.service wireplumber.service 2>/dev/null || true
fi
if command -v pulseaudio >/dev/null 2>&1; then
  pulseaudio -k >/dev/null 2>&1 || true
fi
printf "Pipeline de áudio reiniciado (Debian pack).\n"
'
EOF

sos_check "alsa_udev_permissions" <<'EOF'
category: audio
priority: low
description: "Confere se o usuário está no grupo audio"
exec: bash -c 'id -nG | tr " " "\n" | grep -Fx audio'
expect_nonempty: true
fail_message: Usuário não pertence ao grupo audio.
probability: baixa
suggestions:
  - Execute 'sudo usermod -aG audio $USER' e relogue.
  - Em PipeWire, grupos de áudio geralmente não são necessários, mas ajuda em ALSA puro.
EOF
