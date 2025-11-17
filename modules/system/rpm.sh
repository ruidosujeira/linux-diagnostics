#!/usr/bin/env bash
# shellcheck shell=bash

sos_fix "clean_journal" <<'EOF'
description: (RPM) Limpa journals e cache DNF
exec: printf '%s\n%s\n' \
  "sudo journalctl --vacuum-size=100M" \
  "sudo dnf clean all"
EOF

sos_check "dnf_history_pending" <<'EOF'
category: system
priority: low
description: "Procura transações DNF incompletas"
exec: bash -c 'if ! command -v dnf >/dev/null 2>&1; then exit 5; fi; dnf history sync >/dev/null 2>&1 && dnf history list | head'
expect_nonempty: true
fail_message: dnf history não retornou registros.
probability: baixa
suggestions:
  - Rode 'sudo dnf history undo <id>' se alguma transação falhou.
  - Limpe caches com 'sudo dnf clean packages'.
EOF
