#!/usr/bin/env bash
# shellcheck shell=bash

sos_fix "refresh_pacman_mirrors" <<'EOF'
description: (Manjaro) Atualiza lista de mirrors e sincroniza pacman
exec: printf '%s\n%s\n' \
  "sudo pacman-mirrors --fasttrack && sudo pacman -Syy" \
  "Reaplique atualizações com: sudo pacman -Syu"
EOF

sos_check "pacman_mirror_status" <<'EOF'
category: system
priority: medium
description: "Valida se pacman-mirrors foi atualizado recentemente"
exec: bash -c 'if ! command -v pacman-mirrors >/dev/null 2>&1; then exit 5; fi; pacman-mirrors --status'
expect_nonempty: true
fail_message: Não foi possível obter status dos mirrors (pacman-mirrors).
probability: media
suggestions:
  - Rode 'sudo pacman-mirrors --fasttrack' para renovar a lista.
  - Sincronize pacman com 'sudo pacman -Syy'.
fix: refresh_pacman_mirrors
EOF
