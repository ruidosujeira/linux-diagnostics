#!/usr/bin/env bash
# shellcheck shell=bash

# DSL-based fixes -----------------------------------------------------------
sos_fix "set_dns_cloudflare" <<'EOF'
description: Ajusta DNS para servidores Cloudflare (demonstração)
exec: printf '%s\n%s\n%s\n' \
  "Use 'nmcli connection modify <conexao> ipv4.dns \"1.1.1.1 1.0.0.1\"'" \
  "Após ajustar, aplique 'nmcli connection up <conexao>' para recarregar." \
  "Este fix é apenas um guia seguro; personalize antes de aplicar."
EOF

sos_fix "restart_network_stack" <<'EOF'
description: Reinicia NetworkManager/stack de rede (não destrutivo)
exec: bash -c 'if command -v systemctl >/dev/null 2>&1; then \
  systemctl restart NetworkManager.service 2>/dev/null || true; \
  systemctl restart systemd-resolved.service 2>/dev/null || true; \
fi; printf "Rede reiniciada (se serviços existirem).\n"'
EOF

# Checks -------------------------------------------------------------------
sos_check "dns_resolve" <<'EOF'
category: network
priority: high
description: "Testa resolução de DNS para cloudflare.com"
exec: getent hosts cloudflare.com
expect_nonempty: true
fail_message: DNS não está resolvendo nomes.
probability: alta
suggestions:
  - Teste ping 1.1.1.1; se funcionar, problema é DNS.
  - Edite /etc/resolv.conf ou configure DNS via NetworkManager.
  - Reinicie o roteador ou confirme se há bloqueios locais.
fix: set_dns_cloudflare
EOF

sos_check "gateway_ping" <<'EOF'
category: network
priority: medium
description: "Verifica se o gateway padrão responde a ping"
exec: gw=$(ip route | awk '/default/ {print $3; exit}'); if [[ -z "$gw" ]]; then exit 3; fi; ping -c 1 -W 2 "$gw"
expect_exit_code: 0
fail_message: Gateway padrão não respondeu.
warn_message: Sem gateway padrão detectado.
probability: media
suggestions:
  - Confirme se o cabo ou Wi-Fi está conectado.
  - Execute 'nmcli device status' para ver o estado de links.
  - Reaplique seu perfil de rede com 'nmcli connection up <conexao>'.
fix: restart_network_stack
EOF
