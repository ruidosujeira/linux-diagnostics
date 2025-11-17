# Linux SOS

> Diagnósticos rápidos (e opcionais) para as dores mais comuns logo depois de instalar uma distro Linux.

Linux SOS é um CLI em Bash inspirado no "Windows Diagnostics" que oferece checks declarativos, correções seguras e packs por família de distro. O foco é padronizar o core e permitir que cada comunidade mantenha seus próprios módulos sem quebrar outras distros.

## Destaques

- **Core estável em Bash:** detecta a distro, regula a ordem de carregamento dos módulos (`common → família → ID`) e expõe uma mini DSL para checks/fixes.
- **Checks declarativos e seguros:** inspeções são read-only por padrão; fixes são opcionais, sempre confirmados (ou controlados por `--apply --yes`).
- **Saída unificada:** modo humano amigável ou `--json` para integração com outras ferramentas.
- **Packs por categoria/distro:** qualquer pessoa pode criar `modules/<categoria>/<family>.sh` e sobrescrever apenas o necessário.
- **Empacotamento simples:** `scripts/package.sh` gera um tarball com `bin/`, `core/`, `modules/`, `README.md` e `VERSION`.

## Estrutura do repositório

```
linux-diagnostics/
├── bin/
│   └── linux-sos              # CLI principal
├── core/
│   └── engine.sh              # Heartbeat + DSL
├── modules/
│   ├── audio/
│   │   ├── common.sh
│   │   ├── arch.sh
│   │   ├── debian.sh
│   │   └── rpm.sh
│   ├── network/
│   │   ├── common.sh
│   │   ├── arch.sh
│   │   ├── debian.sh
│   │   └── rpm.sh
│   ├── system/
│   │   ├── common.sh
│   │   ├── arch.sh
│   │   ├── debian.sh
│   │   └── rpm.sh
│   └── video/
│       ├── common.sh
│       ├── arch.sh
│       ├── debian.sh
│       └── rpm.sh
├── scripts/
│   └── package.sh             # Empacotador oficial
├── VERSION
└── README.md
```

## Como o core funciona

1. **Detecção da distro** via `/etc/os-release` expõe `LINUX_SOS_DISTRO_FAMILY` (debian, arch, rpm, generic) e `LINUX_SOS_DISTRO_ID` (ubuntu, fedora, manjaro...).
2. **Carregamento de módulos** por categoria sempre em três camadas: `common.sh` → `<family>.sh` → `<id>.sh` (quando existir). Packs podem sobrescrever checks/fixes reutilizando o mesmo `id`.
3. **Registro declarativo:** `sos_check` e `sos_fix` guardam toda a metadata (categoria, prioridade, sugestões, comando, probabilidade...).
4. **Execução segura:** checks rodam com coleta de saída, status e sugestões; fixes são oferecidos somente se o check falhar/warn e se `--apply` estiver ativo.
5. **Saída padronizada:** cada check retorna `{status: ok|warn|fail, probabilidade, mensagem, sugestões}`. No modo JSON, tudo vira um array de objetos simples.

## Mini DSL (check + fix)

```bash
sos_fix "set_dns_cloudflare" <<'EOF'
description: Ajusta DNS para servidores Cloudflare (demonstração)
exec: printf '%s\n%s\n%s\n' \
  "Use 'nmcli connection modify <conexao> ipv4.dns \"1.1.1.1 1.0.0.1\"'" \
  "Após ajustar, aplique 'nmcli connection up <conexao>' para recarregar." \
  "Este fix é apenas um guia seguro; personalize antes de aplicar."
EOF

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
fix: set_dns_cloudflare
EOF
```

Campos suportados em `sos_check`:

| Campo              | Descrição                                                     |
|--------------------|---------------------------------------------------------------|
| `category`         | network, audio, video, system, etc.                           |
| `priority`         | high, medium, low (impacta ordenação e destaque na saída).     |
| `exec`             | Comando a ser rodado. Pode usar `bash -c '...'`.               |
| `expect_exit_code` | Default `0`. Outros valores tratam falhas controladas.         |
| `expect_nonempty`  | `true/false`: exige saída não vazia.                           |
| `fail_message`     | Mensagem amigável quando algo falha.                           |
| `warn_message`     | Texto usado caso não exista saída, mas também não seja erro.   |
| `probability`      | baixa, media, alta (default `media`).                          |
| `suggestions`      | Lista `- item` (uma por linha).                                |
| `fix`              | ID do fix associado (se existir para essa distro).             |

Fixes podem reutilizar o mesmo `id` em cada pack, mantendo fallback automático para `common`.

## Módulos inclusos

