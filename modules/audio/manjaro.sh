#!/usr/bin/env bash
# shellcheck shell=bash

sos_fix "disable_pulseaudio_daemon" <<'EOF'
description: (Manjaro) Desabilita PulseAudio legado quando usando PipeWire
exec: printf '%s\n%s\n' \
  "systemctl --user mask pulseaudio.service pulseaudio.socket" \
  "systemctl --user enable --now pipewire-pulse.service"
EOF

sos_check "pulseaudio_legacy_active" <<'EOF'
category: audio
priority: medium
description: "Verifica se pulseaudio.service ainda está ativo"
exec: bash -c 'if ! command -v systemctl >/dev/null 2>&1; then exit 5; fi; if systemctl --user is-active pulseaudio.service >/dev/null 2>&1; then exit 9; fi; echo "PulseAudio legacy desativado"'
expect_exit_code: 0
fail_message: PulseAudio legacy continua ativo, pode conflitar com PipeWire.
probability: media
suggestions:
  - Desabilite o serviço com 'systemctl --user mask pulseaudio.service'.
  - Ative pipewire-pulse para fornecer compatibilidade com PulseAudio.
fix: disable_pulseaudio_daemon
EOF
