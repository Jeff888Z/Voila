#!/bin/bash
# VOILÀ — Script de flash ISO sur clé USB
# SPDX-License-Identifier: MIT
#
# Usage: ./flash-iso.sh <path-to-iso>
# Exemple: ./flash-iso.sh ~/Downloads/voila-2026.06.05-amd64.iso
#
# Comportement :
#   1. Vérifie l'ISO (existe, lisible, SHA256)
#   2. Détecte automatiquement la clé NOMADE_DEEP (par label)
#   3. Affiche un récap et demande confirmation explicite
#   4. dd avec bs=4M, conv=fsync, status=progress
#   5. Sync + eject
#
# PRÉCAUTIONS :
#   - On flashe of=/dev/sdX (le disque entier), PAS /dev/sdX1
#   - Le label NOMADE_DEEP doit être sur la partition principale
#   - Le script ABANDONNE si une autre machine / un autre OS est détecté
#   - NE JAMAIS flasher sur /dev/nvme0n1 ou /dev/sda (disques système)

set -euo pipefail

readonly ISO_PATH="${1:?Usage: $0 <path-to-iso>}"
readonly TARGET_LABEL="NOMADE_DEEP"
readonly ISO_MIN_SIZE_MB=400  # 700 Mo attendu pour un Debian Live minimal
readonly ISO_MAX_SIZE_MB=2500 # Live complet avec cache apt embarqué peut atteindre 2 Go

# === COULEURS (sortie terminal) ===
readonly RED=$'\033[0;31m'
readonly GREEN=$'\033[0;32m'
readonly YELLOW=$'\033[0;33m'
readonly BLUE=$'\033[0;34m'
readonly BOLD=$'\033[1m'
readonly NC=$'\033[0m'

# === FONCTIONS UTILITAIRES ===
die() { echo "${RED}✗ $*${NC}" >&2; exit 1; }
info() { echo "${BLUE}ℹ $*${NC}"; }
ok() { echo "${GREEN}✓ $*${NC}"; }
warn() { echo "${YELLOW}⚠ $*${NC}"; }
hr() { echo "────────────────────────────────────────────────────────────"; }

# === 1. VÉRIFICATIONS PRÉLIMINAIRES ===
hr
info "VOILÀ — Flash ISO sur clé USB"
hr

# root ?
[ "$(id -u)" -eq 0 ] || die "Ce script doit être lancé en root : sudo $0 $*"

# ISO existe ?
[ -f "$ISO_PATH" ] || die "ISO introuvable : $ISO_PATH"
[ -r "$ISO_PATH" ] || die "ISO non lisible : $ISO_PATH (problème de permissions ?)"

# Taille ISO raisonnable ?
ISO_SIZE_MB=$(du -m "$ISO_PATH" | cut -f1)
[ "$ISO_SIZE_MB" -ge "$ISO_MIN_SIZE_MB" ] && [ "$ISO_SIZE_MB" -le "$ISO_MAX_SIZE_MB" ] \
    || die "Taille ISO anormale (${ISO_SIZE_MB} Mo) : attendu entre $ISO_MIN_SIZE_MB et $ISO_MAX_SIZE_MB Mo"
ok "ISO valide : $ISO_PATH (${ISO_SIZE_MB} Mo)"

# Outils requis
for cmd in lsblk dd sha256sum sync eject; do
    command -v "$cmd" >/dev/null 2>&1 || die "Outil manquant : $cmd (installer avec apt)"
done

# === 2. VÉRIFICATION SHA256 ===
# On cherche le .sha256 à côté de l'ISO
SHA_FILE="${ISO_PATH}.sha256"
if [ -f "$SHA_FILE" ]; then
    info "Vérification du SHA256..."
    EXPECTED=$(cat "$SHA_FILE" | awk '{print $1}')
    ACTUAL=$(sha256sum "$ISO_PATH" | awk '{print $1}')
    if [ "$EXPECTED" = "$ACTUAL" ]; then
        ok "SHA256 OK : $ACTUAL"
    else
        die "SHA256 mismatch !
Attendu : $EXPECTED
Obtenu   : $ACTUAL
L'ISO est corrompue, ne pas flasher."
    fi
else
    warn "Pas de fichier $SHA_FILE trouvé, vérification SHA256 ignorée"
    warn "(vous pouvez le générer avec : sha256sum $ISO_PATH > $SHA_FILE)"
fi

# === 3. DÉTECTION DE LA CLÉ CIBLE ===
hr
info "Recherche de la clé '$TARGET_LABEL'..."

# lsblk -n -o NAME,LABEL,SIZE,MODEL,TRAN
# Note: NAME n'a PAS le préfixe /dev/ par défaut, on l'ajoute
TARGET_DEV=""
while IFS= read -r line; do
    # Parser chaque ligne (skip header éventuel)
    name=$(echo "$line" | awk '{print $1}')
    label=$(echo "$line" | awk '{print $2}')
    size=$(echo "$line" | awk '{print $3}')
    model=$(echo "$line" | awk '{print $4}')
    tran=$(echo "$line" | awk '{print $5}')

    # Filtrer uniquement les périphériques de type block (sd*, nvme*, mmc*)
    # Note: lsblk affiche les enfants avec ├─ ou └─ en préfixe
    clean_name=$(echo "$name" | sed -E 's/^[├└─]+//')
    case "$clean_name" in
        /dev/sd*|/dev/nvme*|/dev/mmc*|sd*|nvme*|mmc*) :;;
        *) continue ;;
    esac

    if [ "$label" = "$TARGET_LABEL" ]; then
        # Le device parent (sans le numéro de partition)
        # sdc1 → sdc, /dev/sdc1 → /dev/sdc
        # nvme0n1p1 → nvme0n1, /dev/nvme0n1p1 → /dev/nvme0n1
        full_name="/dev/$clean_name"
        parent=$(echo "$full_name" | sed -E 's|/dev/(sd[a-z]+)[0-9]+|/dev/\1|; s|/dev/(nvme[0-9]+n[0-9]+)p[0-9]+|/dev/\1|')
        echo "  Trouvé : $full_name ($label, $size, $model, transport=$tran) → parent=$parent"
        TARGET_DEV="$parent"
        break
    fi