| Categoria | Checks principais (common)                                         | Packs (exemplos)                                                                  |
|-----------|--------------------------------------------------------------------|-----------------------------------------------------------------------------------|
| network   | `dns_resolve`, `gateway_ping`                                      | `netplan_renderer_conflict` (debian), `netctl_profiles_down` (arch), `nm_cli_connections` (rpm) |
| audio     | `audio_server_running`, `default_sink_has_output`                  | `alsa_udev_permissions` (debian), `pipewire_packages` (arch), `pipewire_services_enabled` (rpm) |
| video     | `display_resolution`, `gpu_acceleration`, `gpu_driver_detected`    | `prime_select_state` (debian), `mkinitcpio_nvidia_hook` (arch), `rpmfusion_repository` (rpm)     |
| system    | `root_partition_usage`, `log_disk_pressure`, `time_drift`          | `apt_autoremove_pending` (debian), `pacman_cache_size` (arch), `dnf_history_pending` (rpm)       |

Crie novos checks/fixes em `common.sh` quando forem realmente universais. Caso contrário, abra um arquivo `<family>.sh` (ou até `<id>.sh`, como `modules/network/ubuntu.sh`) e mantenha tudo isolado ao pack.

## Uso

```bash
# Listar checks registrados
bin/linux-sos --list-checks

# Rodar tudo com saída humana
bin/linux-sos

# Focar em uma categoria com JSON
bin/linux-sos --category network --json

# Oferecer correções interativas (confirmação por check com fix disponível)
bin/linux-sos --apply

# Aplicar correções automaticamente após confirmação global
bin/linux-sos --apply --yes

# Rodar apenas um check e forçar JSON
bin/linux-sos --check dns_resolve --json
```

A CLI nunca executa correções automaticamente sem `--apply`. Mesmo com `--apply`, cada fix pede confirmação a menos que você use `--yes`.

## Contribuindo

1. Faça um fork/branch.
2. Adicione checks seguros (somente leitura) e fixes opcionais.
3. Atualize `README.md` e os módulos tocados com exemplos claros.
4. Rode `bin/linux-sos --list-checks` e, se possível, `scripts/package.sh` antes de abrir PR.

Pull requests e discussões sobre novos packs são sempre bem-vindos.
 
## Packs e contribuições por distro
│   │   ├── debian.sh
│   │   └── rpm.sh
│   ├── system/
│   │   ├── common.sh
│   │   ├── arch.sh
│   │   ├── debian.sh
│   │   └── rpm.sh
│   └── video/
│       ├── common.sh
│       ├── arch.sh
│       ├── debian.sh
│       └── rpm.sh
├── scripts/
│   └── package.sh             # Empacotador oficial
├── VERSION
└── README.md
```

## Como o core funciona

1. **Detecção da distro** via `/etc/os-release` expõe `LINUX_SOS_DISTRO_FAMILY` (debian, arch, rpm, generic) e `LINUX_SOS_DISTRO_ID` (ubuntu, fedora, manjaro...).
2. **Carregamento de módulos** por categoria sempre em três camadas: `common.sh` → `<family>.sh` → `<id>.sh` (quando existir). Packs podem sobrescrever checks/fixes reutilizando o mesmo `id`.
3. **Registro declarativo:** `sos_check` e `sos_fix` guardam toda a metadata (categoria, prioridade, sugestões, comando, probabilidade...).
4. **Execução segura:** checks rodam com coleta de saída, status e sugestões; fixes são oferecidos somente se o check falhar/warn e se `--apply` estiver ativo.
5. **Saída padronizada:** cada check retorna `{status: ok|warn|fail, probabilidade, mensagem, sugestões}`. No modo JSON, tudo vira um array de objetos simples.

## Mini DSL (check + fix)

```bash
sos_fix "set_dns_cloudflare" <<'EOF'
description: Ajusta DNS para servidores Cloudflare (demonstração)
exec: printf '%s\n%s\n%s\n' \
  "Use 'nmcli connection modify <conexao> ipv4.dns \"1.1.1.1 1.0.0.1\"'" \
  "Após ajustar, aplique 'nmcli connection up <conexao>' para recarregar." \
  "Este fix é apenas um guia seguro; personalize antes de aplicar."
