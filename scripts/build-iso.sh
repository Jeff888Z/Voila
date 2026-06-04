#!/bin/bash
# VOILÀ — Build de l'ISO
# Appelé par le container Docker
# SPDX-License-Identifier: MIT
set -euo pipefail

readonly VERSION=$(date +%Y.%m.%d)
readonly DIST_DIR="/build/dist"
mkdir -p "$DIST_DIR"

echo "=== VOILÀ build v$VERSION ==="

# 1. Préparer le chroot live-build
cp -r /build/live-build-config/config /tmp/config-build
cd /tmp/config-build

# 2. Lancer lb config + build
# Note : lb config génère la config par défaut, on l'écrase avec la nôtre
echo "[1/3] lb config..."
lb config \
    --distribution bookworm \
    --archive-areas "main contrib non-free non-free-firmware" \
    --debian-installer none \
    --iso-application "VOILÀ" \
    --iso-publisher "JFR-Solutions; https://jfrsolution.fr; dev@jfrsolution.fr" \
    --iso-volume "VOILÀ v$VERSION" \
    --bootappend-live "boot=live components quiet splash username=voila hostname=voila" \
    --bootappend-live-failsafe "boot=live components noapic noapm nodma nomce nosmp nosplash vga=normal" \
    --binary-images iso-hybrid \
    --compression xz

echo "[2/3] lb build (ça prend 20-40 min)..."
lb build 2>&1 | tee /tmp/lb-build.log

# 3. Récupérer l'ISO
ISO=$(ls -t /tmp/config-build/live-image-*.iso 2>/dev/null | head -1)
if [ -z "$ISO" ]; then
    ISO=$(ls -t /tmp/lb-live-*.iso 2>/dev/null | head -1)
fi
if [ -z "$ISO" ]; then
    echo "ERREUR : aucun ISO produit" >&2
    exit 1
fi

cp -v "$ISO" "$DIST_DIR/voila-${VERSION}-amd64.iso"
echo "ISO produit : $DIST_DIR/voila-${VERSION}-amd64.iso"
ls -la "$DIST_DIR/"
