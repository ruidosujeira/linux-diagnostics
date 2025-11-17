#!/usr/bin/env bash
# shellcheck shell=bash

sos_fix "restart_audio_stack" <<'EOF'
description: (RPM) Reinicia PipeWire e ALSA bridge
exec: bash -c 'systemctl --user restart pipewire.service pipewire-pulse.service 2>/dev/null || true; systemctl --user restart wireplumber.service 2>/dev/null || true; printf "Serviços de áudio reiniciados (RPM).\n"'
EOF

sos_check "pipewire_services_enabled" <<'EOF'
category: audio
priority: medium
description: "Confere unidades pipewire habilitadas"
exec: bash -c 'if ! command -v systemctl >/dev/null 2>&1; then exit 5; fi; systemctl --user is-enabled pipewire.service'
expect_exit_code: 0
fail_message: pipewire.service não está habilitado.
probability: media
suggestions:
  - Execute 'systemctl --user enable --now pipewire.service pipewire-pulse.service'.
  - Reinicie a sessão para reativar user units.
EOF
