# VOILÀ — Guide utilisateur (FR)

> **VOILÀ** v0.1.0-alpha — guide d'utilisation
> Pour la dernière version : [github.com/Jeff888Z/Voila](https://github.com/Jeff888Z/Voila)

---

## 🎯 En 30 secondes

1. Branchez votre clé VOILÀ ou SSD M.2 sur la machine
2. Allumez et appuyez sur **F12** (ou Option sur Mac) pour choisir le boot
3. Sélectionnez "VOILÀ"
4. **C'est tout.** Vous êtes sur un système anonyme, amnésique, sécurisé.

---

## 📦 Ce dont vous avez besoin

### Matériel
- **Clé USB** : 8 Go minimum, USB 3.0+ recommandé, 64 Go idéal
- OU **SSD M.2** dans un boîtier USB-C (256 Go+, ~500 Mo/s)
- Une machine compatible : PC/Mac/Linux, UEFI ou Legacy BIOS, 4 Go RAM minimum
- Connexion Internet (Tor s'en chargera, pas besoin de configurer)

### Logiciel pour flasher
- **Linux** : `dd` ou Balena Etcher (https://etcher.balena.io)
- **macOS** : Balena Etcher
- **Windows** : Rufus (https://rufus.ie) ou Balena Etcher

⚠️ **Attention** : flasher efface TOUT le contenu du support. Utilisez une clé ou SSD dédié, pas celui où vous avez vos données.

---

## 🚀 Installation

### Étape 1 : Télécharger l'ISO

Rendez-vous sur [github.com/Jeff888Z/Voila/releases](https://github.com/Jeff888Z/Voila/releases) et téléchargez la dernière version stable :
- `voila-X.Y.Z-amd64.iso` (l'image)
- `voila-X.Y.Z-amd64.iso.sha256` (la somme de contrôle)

**Vérification** (recommandé) :
```bash
sha256sum voila-X.Y.Z-amd64.iso
# Comparez avec le contenu de voila-X.Y.Z-amd64.iso.sha256
# Les deux hash doivent être identiques
```

### Étape 2 : Flasher le support

**Avec Balena Etcher** (recommandé pour les débutants) :
1. Téléchargez Etcher sur https://etcher.balena.io
2. Sélectionnez l'ISO
3. Sélectionnez votre clé USB ou SSD
4. Cliquez "Flash"
5. Attendez (5-15 min selon le support)

**Avec `dd` en ligne de commande** (Linux/macOS) :
```bash
# Trouvez le device de votre clé (ex: /dev/sdb)
lsblk

# ⚠️ ATTENTION : remplacez /dev/sdX par le bon device
sudo dd if=voila-X.Y.Z-amd64.iso of=/dev/sdX bs=4M status=progress conv=fsync
sync
```

### Étape 3 : Premier boot

1. **Éteignez** complètement la machine (pas de veille/hibernation)
2. Branchez votre support VOILÀ
3. Allumez et appuyez sur la touche de boot menu :
   - **PC** : F12 (Dell), F9 (HP), F2 (Lenovo), Echap (Asus)
   - **Mac** : touche **Option** (⌥) au démarrage
4. Sélectionnez votre support dans la liste
5. Le boot prend 15-30 secondes

### Étape 4 : Connexion WiFi (si pas en Ethernet)

Une fois sur le bureau, cliquez sur l'icône réseau en haut à droite :
- Sélectionnez votre réseau WiFi
- Entrez le mot de passe
- Tor se lance automatiquement

Pour vérifier que Tor fonctionne :
- Ouvrez Tor Browser
- Allez sur https://check.torproject.org
- Vous devez voir "Congratulations. This browser is configured to use Tor."

---

## 💬 Utilisation

### Chat sécurisé

| Application | Usage | Connexion |
|---|---|---|
| **Element** (Matrix) | Chat E2E, salons, fichiers | Internet (via Tor) |
| **Signal** | Messages/textos/appels E2E | Internet (via Tor) |
| **Briar** | Chat **sans internet** (mesh Bluetooth/WiFi) | Pair à pair |

**Briar** est particulièrement utile : il marche même sans réseau, juste avec quelqu'un à proximité (10-30m en Bluetooth, ~100m en WiFi).

### LLM local (Ollama)

Un assistant IA tourne localement, **sans envoyer vos questions sur internet** :
- Ouvrez un terminal
- Tapez : `ollama run llama3.2:3b`
- Posez votre question
- Pour quitter : `/bye`

**Limites** : c'est un petit modèle 3B, donc les réponses sont basiques. Pour des tâches complexes, mieux vaut un humain ou un modèle cloud.

### Bureautique

- **LibreOffice** : traitement de texte, tableur, présentations
- **GIMP** : retouche d'images
- **Thunderbird** : email (PIM/IMAP, compatible Tor)

---

## 🔐 Sécurité au quotidien

### ✅ À faire

- **Changer le mot de passe** de l'utilisateur `voila` au premier login (le système vous le demandera)
- **Vérifier Tor** avant toute activité sensible (https://check.torproject.org)
- **Utiliser Briar** pour les conversations vraiment sensibles
- **Éteindre complètement** la machine quand vous avez fini (pas de veille)
- **Débrancher le support** quand vous quittez

### ❌ À ne PAS faire

- **Ne jamais installer de paquet** non vérifié (compromet l'amnésie)
- **Ne pas se logger sur un compte nominatif** pendant une session sensible (Twitter, Facebook, etc.)
- **Ne pas ouvrir de pièce jointe Word/PDF** venant d'une source inconnue
- **Ne pas laisser la machine sans surveillance** en mode déverrouillé (utilisez Ctrl+Alt+L)
- **Ne pas mettre de données sensibles** dans `/home/persistent/` sans avoir bien compris les implications

### 🆘 Mode panique

**Raccourci** : `Ctrl+Alt+P`

**Effet** : extinction immédiate, sans sync, sans log, sans délai. La RAM se vide, plus rien ne reste.

À utiliser si quelqu'un entre dans la pièce et que vous n'avez pas le temps d'éteindre proprement.

---

## 🔄 Persistance des données (optionnel)

Par défaut, VOILÀ est **100% amnésique** : tout disparaît à l'extinction.

Si vous avez besoin de **conserver des données** entre sessions :

1. Procurez-vous une **deuxième** clé USB ou SSD (différent de celui où VOILÀ est installé)
2. Branchez-le après le boot
3. Montez-le : `sudo mount /dev/sdX1 /mnt/persistent`
4. Créez vos fichiers dans `/mnt/persistent/`
5. **Démontez** : `sudo umount /mnt/persistent`
6. Débranchez

**Pour chiffrer ce second support** (fortement recommandé) :
```bash
sudo cryptsetup luksFormat /dev/sdX
sudo cryptsetup open /dev/sdX monsupport
sudo mkfs.ext4 /dev/mapper/monsupport
```

---

## 🛒 Acheter un support préinstallé

Vous n'êtes pas à l'aise avec le flash ? Commandez un support VOILÀ prêt à l'emploi sur [jfrsolution.fr/voila](https://jfrsolution.fr/voila) :
- Clé USB 64 Go préinstallée
- SSD M.2 256 Go préinstallé
- Mise à jour à chaque nouvelle release (service optionnel)

**Prix** : à prix coûtant (pas de marge, c'est un service public).

---

## ❓ Problèmes fréquents

### Le support ne boot pas

- Vérifiez que le **Secure Boot est activé** dans le BIOS/UEFI
- Essayez de **désactiver le Secure Boot** (certains vieux BIOS sont capricieux)
- Sur Mac : réinitialisez la NVRAM (Cmd+Option+P+R au démarrage)

### Tor ne se connecte pas

- Cliquez sur l'icône réseau en haut à droite
- Sélectionnez un autre **bridge Tor** : Paramètres réseau → Tor → Use bridge → `obfs4`
- Si ça échoue toujours : essayez depuis un autre réseau WiFi

### Le LLM (Ollama) est très lent

- Les modèles 3B tournent lentement sur CPU, c'est normal
- Pour améliorer : installez un **SSD M.2 NVMe** au lieu d'une clé USB
- Réduisez la taille du contexte : `ollama run llama3.2:3b --ctx-size 2048`

### J'ai perdu mon mot de passe

C'est l'amnésie : redémarrez, le mot de passe par défaut est `voila` / `voila` (changement obligatoire au premier login).

---

## 📞 Support

- **Bugs** : [github.com/Jeff888Z/Voila/issues](https://github.com/Jeff888Z/Voila/issues)
- **Sécurité** : security@jfrsolution.fr (chiffré GPG recommandé)
- **Commercial** : contact@jfrsolution.fr

---

**VOILÀ** est un projet open source (licence MIT) de **JFR-Solutions**.
"Des outils, pas des armes."
