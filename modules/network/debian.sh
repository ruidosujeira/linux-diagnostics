#!/usr/bin/env bash
# shellcheck shell=bash

sos_fix "set_dns_cloudflare" <<'EOF'
description: (Debian/Ubuntu) Ajusta DNS via Netplan/resolved
exec: bash -c 'cat <<INSTR
1. sudo nano /etc/netplan/*.yaml e adicione:
   nameservers:
     addresses: [1.1.1.1, 1.0.0.1]
2. sudo netplan apply
3. sudo systemctl restart systemd-resolved.service
INSTR'
EOF

sos_check "netplan_renderer_conflict" <<'EOF'
category: network
priority: medium
description: "Detecta configs Netplan apontando para renderer errado"
exec: bash -c 'if ! command -v netplan >/dev/null 2>&1; then exit 5; fi; grep -R "renderer" /etc/netplan 2>/dev/null'
expect_nonempty: true
fail_message: Renderer do Netplan pode estar ausente.
probability: media
suggestions:
  - Ajuste renderer para NetworkManager ou networkd conforme sua escolha.
  - Rode 'sudo netplan generate && sudo netplan apply'.
fix: set_dns_cloudflare
EOF
