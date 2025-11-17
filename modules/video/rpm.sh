#!/usr/bin/env bash
# shellcheck shell=bash

sos_fix "reinstall_gpu_stack" <<'EOF'
description: (RPM) Sugere reinstalar drivers mesa/nvidia
exec: printf '%s\n%s\n' \
  "Mesa: sudo dnf groupinstall 'Hardware Support' --with-optional" \
  "NVIDIA: consulte rpmfusion e rode sudo dnf install akmod-nvidia xorg-x11-drv-nvidia-cuda"
EOF

sos_check "rpmfusion_repository" <<'EOF'
category: video
priority: low
description: "Confere se RPM Fusion está configurado"
exec: bash -c 'if ! command -v dnf >/dev/null 2>&1; then exit 5; fi; dnf repolist | grep -i rpmfusion'
expect_nonempty: true
fail_message: Repositório RPM Fusion não encontrado (necessário para drivers proprietários).
probability: baixa
suggestions:
  - Ative com: sudo dnf install https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm
  - Repita para rpmfusion-nonfree se usar NVIDIA.
EOF
