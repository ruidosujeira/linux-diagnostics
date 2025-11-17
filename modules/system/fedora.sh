#!/usr/bin/env bash
# shellcheck shell=bash

sos_fix "enable_dnf_automatic" <<'EOF'
description: (Fedora) Ativa dnf-automatic.timer
exec: printf '%s\n' "sudo systemctl enable --now dnf-automatic.timer"
EOF

sos_check "dnf_automatic_timer" <<'EOF'
category: system
priority: low
description: "Verifica se dnf-automatic.timer está ativo"
exec: bash -c 'if ! command -v systemctl >/dev/null 2>&1; then exit 5; fi; systemctl is-enabled dnf-automatic.timer'
expect_exit_code: 0
fail_message: dnf-automatic.timer não está habilitado.
probability: baixa
suggestions:
  - Habilite atualizações automáticas com 'sudo systemctl enable --now dnf-automatic.timer'.
  - Ajuste /etc/dnf/automatic.conf para definir políticas de reboot/aplicação.
fix: enable_dnf_automatic
EOF
