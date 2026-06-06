# VOILÀ — Architecture technique v1

> **Statut** : spécification initiale (v0.1.0)
> **Date** : 2026-06-04
> **Auteur** : Jean-François (Jeff) — JFR-Solutions, assisté par Hermes Agent

---

## 1. Vision

**VOILÀ** est une distribution Linux **live, amnésique, anonyme par défaut**, destinée à être installée sur un support amovible (clé USB ou SSD M.2 externe) et à fournir un environnement de travail sécurisé et confidentiel, sans laisser de trace sur le support ni sur la machine hôte.

**Cible** : journalistes, avocats, notaires, associations, militants, et toute personne soucieuse de sa vie privée, en particulier dans un contexte de censure numérique étatique croissante.

**Modèle économique** : open source (MIT) + revente de supports préinstallés à prix coûtant via JFR-Solutions. Aucun composant n'est privateur. Le projet n'est pas commercialisé en tant que logiciel : seul le support physique l'est.

---

## 2. Modèle de menace

### Ce que VOILÀ protège

| Acteur | Scénario | Protection VOILÀ |
|---|---|---|
| **Fournisseur d'accès (FAI)** | Surveillance du trafic | Tout passe par Tor, FAI voit uniquement "connexion à un relais Tor" |
| **Surveillance WiFi public** | Hôtel, café, aéroport | Tor + chiffrement bout-en-bout, MAC randomisée |
| **Saisie de la machine** | On vous prend l'ordinateur | OS amnésique en RAM, aucune donnée sur disque |
| **Saisie du support** | On vous prend la clé USB | Idem, données chiffrées en RAM, key material éphémère |
| **Confiscation d'une machine tierce** | Vous branchez votre clé sur l'ordi d'un tiers | Système live, pas d'écriture sur l'hôte, pas de swap |

### Ce que VOILÀ NE protège PAS

- **Compromission matérielle de l'utilisateur** (keylogger physique, caméra cachée)
- **Ingénierie sociale** (on vous trompe pour que vous révéliez vos secrets)
- **Faille zero-day dans Tor** (VOILÀ dépend de Tor)
- **Attaque physique pendant que le système tourne** (Cold Boot Attack, possible mais coûteux)
- **Compromission de l'utilisateur final** (mauvaise configuration volontaire)

### Hypothèses de sécurité

- L'utilisateur suit la documentation (n'installe pas de paquets non vérifiés)
- Le matériel hôte est réputé fonctionnel (pas de firmware compromis)
- L'OS est démarré en mode UEFI **Secure Boot activé** (validation de la chaîne de boot)

---

## 3. Choix techniques

### 3.1 OS de base

**Décision** : **Debian Live + live-build**, pas Tails ni Voyager.

**Rationale** :
- Tails : audité, mature, mais **non-customisable légalement** (Tails interdit les forks non-officiels). Inadapté à la revente de supports préinstallés avec branding JFR-Solutions.
- Voyager Linux : léger, rapide, mais **pas conçu pour l'amnésie**. Aucune garantie sur les écritures disque.
- Debian Live + live-build : standard, **reproductible**, customisable 100%, base Debian stable (audité 25+ ans). On peut le signer avec notre clé GPG JFR-Solutions.

### 3.2 Réseau

**Décision** : **Tor transparent proxy obligatoire par défaut, VPN WireGuard maison en fallback optionnel**.

**Rationale** :
- Tor by default = meilleur équilibre anonymat / ergonomie
- Toggle au boot = risque d'erreur humaine, rejeté
- VPN maison = utile pour des usages spécifiques (perf, accès à un réseau domestique) mais **n'apporte pas d'anonymat supplémentaire** quand utilisé seul

**Implémentation** :
- `iptables` force tout le trafic à passer par le SOCKS proxy de Tor (port 9050)
- DNS intercepté par `dnsmasq` → résolu uniquement via Tor (`DNSPort 9053`)
- Le user ne peut pas bypass, même involontairement (par défaut)
- Mode "expert" : kill switch dans un script `/opt/voila/toggle-network.sh` (à documenter)

### 3.3 Amnésie et persistance

**Décision** : **Tout en tmpfs (RAM), pas de persistance par défaut, persistance chiffrée optionnelle sur second support**.

| Partition | Type | Contenu |
|---|---|---|
| `/` (système) | Squashfs (read-only, compressé) | OS complet, ~3 Go |
| `/home` | tmpfs (RAM, 2 Go max) | Données utilisateur éphémères |
| `/tmp` | tmpfs (RAM) | Fichiers temporaires |
| `/var/log` | tmpfs (RAM, effacé au boot) | Logs système |
| **Persistence** (optionnel) | LUKS chiffré sur **second** support USB | `/home/persistent/` monté à la demande |

