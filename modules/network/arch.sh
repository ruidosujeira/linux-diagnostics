#!/usr/bin/env bash
# shellcheck shell=bash

sos_fix "restart_network_stack" <<'EOF'
description: (Arch) Reinicia NetworkManager e systemd-resolved
exec: bash -c 'if ! command -v systemctl >/dev/null 2>&1; then exit 1; fi; sudo systemctl restart NetworkManager.service; sudo systemctl restart systemd-resolved.service 2>/dev/null || true; printf "Serviços de rede reiniciados.\n"'
EOF

sos_check "netctl_profiles_down" <<'EOF'
category: network
priority: medium
description: "Verifica perfis netctl falhando"
exec: bash -c 'if ! command -v netctl >/dev/null 2>&1; then exit 5; fi; netctl list'
expect_nonempty: true
fail_message: netctl não encontrou perfis ou não está instalado.
probability: media
suggestions:
  - Habilite um perfil específico com 'sudo netctl start <profile>'.
  - Considere migrar para NetworkManager/ConnMan caso prefira interface amigável.
EOF
