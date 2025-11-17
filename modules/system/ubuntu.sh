#!/usr/bin/env bash
# shellcheck shell=bash

sos_fix "enable_unattended_upgrades" <<'EOF'
description: (Ubuntu) Ativa unattended-upgrades
exec: printf '%s\n%s\n' \
  "sudo apt install unattended-upgrades" \
  "sudo dpkg-reconfigure --priority=low unattended-upgrades"
EOF

sos_check "unattended_upgrades_status" <<'EOF'
category: system
priority: low
description: "Confere se unattended-upgrades.service está habilitado"
exec: bash -c 'if ! command -v systemctl >/dev/null 2>&1; then exit 5; fi; systemctl is-enabled unattended-upgrades.service'
expect_exit_code: 0
fail_message: unattended-upgrades não está habilitado.
probability: baixa
suggestions:
  - Rode 'sudo dpkg-reconfigure --priority=low unattended-upgrades'.
  - Verifique /etc/apt/apt.conf.d/50unattended-upgrades para personalizações.
fix: enable_unattended_upgrades
EOF
