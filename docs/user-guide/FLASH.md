# VOILÀ — Guide de flash sur clé USB

> Comment récupérer l'ISO de VOILÀ et la flasher sur une clé USB pour booter dessus.

## 📥 Étape 1 : Télécharger l'ISO

Va sur https://github.com/Jeff888Z/Voila/actions

1. Clique sur le dernier run de workflow **build** qui est ✅ (vert)
2. Tout en bas, dans la section **Artifacts**, télécharge `voila-iso.zip`
3. Décompresse :
   ```bash
   cd ~/Downloads
   unzip voila-iso.zip
   ls -la
   # Tu dois voir : voila-X.Y.Z-amd64.iso  +  voila-X.Y.Z-amd64.iso.sha256
   ```

## ✅ Étape 2 : Vérifier le SHA256

**Recommandé fortement** : vérifier que l'ISO n'a pas été corrompue pendant le download.

```bash
cd ~/Downloads
sha256sum voila-X.Y.Z-amd64.iso
# Compare avec le contenu de voila-X.Y.Z-amd64.iso.sha256
cat voila-X.Y.Z-amd64.iso.sha256
```

Les deux hash doivent être **identiques**. Si non, retélécharge.

## 🔍 Étape 3 : Préparer ta clé USB

### Matériel requis

- **Clé USB** : 8 Go minimum (16+ Go recommandé), USB 3.0+
  - Plus la clé est rapide, plus le boot est rapide
  - Une **SSD M.2 NVMe dans un boîtier USB-C** est encore mieux (~500 Mo/s)
- La clé sera **intégralement effacée** : sauvegarde les données importantes d'abord

### Identifier ta clé sous Linux

```bash
lsblk -o NAME,SIZE,MODEL,TRAN,LABEL
```

Tu vas voir un truc du genre :
```
sda      223,6G  KINGSTON SA400S37240G  sata            <- ton SSD système, NE PAS TOUCHER
├─sda1       1G
└─sda2   222,5G
sdb      465,8G  TOSHIBA MK5065GSXF     sata            <- ton DD stockage, NE PAS TOUCHER
└─sdb1   465,8G
sdc      232,9G  Ultra                  usb   NOMADE_DEEP  ← TA CLÉ USB
└─sdc1   232,9G
```

**Repère bien le device** (ici `sdc`) et vérifie :
- Le **transport** est `usb` ou `mmc` (pas `sata` ou `nvme`)
- La **taille** correspond à ta clé
- Le **label** (si tu en as mis un) est visible

⚠️ **Règle d'or** : ne flashe JAMAIS sur `/dev/sda` ou `/dev/nvme0n1` (tes disques système).

## 🚀 Étape 4 : Flasher (méthode recommandée)

**Méthode sûre** : utiliser le script `flash-iso.sh` fourni par le projet.

```bash
cd ~/dev/voila
sudo ./scripts/flash-iso.sh ~/Downloads/voila-X.Y.Z-amd64.iso
```

Le script va :
1. ✅ Vérifier que l'ISO existe et a une taille cohérente
2. ✅ Vérifier le SHA256 (si le fichier .sha256 est à côté)
3. ✅ Détecter automatiquement la clé cible **par son label** (`NOMADE_DEEP` par défaut)
4. ✅ Vérifier que la cible est bien sur USB (pas un disque système)
5. ⚠️ Te demander **2 confirmations** avant d'écrire
6. ✅ Flasher avec `dd` + `sync`
7. ✅ Éjecter la clé proprement

Si ta clé n'a pas le label `NOMADE_DEEP`, le script refusera et te dira comment faire.

### Personnaliser le label cible

Si ta clé s'appelle autrement (par ex. `VIEILLE_CLE`), tu peux le préciser :

```bash
# Méthode 1 : éditer le script
sed -i 's/NOMADE_DEEP/VIEILLE_CLE/' scripts/flash-iso.sh

# Méthode 2 : renommer ta clé (avant de flasher)
sudo e2label /dev/sdc1 VIEILLE_CLE   # pour ext4
```