done < <(lsblk -n -o NAME,LABEL,SIZE,MODEL,TRAN 2>/dev/null)

if [ -z "$TARGET_DEV" ]; then
    die "Aucune clé avec le label '$TARGET_LABEL' trouvée.
Étapes :
  1. Branche ta clé USB
  2. Vérifie son label : lsblk -o NAME,LABEL,MOUNTPOINT
  3. Si elle a pas ce label, rebranche-la (le label sera mis par mkfs après reformat)
  4. Relance ce script"
fi

# Récupérer les infos complètes du device parent
lsblk "$TARGET_DEV" -o NAME,SIZE,MODEL,TRAN,ROTA | sed 's/^/  /'

# === 4. SÉCURITÉS ANTI-DISQUE-SYSTÈME ===
hr
warn "SÉCURITÉS :"

# Refus de flasher sur des devices "système" probables
case "$TARGET_DEV" in
    /dev/nvme0n1) die "REFUS : $TARGET_DEV ressemble à un disque système NVMe. Abandon.";;
    /dev/sda)     die "REFUS : $TARGET_DEV (premier disque SATA) est typiquement le disque système. Abandon.";;
esac

# Vérifier que la cible est bien sur USB (pas NVMe, pas SATA interne)
TRANSPORT=$(lsblk -n -o TRAN "$TARGET_DEV" | tail -1)
case "$TRANSPORT" in
    usb) ok "Device sur bus USB : OK";;
    mmc) ok "Device sur bus MMC (carte SD) : OK";;
    *)  die "Device sur $TRANSPORT (ni USB, ni MMC). Pour éviter tout risque, on refuse.
Si tu sais ce que tu fais, force manuellement avec : dd if=$ISO_PATH of=$TARGET_DEV bs=4M status=progress conv=fsync";;
esac

# === 5. DÉMONTAGE DES PARTITIONS MONTÉES ===
hr
info "Démontage des partitions de $TARGET_DEV..."
# Démonte tout ce qui est sur ce device
mount | grep "^$TARGET_DEV" | awk '{print $1}' | while read -r mp; do
    info "  Démontage de $mp"
    umount "$mp" 2>/dev/null || warn "    (impossible de démonter $mp, peut-être occupé)"
done

# === 6. CONFIRMATION UTILISATEUR (2 SÉCURITÉS) ===
hr
echo "${BOLD}RÉCAPITULATIF${NC}"
echo "  ISO source : $ISO_PATH (${ISO_SIZE_MB} Mo)"
echo "  Cible      : $TARGET_DEV (label=$TARGET_LABEL, transport=$TRANSPORT)"
echo "  Action     : dd if=... of=$TARGET_DEV bs=4M (efface TOUT sur la clé)"
echo ""
echo "${RED}${BOLD}⚠  CECI EFFACE DÉFINITIVEMENT TOUTES LES DONNÉES SUR $TARGET_DEV ⚠${NC}"
echo ""
read -r -p "Tape 'OUI' (en majuscules) pour confirmer : " CONFIRM1
[ "$CONFIRM1" = "OUI" ] || { info "Annulé par l'utilisateur"; exit 0; }

read -r -p "Confirme une 2e fois en tapant le label exact '$TARGET_LABEL' : " CONFIRM2
[ "$CONFIRM2" = "$TARGET_LABEL" ] || { info "Annulé (label incorrect)"; exit 0; }

# === 7. FLASH ===
hr
info "Flash en cours (ça peut prendre 2-5 min)..."
echo ""
dd if="$ISO_PATH" of="$TARGET_DEV" bs=4M status=progress conv=fsync
sync

# === 8. VÉRIFICATION POST-FLASH ===
hr
ok "Flash terminé !"
info "Vérification post-flash..."
lsblk "$TARGET_DEV" -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINT | sed 's/^/  /'

# Eject (le user peut maintenant débrancher)
if command -v eject >/dev/null; then
    info "Éjection..."
    eject "$TARGET_DEV" 2>/dev/null || warn "  (éjection logicielle impossible, débranche manuellement)"
fi

hr
ok "VOILÀ est flashé sur $TARGET_DEV !"
info "Pour booter dessus :"
info "  - Mac Intel (MacBook Pro 2011) : touche Option (⌥) au boot"
info "  - MSI Gaming / PC : touche F12 au boot"
info "  - Mac Apple Silicon (M4) : maintenir le bouton power au boot"
info ""
info "⚠ N'OUBLIE PAS : pour re-formater ta clé après test :"
info "    sudo mkfs.ext4 -L NOMADE_DEEP $TARGET_DEV"
