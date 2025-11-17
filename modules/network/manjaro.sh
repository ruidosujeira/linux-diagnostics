#!/usr/bin/env bash
# shellcheck shell=bash

sos_fix "nm_enable_managed" <<'EOF'
description: (Manjaro) Ativa managed=true para NetworkManager
exec: printf '%s\n%s\n' \
  "Edite /etc/NetworkManager/NetworkManager.conf e garanta managed=true em [main]." \
  "Reinicie com: sudo systemctl restart NetworkManager.service"
EOF

sos_check "nm_managed_flag" <<'EOF'
category: network
priority: medium
description: "Confere flag managed=true nos arquivos da Manjaro"
exec: bash -c 'grep -R "managed=" /etc/NetworkManager/NetworkManager.conf /etc/NetworkManager/conf.d 2>/dev/null'
expect_nonempty: true
fail_message: NetworkManager não está configurado como managed.
probability: media
suggestions:
  - Garanta que [main] managed=true esteja definido.
  - Remova restos do netctl/ConnMan antes de usar NetworkManager.
fix: nm_enable_managed
EOF