EOF

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
fix: set_dns_cloudflare
EOF
```

Campos suportados em `sos_check`:

| Campo              | Descrição                                                     |
|--------------------|---------------------------------------------------------------|
| `category`         | network, audio, video, system, etc.                           |
| `priority`         | high, medium, low (impacta ordenação e destaque na saída).     |
| `exec`             | Comando a ser rodado. Pode usar `bash -c '...'`.               |
| `expect_exit_code` | Default `0`. Outros valores tratam falhas controladas.         |
| `expect_nonempty`  | `true/false`: exige saída não vazia.                           |
| `fail_message`     | Mensagem amigável quando algo falha.                           |
| `warn_message`     | Texto usado caso não exista saída, mas também não seja erro.   |
| `probability`      | baixa, media, alta (default `media`).                          |
| `suggestions`      | Lista `- item` (uma por linha).                                |
| `fix`              | ID do fix associado (se existir para essa distro).             |

Fixes podem reutilizar o mesmo `id` em cada pack, mantendo fallback automático para `common`.

## Módulos inclusos

| Categoria | Checks principais (common)                                         | Packs (exemplos)                                                                  |
|-----------|--------------------------------------------------------------------|-----------------------------------------------------------------------------------|
| network   | `dns_resolve`, `gateway_ping`                                      | `netplan_renderer_conflict` (debian), `netctl_profiles_down` (arch), `nm_cli_connections` (rpm) |
| audio     | `audio_server_running`, `default_sink_has_output`                  | `alsa_udev_permissions` (debian), `pipewire_packages` (arch), `pipewire_services_enabled` (rpm) |
| video     | `display_resolution`, `gpu_acceleration`, `gpu_driver_detected`    | `prime_select_state` (debian), `mkinitcpio_nvidia_hook` (arch), `rpmfusion_repository` (rpm)     |
| system    | `root_partition_usage`, `log_disk_pressure`, `time_drift`          | `apt_autoremove_pending` (debian), `pacman_cache_size` (arch), `dnf_history_pending` (rpm)       |

Crie novos checks/fixes em `common.sh` quando forem realmente universais. Caso contrário, abra um arquivo `<family>.sh` (ou até `<id>.sh`, como `modules/network/ubuntu.sh`) e mantenha tudo isolado ao pack.

## Uso

```bash
# Listar checks registrados
bin/linux-sos --list-checks

# Rodar tudo com saída humana
bin/linux-sos

# Focar em uma categoria com JSON
bin/linux-sos --category network --json

# Oferecer correções interativas (confirmação por check com fix disponível)
bin/linux-sos --apply

# Aplicar correções automaticamente após confirmação global
bin/linux-sos --apply --yes

# Rodar apenas um check e forçar JSON
bin/linux-sos --check dns_resolve --json
```

A CLI nunca executa correções automaticamente sem `--apply`. Mesmo com `--apply`, cada fix pede confirmação a menos que você use `--yes`.

## Packs e contribuições por distro

- **Famílias suportadas de fábrica:** `debian`, `arch`, `rpm` (fallback `generic`).
- **Sobrescreva apenas o necessário:** registre um fix com o mesmo `id` para trocar os comandos daquela família, mantendo a experiência consistente.
- **IDs específicos:** Se uma distro exigir um comportamento muito diferente (ex.: `ubuntu`, `fedora`), crie `modules/<categoria>/<id>.sh`. O core carrega `common → family → id` automaticamente.
- **Boas práticas:** checks devem ser não-destrutivos e funcionar sem root; fixes sempre devem explicar o que vão fazer antes de requisitar confirmação.

## Empacotamento

Defina a versão em `VERSION` e gere o pacote oficial:

```bash
scripts/package.sh
```

O script cria `dist/linux-sos-<versão>.tar.gz` contendo:

- `bin/linux-sos`
- `core/engine.sh`
- `modules/` (todos os packs disponíveis)
- `README.md`
- `VERSION`

Use esse tarball como base para publicar `linux-sos-core` ou montar repositórios `linux-sos-pack-<distro>` independentes.

## Roadmap sugerido

1. **Novos packs**: criar `modules/<categoria>/<id>.sh` para Ubuntu, Fedora, Manjaro, etc.
2. **Mais categorias**: adicionar pacotes específicos para drivers proprietários (NVIDIA/AMD) e periféricos (touchpad, bluetooth, sensores).
3. **Integração CI/CD**: rodar `bin/linux-sos --list-checks` e `bash -n core/engine.sh modules/**` em cada PR.
4. **Empacotamento distribuído**: separar `linux-sos-core` e publicar packs individuais como submódulos ou repositórios dedicados.

## Contribuindo

1. Faça um fork/branch.
2. Adicione checks seguros (somente leitura) e fixes opcionais.
3. Atualize `README.md` e os módulos tocados com exemplos claros.
4. Rode `bin/linux-sos --list-checks` e, se possível, `scripts/package.sh` antes de abrir PR.

Pull requests e discussões sobre novos packs são sempre bem-vindos.