## 🚀 Étape 4bis : Flasher (méthode manuelle)

Si tu ne veux pas utiliser le script, voici les commandes manuelles :

```bash
# 1. Démonter la clé (si montée automatiquement)
sudo umount /dev/sdc1
sudo umount /dev/sdc  # au cas où il y aurait d'autres partitions

# 2. dd : flasher l'ISO sur le DISQUE ENTIER (pas la partition !)
# ⚠️ Bien mettre /dev/sdc, PAS /dev/sdc1
sudo dd if=~/Downloads/voila-X.Y.Z-amd64.iso of=/dev/sdc bs=4M status=progress conv=fsync

# 3. Synchroniser
sudo sync

# 4. Éjecter proprement
sudo eject /dev/sdc
```

⏱️ **Durée** : 2-5 min sur USB 3.0, 10-15 min sur USB 2.0.

## 💻 Étape 5 : Booter sur la clé

1. **Éteindre** complètement ta machine (pas de veille/hibernation)
2. **Brancher** la clé VOILÀ
3. **Allumer** et appuyer sur la touche de boot menu :

| Machine | Touche |
|---|---|
| MacBook Pro (Intel, 2011) | **Option (⌥)** |
| MacBook Air M4 (Apple Silicon) | **Maintenir le bouton power** au démarrage |
| MSI / PC Custom | **F12** (boot menu) ou **DEL** (BIOS) |
| Lenovo ThinkPad | **F12** |
| Dell | **F12** |
| HP | **F9** |
| Asus | **Echap** |

4. **Sélectionner** ta clé USB dans la liste (souvent "UEFI: ..." ou "USB: ...")
5. Le boot prend **15-30 secondes**

## 🔐 Étape 6 : Premier login

Une fois sur le bureau XFCE :

- **Utilisateur** : `voila`
- **Mot de passe par défaut** : `voila` (changement **obligatoire** au premier login)
- Connexion WiFi via l'icône réseau en haut à droite
- **Tor** démarre tout seul

### Vérifier que Tor fonctionne

1. Ouvre **Tor Browser** (raccourci sur le bureau)
2. Va sur https://check.torproject.org
3. Tu dois voir : **"Congratulations. This browser is configured to use Tor."**

## 🛒 Étape 7 : Re-formater ta clé après test

Quand tu n'as plus besoin de VOILÀ sur la clé (par ex. tu veux récupérer tes 256 Go) :

```bash
# Reformater en ext4 (Linux only)
sudo mkfs.ext4 -L NOMADE_DEEP /dev/sdc1
sudo mount /dev/sdc1 /mnt/nomade
```

Pour rendre la clé **compatible Windows + Mac + Linux** : formate en **exFAT** :
```bash
sudo mkfs.exfat -L NOMADE_DEEP /dev/sdc1
```

## ❓ Problèmes fréquents

### La clé n'apparaît pas dans le boot menu

- Vérifie que le **Secure Boot est désactivé** dans le BIOS/UEFI
- Sur Mac : réinitialise la NVRAM (Cmd+Option+P+R au démarrage)

### Tor ne se connecte pas

- Clique sur l'icône réseau → sélectionne ton WiFi
- Si ça bloque : **Paramètres réseau → Tor → Use bridge → `obfs4`**
- Teste depuis un autre WiFi si possible

### L'ISO ne boote pas (kernel panic, écran noir)

- Vérifie le SHA256 (cf. étape 2)
- Retélécharge l'ISO, possible corruption
- Teste sur une autre machine pour isoler

## 📞 Support

- **Bugs** : https://github.com/Jeff888Z/Voila/issues
- **Sécurité** : security@jfrsolution.fr (chiffré GPG recommandé)
- **Commercial** : contact@jfrsolution.fr

---

**VOILÀ** est un projet open source (licence MIT) de **JFR-Solutions**.
*"Des outils, pas des armes."*
