#!/bin/bash
# VOILÀ — Build de l'ISO
# Appelé par le container Docker
# SPDX-License-Identifier: MIT
set -euo pipefail

readonly VERSION=$(date +%Y.%m.%d)
readonly DIST_DIR="/build/dist"
mkdir -p "$DIST_DIR"

echo "=== VOILÀ build v$VERSION ==="

# 1. Préparer le répertoire de travail live-build
mkdir -p /tmp/config-build
cd /tmp/config-build

# 2. Lancer lb config dans un dossier SÉPARÉ pour ne pas écraser nos fichiers custom
# On utilise --config pour pointer sur un dossier de config "neutre", puis on copie
# nos personnalisations (hooks, package-lists) APRÈS lb config, pour qu'elles soient
# prises en compte par lb build sans être effacées.
echo "[1/4] lb config (génère config/ par défaut)..."
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

# 3. Injecter nos personnalisations (hooks, package-lists) dans le config/ généré
echo "[2/4] Injection des personnalisations VOILÀ..."
# Copier les hooks normal (live-build a déjà créé config/hooks/normal/ avec ses propres hooks)
cp -rv /build/live-build-config/config/hooks/normal/* config/hooks/normal/
# Copier les listes de paquets (pareil, config/package-lists/ existe déjà)
cp -rv /build/live-build-config/config/package-lists/* config/package-lists/

echo "[3/4] lb build (ça prend 20-40 min)..."
lb build 2>&1 | tee /tmp/lb-build.log

# 4. Récupérer l'ISO
ISO=$(ls -t live-image-*.iso 2>/dev/null | head -1)
if [ -z "$ISO" ]; then
    ISO=$(ls -t lb-live-*.iso 2>/dev/null | head -1)
fi
if [ -z "$ISO" ]; then
    echo "ERREUR : aucun ISO produit" >&2
    exit 1
fi

cp -v "$ISO" "$DIST_DIR/voila-${VERSION}-amd64.iso"
echo "ISO produit : $DIST_DIR/voila-${VERSION}-amd64.iso"
ls -la "$DIST_DIR/"
