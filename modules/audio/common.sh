#!/usr/bin/env bash
# shellcheck shell=bash

sos_fix "restart_audio_stack" <<'EOF'
description: Reinicia PipeWire/PulseAudio no usuário atual
exec: bash -c 'if command -v systemctl >/dev/null 2>&1; then \
  systemctl --user restart pipewire.service pipewire-pulse.service 2>/dev/null || true; \
fi; if command -v pw-cli >/dev/null 2>&1; then \
  pw-cli ls >/dev/null 2>&1 || true; \
fi; if command -v pulseaudio >/dev/null 2>&1; then \
  pulseaudio -k >/dev/null 2>&1 || true; \
fi; printf "Pipeline de áudio reiniciado (quando suportado).\n"'
EOF

sos_fix "cycle_audio_outputs" <<'EOF'
description: Sugere alternar dispositivo de saída padrão via pactl
exec: bash -c 'if command -v pactl >/dev/null 2>&1; then \
  current=$(pactl info | awk -F": " "/Default Sink/ {print $2}"); \
  printf "Saída padrão atual: %s\n" "$current"; \
  printf "Use: pactl set-default-sink <sink>\n"; \
else \
  printf "Abra as configurações de som da sua distro e selecione o dispositivo correto.\n"; \
fi'
EOF

sos_check "audio_server_running" <<'EOF'
category: audio
priority: high
description: "PipeWire ou PulseAudio estão rodando?"
exec: bash -c 'if command -v pw-cli >/dev/null 2>&1; then pw-cli info 0 >/dev/null 2>&1 || exit 2; exit 0; fi; if command -v pactl >/dev/null 2>&1; then pactl info >/dev/null 2>&1 || exit 2; exit 0; fi; exit 5'
expect_exit_code: 0
fail_message: Nenhum servidor de áudio respondeu.
probability: alta
suggestions:
  - Reinstale/ative PipeWire ou PulseAudio.
  - Verifique 'systemctl --user status pipewire pipewire-pulse'.
  - Refaça login gráfico para reativar serviços de usuário.
fix: restart_audio_stack
EOF

sos_check "default_sink_has_output" <<'EOF'
category: audio
priority: medium
description: "Dispositivo de saída padrão parece válido"
exec: bash -c 'if command -v pactl >/dev/null 2>&1; then pactl info | grep -E "Default Sink"; exit $?; fi; if command -v wpctl >/dev/null 2>&1; then wpctl status | grep -A 2 "Sinks"; exit $?; fi; exit 5'
expect_nonempty: true
fail_message: Não foi possível identificar um dispositivo de saída ativo.
probability: media
suggestions:
  - Abra as configurações de som e escolha a saída correta.
  - Com PulseAudio, use 'pavucontrol' para inspecionar perfis.
  - Em PipeWire/WirePlumber, tente 'wpctl status'.
fix: cycle_audio_outputs
EOF
