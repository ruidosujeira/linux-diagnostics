#!/usr/bin/env bash
# shellcheck shell=bash

sos_fix "nm_reload_dns" <<'EOF'
description: (Fedora) Reinicia NetworkManager e limpa caches DNS
exec: printf '%s\n%s\n' \
  "sudo systemctl restart NetworkManager.service" \
  "sudo resolvectl flush-caches 2>/dev/null || sudo systemd-resolve --flush-caches"
EOF

sos_check "nmcli_general_state" <<'EOF'
category: network
priority: high
description: "Garante que nmcli reporta estado conectado"
exec: bash -c 'if ! command -v nmcli >/dev/null 2>&1; then exit 5; fi; state=$(nmcli -t -f STATE general); [[ "$state" == "connected" ]] && echo "$state"'
expect_exit_code: 0
fail_message: NetworkManager não está conectado segundo nmcli.
probability: alta
suggestions:
  - Revise conexões com 'nmcli connection show --active'.
  - Reinicie o serviço com 'sudo systemctl restart NetworkManager'.
  - Confira logs em 'journalctl -u NetworkManager --since "-5m"'.
fix: nm_reload_dns
EOF
