#!/usr/bin/env bash
# shellcheck shell=bash

sos_fix "enable_secureboot_drivers" <<'EOF'
description: (Ubuntu) Guia para assinar drivers com Secure Boot
exec: printf '%s\n%s\n' \
  "sudo mokutil --import <sua-chave>.cer (após gerar chave com openssl)." \
  "Reinicie para concluir o enrolamento da chave e permitir drivers proprietários."
EOF

sos_check "secureboot_blocking_modules" <<'EOF'
category: video
priority: medium
description: "Checa se Secure Boot está ativo e drivers DKMS falharam"
exec: bash -c 'if ! command -v mokutil >/dev/null 2>&1; then exit 5; fi; mokutil --sb-state'
expect_nonempty: true
fail_message: Não foi possível verificar estado do Secure Boot.
probability: media
suggestions:
  - Se Secure Boot estiver habilitado, assine módulos DKMS com mokutil.
  - Desative temporariamente Secure Boot para diagnosticar falhas de driver.
fix: enable_secureboot_drivers
EOF

sos_check "dkms_pending_modules" <<'EOF'
category: video
priority: high
description: "Detecta módulos DKMS com build pendente"
exec: bash -c 'if ! command -v dkms >/dev/null 2>&1; then exit 5; fi; pending=$(dkms status | grep -Ei "(added|install)" || true); if [[ -n "$pending" ]]; then echo "$pending"; exit 9; fi; echo "Nenhum módulo pendente"'
expect_exit_code: 0
fail_message: Há builds DKMS pendentes; conclua a instalação dos drivers.
probability: alta
suggestions:
  - Rode 'sudo dkms autoinstall' para reconstruir módulos.
  - Leia /var/lib/dkms/<módulo>/build/make.log para detalhes do erro.
EOF
