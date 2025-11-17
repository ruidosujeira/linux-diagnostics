#!/usr/bin/env bash
# shellcheck shell=bash

sos_fix "clean_journal" <<'EOF'
description: Reduce o tamanho do journalctl para 100M
exec: bash -c 'if ! command -v journalctl >/dev/null 2>&1; then \
  printf "journalctl não disponível.\n"; exit 1; \
fi; printf "Use: sudo journalctl --vacuum-size=100M\n"'
EOF

sos_fix "sync_clock" <<'EOF'
description: Usa timedatectl para sincronizar data/hora
exec: bash -c 'if ! command -v timedatectl >/dev/null 2>&1; then \
  printf "timedatectl não disponível; configure NTP manualmente.\n"; exit 1; \
fi; printf "Use: sudo timedatectl set-ntp true && timedatectl timesync-status\n"'
EOF

sos_check "root_partition_usage" <<'EOF'
category: system
priority: high
description: "Verifica uso da partição raiz"
exec: bash -c 'usage=$(df -P / | awk "NR==2 {gsub(/%/,\"\",$5); print $5}"); if [[ -z "$usage" ]]; then exit 5; fi; if (( usage >= 90 )); then echo "$usage"; exit 9; fi; echo "$usage"'
expect_exit_code: 0
fail_message: Partição raiz acima de 90%% de uso.
probability: alta
suggestions:
  - Rode 'sudo du -xh / | sort -h | tail' para encontrar diretórios grandes.
  - Limpe caches de pacotes (apt, pacman, dnf) e /var/tmp.
fix: clean_journal
EOF

sos_check "log_disk_pressure" <<'EOF'
category: system
priority: medium
description: "Detecta diretórios de log acima de 1G"
exec: bash -c 'if ! command -v du >/dev/null 2>&1; then exit 5; fi; du -sh /var/log 2>/dev/null'
expect_nonempty: true
fail_message: Não foi possível consultar /var/log.
probability: media
suggestions:
  - Analise arquivos em /var/log com mais de 500M e rotacione-os.
  - Configure logrotate ou journald SystemMaxUse=200M.
fix: clean_journal
EOF

sos_check "time_drift" <<'EOF'
category: system
priority: medium
description: "Confere se timedatectl reporta NTP sincronizado"
exec: bash -c 'if ! command -v timedatectl >/dev/null 2>&1; then exit 5; fi; timedatectl show -p NTPSynchronized -p Timezone'
expect_nonempty: true
fail_message: timedatectl não confirma sincronização NTP.
probability: media
suggestions:
  - Execute 'timedatectl set-ntp true' para ativar sincronização.
  - Ajuste manualmente com 'sudo hwclock --systohc' em dual boot.
fix: sync_clock
EOF
