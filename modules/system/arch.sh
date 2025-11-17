#!/usr/bin/env bash
# shellcheck shell=bash

sos_fix "clean_journal" <<'EOF'
description: (Arch) Limpa journals e cache pacman
exec: printf '%s\n%s\n' \
  "sudo journalctl --vacuum-size=100M" \
  "sudo pacman -Sc"
EOF

sos_check "pacman_cache_size" <<'EOF'
category: system
priority: medium
description: "Avalia tamanho do cache pacman"
exec: bash -c 'if ! command -v du >/dev/null 2>&1 || [[ ! -d /var/cache/pacman/pkg ]]; then exit 5; fi; du -sh /var/cache/pacman/pkg'
expect_nonempty: true
fail_message: Não foi possível medir /var/cache/pacman/pkg.
probability: media
suggestions:
  - Execute 'sudo pacman -Scc' para limpar completamente (irá perguntar duas vezes).
EOF
