#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION_FILE="${ROOT_DIR}/VERSION"
if [[ ! -f "$VERSION_FILE" ]]; then
  echo "VERSION file não encontrado." >&2
  exit 1
fi
VERSION="$(tr -d '\n' < "$VERSION_FILE")"
DIST_DIR="${ROOT_DIR}/dist"

mkdir -p "$DIST_DIR"
rm -f "$DIST_DIR"/linux-sos-*.tar.gz

copy_common_modules() {
  local target="$1"
  local category
  for category in "$ROOT_DIR"/modules/*; do
    [[ -d "$category" ]] || continue
    local name="$(basename "$category")"
    mkdir -p "$target/modules/$name"
    if [[ -f "$category/common.sh" ]]; then
      cp "$category/common.sh" "$target/modules/$name/common.sh"
    fi
  done
}

pack_core() {
  local tmp
  tmp="$(mktemp -d)"
  cp -a "$ROOT_DIR/bin" "$tmp/bin"
  cp -a "$ROOT_DIR/core" "$tmp/core"
  copy_common_modules "$tmp"
  cp "$ROOT_DIR/README.md" "$tmp/README.md"
  cp "$VERSION_FILE" "$tmp/VERSION"
  ( cd "$tmp" && tar -czf "$DIST_DIR/linux-sos-core-${VERSION}.tar.gz" . )
  rm -rf "$tmp"
  echo "[pack] Core -> $DIST_DIR/linux-sos-core-${VERSION}.tar.gz"
}

pack_layer() {
  local label="$1"
  local pattern="$2"
  local tmp="$(mktemp -d)"
  local -a files=()
  while IFS= read -r rel; do
    files+=("$rel")
  done < <(cd "$ROOT_DIR" && find modules -mindepth 2 -maxdepth 2 -name "${pattern}.sh" -print)

  if ((${#files[@]} == 0)); then
    rm -rf "$tmp"
    echo "[pack] Nenhum arquivo para ${label}, pulando."
    return
  fi

  for rel in "${files[@]}"; do
    mkdir -p "$tmp/$(dirname "$rel")"
    cp "$ROOT_DIR/$rel" "$tmp/$rel"
  done
  cp "$ROOT_DIR/README.md" "$tmp/README.md"
  cp "$VERSION_FILE" "$tmp/VERSION"
  ( cd "$tmp" && tar -czf "$DIST_DIR/linux-sos-pack-${label}-${VERSION}.tar.gz" . )
  rm -rf "$tmp"
  echo "[pack] ${label} -> $DIST_DIR/linux-sos-pack-${label}-${VERSION}.tar.gz"
}

pack_core
pack_layer "debian" "debian.sh"
pack_layer "arch" "arch.sh"
pack_layer "rpm" "rpm.sh"
pack_layer "ubuntu" "ubuntu.sh"
pack_layer "fedora" "fedora.sh"
pack_layer "manjaro" "manjaro.sh"
