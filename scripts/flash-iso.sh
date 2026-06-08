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
# On matche sur le transport USB (exclure sata/nvme pour éviter de flasher
# un disque système). Le label ISO 9660 contient des caractères non-ASCII
# mal décodés par lsblk (double encodage UTF-8), donc inutilisable pour
# identifier la clé de manière fiable. Le TRAN=usb est stable et sûr.
readonly TARGET_TRANSPORT="usb"
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
info "Recherche de la clé USB (transport=$TARGET_TRANSPORT)..."

# lsblk -n -o NAME,LABEL,SIZE,MODEL,TRAN
# Note: NAME n'a PAS le préfixe /dev/ par défaut, on l'ajoute
TARGET_DEV=""
TARGET_SIZE=""
TARGET_MODEL=""
# lsblk --json est plus robuste que le parsing colonne d'awk, qui casse
# quand le label contient des caractères non-ASCII (ex: "VOILÀ" en iso9660).
# On utilise un fichier temp pour éviter le subshell du pipe (qui masquerait
# les assignations de variables au shell parent).
TEMP_RESULT=$(lsblk -J -o NAME,LABEL,SIZE,MODEL,TRAN 2>/dev/null | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)
for dev in data.get('blockdevices', []):
    tran = (dev.get('tran') or '').strip()
    name = (dev.get('name') or '').strip()
    if tran != 'usb':
        continue
    label = (dev.get('label') or '').strip()
    size = (dev.get('size') or '').strip()
    model = (dev.get('model') or '').strip()
    print(f'{name}|{label}|{size}|{model}|{tran}')
")
while IFS='|' read -r name label size model tran; do
    [ -z "$name" ] && continue
    # Filtrer uniquement les périphériques de type block (sd*, nvme*, mmc*)
    clean_name=$(echo "$name" | sed -E 's/^[├└─]+//')
    case "$clean_name" in
        /dev/sd*|/dev/nvme*|/dev/mmc*|sd*|nvme*|mmc*) :;;
        *) continue ;;
    esac

    full_name="/dev/$clean_name"
    parent=$(echo "$full_name" | sed -E 's|/dev/(sd[a-z]+)[0-9]+|/dev/\1|; s|/dev/(nvme[0-9]+n[0-9]+)p[0-9]+|/dev/\1|')
    # Récupérer le transport du PARENT (pas de l'enfant qui est souvent vide)
    found_tran=$(lsblk -n -d -o TRAN "$parent" 2>/dev/null | head -1 | tr -d ' ')
    if [ "$found_tran" != "$TARGET_TRANSPORT" ]; then
        continue
    fi
    echo "  Trouvé : $full_name ($label, $size, $model, transport=$found_tran) → parent=$parent"
    TARGET_DEV="$parent"
    TARGET_TRAN="$found_tran"
    TARGET_SIZE="$size"
    TARGET_MODEL="$model"
    break
done <<< "$TEMP_RESULT"

if [ -z "$TARGET_DEV" ]; then
    die "Aucune clé USB détectée.
Étapes :
  1. Branche ta clé USB
  2. Vérifie qu'elle apparaît : lsblk -o NAME,TRAN,SIZE,MODEL
  3. La colonne TRAN doit indiquer 'usb' (pas 'sata' ni 'nvme')
  4. Relance ce script"
fi

# Récupérer les infos complètes du device parent (le tran du parent est correct,
# celui de l'enfant est souvent vide dans la sortie lsblk)
TRANSPORT=$(lsblk -n -o TRAN "$TARGET_DEV" 2>/dev/null | head -1 | tr -d ' ')
if [ -z "$TRANSPORT" ]; then
    TRANSPORT=$(lsblk -n -d -o TRAN "$TARGET_DEV" 2>/dev/null | head -1 | tr -d ' ')
fi
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
TRANSPORT="${TARGET_TRAN:-}"
case "$TRANSPORT" in
    usb) ok "Device sur bus USB : OK";;
    mmc) ok "Device sur bus MMC (carte SD) : OK";;
    *)  die "Device sur '$TRANSPORT' (ni USB, ni MMC). Pour éviter tout risque, on refuse.
Si tu sais ce que tu fais, force manuellement avec : sudo dd if=$ISO_PATH of=$TARGET_DEV bs=4M status=progress conv=fsync";;
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
echo "  Cible      : $TARGET_DEV (taille=$TARGET_SIZE, modèle=$TARGET_MODEL, transport=$TRANSPORT)"
echo "  Action     : dd if=... of=$TARGET_DEV bs=4M (efface TOUT sur la clé)"
echo ""
# Confirmations : on lit depuis stdin (toujours), ce qui permet à la fois
# le mode interactif (l'utilisateur tape) ET le mode scripté (pipe via printf).
# En mode interactif, le shell bind le TTY à stdin automatiquement.
echo "${RED}${BOLD}⚠  CECI EFFACE DÉFINITIVEMENT TOUTES LES DONNÉES SUR $TARGET_DEV ⚠${NC}"
echo ""
read -r -p "Tape 'OUI' (en majuscules) pour confirmer : " CONFIRM1
[ "$CONFIRM1" = "OUI" ] || { info "Annulé par l'utilisateur"; exit 0; }

read -r -p "Confirme une 2e fois en tapant la taille exacte '$TARGET_SIZE' : " CONFIRM2
[ "$CONFIRM2" = "$TARGET_SIZE" ] || { info "Annulé (taille incorrecte)"; exit 0; }

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