**Swap** : désactivé (`systemctl mask swap.target`).

**Why not encrypted persistence on same USB ?**
- Si on chiffre `/home` sur le même USB, **la clé de chiffrement est aussi sur l'USB** → tout le monde peut l'extraire.
- Persistance = sur **deuxième support**, à garder physiquement séparé.

### 3.4 Stack applicative

| Catégorie | Application | Justification |
|---|---|---|
| Navigateur (en ligne) | **Tor Browser** | Standard, audité, plug-and-play |
| Navigateur (hors-ligne) | **Firefox ESR** | Pour docs locaux, .onion jamais contacté |
| Chat Internet | **Element** (Matrix) | E2E, décentralisé, on peut monter un serveur Matrix maison JFR |
| Chat Internet (alternatif) | **Signal Desktop** | Standard de fait pour le grand public |
| Chat offline (mesh) | **Briar** | Bluetooth/WiFi direct, **sans serveur, sans internet**, parfait pour la cible journaliste |
| LLM local | **Ollama** + **llama3.2:3b** | ~2 Go RAM, réponse correcte en français, anglais excellent |
| VPN | **WireGuard** | Léger, rapide, auditable |
| Bureautique | **LibreOffice** | Standard open source |
| Édition texte/code | **Vim** + **Nano** | Pour le cas où on doit éditer un fichier en urgence |
| Email | **Thunderbird** | Compatible Tor, support PGP intégré |
| Transfert fichiers | **Syncthing** | P2P, E2E, alternative à AirDrop |

### 3.5 Matériel cible

| Support | Avantage | Limite | Recommandation |
|---|---|---|---|
| Clé USB 3.2+ | Portable, ~10€ pour 64 Go | Lenteur en USB 2.0, write ~30 Mo/s | Usage basique, 64 Go minimum |
| SSD M.2 NVMe + boîtier USB-C | ~500 Mo/s en USB 3.2 Gen 2, démarrage éclair | ~40€ pour 256 Go | **Recommandé pour usage pro** |
| Carte SD | Compact, dans le portefeuille | Encore plus lent qu'USB 2.0 | Usage d'urgence |

**Configuration minimale** : 4 Go de RAM, CPU 64-bit, UEFI ou Legacy BIOS.
**Configuration recommandée** : 8+ Go de RAM (pour Ollama 3B confortable), SSD NVMe, UEFI.

---

## 4. Architecture logicielle

### 4.1 Process de build

```
Sources Debian (deb.debian.org)
       │
       ▼
debootstrap  → chroot Debian minimal
       │
       ├── Configuration système (live-build)
       │     - hostname, locale FR, clavier AZERTY
       │     - utilisateurs (user 'voila' sans sudo par défaut)
       │     - policies AppArmor strictes
       │
       ├── Installation paquets (live-build/package-lists/)
       │     - tor, wireguard, ollama
       │     - element-desktop, signal-desktop, briar
       │     - firefox-esr, thunderbird, libreoffice
       │     - vim, nano, htop
       │
       ├── Hooks post-install (live-build/config/hooks/)
       │     - 0100-network-hardening.sh (iptables, MAC random, dnsmasq)
       │     - 0200-amnesia.sh (tmpfs, swap off, /var/log tmpfs)
       │     - 0300-ollama-setup.sh (modèle par défaut, autostart)
       │     - 0400-branding.sh (logo, wallpapers, doc FR)
       │
       └── Squashfs + ISO bootable
              - GRUB UEFI + BIOS legacy
              - Signature GPG JFR-Solutions (Secure Boot)
              - ISO hybride (dd ou Rufus)
```

### 4.2 Process de boot

```
Boot (BIOS/UEFI)
       │
       ├── GRUB charge vmlinuz + initrd depuis USB/SSD
       │
       ├── initrd monte racine Squashfs en read-only
       │
       ├── systemd-tmpfiles crée tmpfs /home, /tmp, /var/log
       │
       ├── NetworkManager (config amnésique, MAC random)
       │
       ├── Tor démarre (tor@default.service)
       │
       ├── Script /opt/voila/hardening.sh :
       │     - iptables → force traffic via Tor
       │     - dnsmasq → DNS via Tor
       │     - kill switch activé
       │
       ├── Ollama (si activé) → charge llama3.2:3b
       │
       ├── LightDM démarre → AUTOLOGIN sur user 'voila'
       │     (via /etc/lightdm/lightdm.conf.d/99-voila-autologin.conf
       │      posé par le hook 0150 ; annulé au 2e boot si le sentinel
       │      /var/lib/voila/pwd-changed est présent)
       │
       └── XFCE démarre → service voila-first-boot.service lance
            le wizard YAD /opt/voila/welcome.sh qui propose :
              - changer le mdp (recommandé, mais pas obligatoire)
              - changer la langue du système
              - changer la disposition clavier
            Une fois le mdp changé, le sentinel pwd-changed est posé
            et voila-shadow-watcher.path désactive l'autologin pour
            les boots suivants. Au prochain boot, l'écran de login
            LightDM standard s'affiche.
```

