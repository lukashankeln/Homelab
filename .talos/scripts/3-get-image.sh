#!/usr/bin/env bash

# Resolve Talos factory installer image for a bare-metal amd64 machine.
#
# Usage:
#   ./3-get-image.sh [extension1 extension2 ...]
#
# Extensions can be passed as arguments (e.g. siderolabs/iscsi-tools) or are
# read from .talos/patches/extensions.yaml when no arguments are given.
# The resolved OCI image reference is written to patches/*/disk.yaml.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TALOS_DIR="$(dirname "$SCRIPT_DIR")"

# ---------------------------------------------------------------------------
# Read version
# ---------------------------------------------------------------------------
VERSION_FILE="$TALOS_DIR/version.txt"
if [[ ! -f "$VERSION_FILE" ]]; then
    echo "Error: $VERSION_FILE not found" >&2
    exit 1
fi

# shellcheck source=/dev/null
source "$VERSION_FILE"

if [[ -z "${TALOS_VERSION:-}" ]]; then
    echo "Error: TALOS_VERSION not set in $VERSION_FILE" >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# Collect extensions
# ---------------------------------------------------------------------------
EXTENSIONS=()

if [[ $# -gt 0 ]]; then
    EXTENSIONS=("$@")
else
    EXTENSIONS_FILE="$TALOS_DIR/patches/extensions.yaml"
    if [[ -f "$EXTENSIONS_FILE" ]]; then
        while IFS= read -r ext; do
            [[ -n "$ext" ]] && EXTENSIONS+=("$ext")
        done < <(
            grep -oE '\- siderolabs/[^ ]+' "$EXTENSIONS_FILE" | sed 's/^- //' || true
        )
    fi
fi

# ---------------------------------------------------------------------------
# Build JSON payload
# ---------------------------------------------------------------------------
build_json() {
    local ext_json=""
    for ext in "${EXTENSIONS[@]:-}"; do
        [[ -n "${ext:-}" ]] && ext_json+="\"$ext\","
    done
    ext_json="${ext_json%,}"
    printf '{"customization":{"systemExtensions":{"officialExtensions":[%s]}}}' "$ext_json"
}

PAYLOAD="$(build_json)"

# ---------------------------------------------------------------------------
# Call factory API
# ---------------------------------------------------------------------------
FACTORY_API="https://factory.talos.dev"
FACTORY_REGISTRY="factory.talos.dev"

echo "Calling Talos image factory for version ${TALOS_VERSION}..." >&2
if [[ ${#EXTENSIONS[@]} -gt 0 && -n "${EXTENSIONS[0]:-}" ]]; then
    echo "Extensions: ${EXTENSIONS[*]}" >&2
else
    echo "Extensions: (none)" >&2
fi

RESPONSE="$(curl -fsSL -X POST \
    -H "Content-Type: application/json" \
    -d "$PAYLOAD" \
    "$FACTORY_API/schematics")"

SCHEMATIC_ID="$(echo "$RESPONSE" | grep -oE '"id":"[^"]+"' | sed 's/"id":"//;s/"//')"

if [[ -z "$SCHEMATIC_ID" ]]; then
    echo "Error: failed to extract schematic ID from response: $RESPONSE" >&2
    exit 1
fi

# OCI image reference — no scheme, bare-metal amd64 installer
IMAGE="${FACTORY_REGISTRY}/metal-installer/${SCHEMATIC_ID}:${TALOS_VERSION}"

echo "Resolved image: $IMAGE" >&2

# ---------------------------------------------------------------------------
# Update patches/*/disk.yaml (cross-platform: macOS + Linux)
# ---------------------------------------------------------------------------
PATCHES_DIR="$TALOS_DIR/patches"

inplace_sed() {
    local pattern="$1"
    local file="$2"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "$pattern" "$file"
    else
        sed -i "$pattern" "$file"
    fi
}

for disk_yaml in "$PATCHES_DIR"/*/disk.yaml; do
    inplace_sed "s|image: factory\.talos\.dev/metal-installer/[^:]*:[^ ]*|image: $IMAGE|" "$disk_yaml"
    echo "Updated $disk_yaml" >&2
done
