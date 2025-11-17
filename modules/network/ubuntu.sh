#!/usr/bin/env bash
# shellcheck shell=bash

sos_fix "resolved_flush_cache" <<'EOF'
description: (Ubuntu) Reinicia systemd-resolved e limpa cache DNS
exec: bash -c '
if ! command -v resolvectl >/dev/null 2>&1; then
  printf "resolvectl indisponível; instale systemd-resolved.\n"
  exit 1
fi
printf "Use: sudo systemctl restart systemd-resolved.service && sudo resolvectl flush-caches\n"
'
EOF

sos_check "resolved_stub_listening" <<'EOF'
category: network
priority: medium
description: "Valida se /etc/resolv.conf aponta para 127.0.0.53 (systemd-resolved)"
exec: bash -c 'if [[ ! -f /etc/resolv.conf ]]; then exit 5; fi; grep -q "127.0.0.53" /etc/resolv.conf'
expect_exit_code: 0
fail_message: resolv.conf não aponta para o stub do systemd-resolved.
probability: media
suggestions:
  - Verifique se /etc/resolv.conf é um link para /run/systemd/resolve/stub-resolv.conf.
  - Rode "sudo ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf" quando apropriado.
  - Reinicie systemd-resolved após ajustes.
fix: resolved_flush_cache
EOF

sos_check "netplan_pending_changes" <<'EOF'
category: network
priority: low
description: "Confere se há alterações pendentes no netplan"
exec: bash -c 'if ! command -v netplan >/dev/null 2>&1; then exit 5; fi; netplan status 2>&1 | grep -i "Changes"'
expect_nonempty: true
fail_message: Netplan não apontou alterações pendentes.
probability: baixa
suggestions:
  - Execute 'sudo netplan generate && sudo netplan apply' após revisar arquivos.
  - Verifique YAMLs em /etc/netplan para renderers conflitantes.
EOF