### 4.3 Sécurité runtime

**Mode "panic"** : raccourci `Ctrl+Alt+P` → `systemctl poweroff --force` (pas de sync, pas de logs, extinction brutale pour minimiser la RAM dumpable).

**Mode "verrouillage"** : raccourci `Ctrl+Alt+L` → screensaver avec mot de passe obligatoire (évite qu'on accède à l'écran si on s'absente).

**Logs** : tout en tmpfs, **automatiquement effacés** au shutdown. Pas de forward syslog (impossible par design amnésique).

---

## 5. Distribution et packaging

### 5.1 Releases

| Canal | Format | Audience |
|---|---|---|
| GitHub Releases | `.iso` + `.sha256` + signature GPG | Technique |
| jfrsolution.fr/voila | `.iso` + guide téléchargement | Grand public |
| Supports physiques | Clé USB ou SSD M.2 préinstallés | Tout public |

### 5.2 Cycle de release

- **Release stable** : tous les 3 mois, après 2 semaines de RC
- **Release sécurité** : sous 7 jours si faille critique Tor/Debian/Ollama
- **Versioning** : semver (`MAJOR.MINOR.PATCH`)

### 5.3 CI/CD (GitHub Actions)

```yaml
# .github/workflows/build.yml (résumé)
on:
  push: { branches: [main] }
  schedule: { cron: '0 3 * * 0' }  # tous les dimanches 03:00 UTC
  workflow_dispatch:                # manuel

jobs:
  build:
    runs-on: ubuntu-24.04
    steps:
      - build: docker build + run, produit voila-*.iso
      - test: qemu boot, smoke test
      - sign: GPG sign
      - release: si tag v*, créer release avec .iso + .sha256
```

---

## 6. Roadmap v1.0

| Étape | Statut |
|---|---|
| Spec complète (ce document) | ✅ |
| Repo GitHub initialisé | ✅ ([Jeff888Z/Voila](https://github.com/Jeff888Z/Voila)) |
| Container Docker de build | ✅ (Dockerfile prêt, pas encore testé en CI) |
| Script hardening (Tor, MAC, tmpfs) | ✅ (hook 0100 unique, 6 ko, à tester) |
| Configuration live-build | ✅ (package-lists + hooks prêts) |
| GitHub Actions pour rebuilds auto | ✅ (workflow YAML prêt, scope `workflow` du PAT requis pour push) |
| Documentation utilisateur FR | ✅ (docs/user-guide/GUIDE.md, ~7 ko) |
| Premier ISO de test | ⏳ |
| Test sur MacBook 2011 (machine Jeff) | ⏳ |
| Site jfrsolution.fr/voila | ⏳ |
| Release v0.1.0 "alpha" | ⏳ (bloquée par premier ISO) |
| Support préinstallé en vente | ⏳ |
| Release v1.0 "stable" | 🎯 cible 2026-Q3 |

---

## 7. Hors-scope v1

Pour ne pas surcharger la v1, on reporte :
- Version serveur (Matrix auto-hébergé) → v2
- Application mobile VOILÀ (chat natif Android) → v2
- Intégration Meshtastic directe (hardware LoRa) → v2
- Builds ARM64 (Raspberry Pi) → v2
- Multi-langue (EN, ES) → v2
- Support GPU NVIDIA pour Ollama → v2

---

## 8. Crédits et licences

- **VOILÀ** : MIT, JFR-Solutions 2026
- **Base** : Debian (DFSG-free), live-build (GPL)
- **Apps** : toutes en licence libre (Tor MIT, WireGuard GPLv2, Ollama MIT, Element AGPLv3, Signal AGPLv3, Briar GPLv3)

---

**Mainteneur** : Jean-François — [dev@jfrsolution.fr](mailto:dev@jfrsolution.fr)
**Sécurité** : [security@jfrsolution.fr](mailto:security@jfrsolution.fr)
**Site** : [jfrsolution.fr/voila](https://jfrsolution.fr/voila)
