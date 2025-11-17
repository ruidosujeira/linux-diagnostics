#!/usr/bin/env bash
# shellcheck shell=bash

sos_fix "clean_journal" <<'EOF'
description: (Debian/Ubuntu) Limpa journals + apt caches
exec: printf '%s\n%s\n' \
  "sudo journalctl --vacuum-size=100M" \
  "sudo apt autoremove && sudo apt clean"
EOF

sos_check "apt_autoremove_pending" <<'EOF'
category: system
priority: low
description: "Itens órfãos aguardando autoremove"
exec: bash -c 'if ! command -v apt-get >/dev/null 2>&1; then exit 5; fi; apt-get -s autoremove | grep -i "Remv"'
expect_nonempty: true
fail_message: Nenhum pacote órfão foi listado.
probability: baixa
suggestions:
  - Rode 'sudo apt autoremove' para liberar espaço.
EOF
