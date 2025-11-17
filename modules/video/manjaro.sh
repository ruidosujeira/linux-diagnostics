#!/usr/bin/env bash
# shellcheck shell=bash

sos_fix "mhwd_switch_driver" <<'EOF'
description: (Manjaro) Sugere trocar driver com mhwd
exec: printf '%s\n%s\n' \
  "Listar drivers: sudo mhwd -l" \
  "Aplicar driver recomendado: sudo mhwd -a pci free 0300 OU sudo mhwd -a pci nonfree 0300"
EOF

sos_check "mhwd_driver_state" <<'EOF'
category: video
priority: medium
description: "Confere drivers instalados via mhwd"
exec: bash -c 'if ! command -v mhwd >/dev/null 2>&1; then exit 5; fi; mhwd -li'
expect_nonempty: true
fail_message: mhwd não listou drivers ativos.
probability: media
suggestions:
  - Use 'mhwd -a pci free 0300' para drivers open-source.
  - Para NVIDIA proprietária, rode 'mhwd -a pci nonfree 0300'.
fix: mhwd_switch_driver
EOF
