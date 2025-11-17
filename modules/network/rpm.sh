#!/usr/bin/env bash
# shellcheck shell=bash

sos_fix "restart_network_stack" <<'EOF'
description: (RPM) Reinicia NetworkManager e limpa dnsmasq
exec: bash -c 'sudo systemctl restart NetworkManager.service; sudo systemctl restart NetworkManager-dispatcher.service 2>/dev/null || true; printf "Stack de rede reiniciado (RPM).\n"'
EOF

sos_check "nm_cli_connections" <<'EOF'
category: network
priority: medium
description: "Lista conexões nmcli para verificar estados"
exec: bash -c 'if ! command -v nmcli >/dev/null 2>&1; then exit 5; fi; nmcli --fields NAME,TYPE,DEVICE con show'
expect_nonempty: true
fail_message: nmcli não conseguiu listar conexões (RPM).
probability: media
suggestions:
  - Verifique se NetworkManager está habilitado: sudo systemctl enable --now NetworkManager.
  - Recrie perfis com 'nmcli connection add ...'.
EOF
