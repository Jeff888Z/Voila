# VOILÀ — Handoff pour IA agents (Claude Code, Hermes, autres)

> **But** : ce fichier est le point de reprise pour toute session IA qui
> arrive à froid sur ce repo. Il contient tout le contexte nécessaire
> pour ne PAS avoir à tout ré-expliquer.
>
> **À METTRE À JOUR** en fin de session (avant `/clear` pour Claude
> Code, ou avant de fermer la session pour Hermes/Cursor/Copilot/etc.)
> avec les décisions prises, fichiers touchés, prochaines étapes.
>
> **Convention** : chaque section est datée. Les décisions sont
> explicables rétrospectivement (rationale). Les TODO sont testables.

---

## 0. Métadonnées du projet

| Champ | Valeur |
|---|---|
| **Nom** | VOILÀ |
| **Type** | Distribution Linux live, amnésique, anonyme par défaut |
| **Base** | Debian Live (live-build) sur bookworm |
| **Cible** | Clé USB / SSD M.2 externe, 4 Go RAM min, UEFI ou Legacy BIOS |
| **Repo** | `https://github.com/Jeff888Z/Voila` (compte perso Jeff) |
| **Org** | `JFR-Solutions` — N'héberge PAS le code (que les sites web) |
| **License** | MIT (Jeff © 2026) |
| **Site public** | https://jfrsolution.fr/voila (à venir) |
| **Modèle commercial** | open source gratuit + revente supports préinstallés à prix coûtant |
| **Mainteneur** | Jean-François (Jeff) — `dev@jfrsolution.fr` |
| **Sécu** | `security@jfrsolution.fr` (GPG recommandé) |

---

## 1. Environnement de l'opérateur (Jeff)

| Élément | Valeur |
|---|---|
| **Machine** | MacBook Pro fin 2011 / Ubuntu 24.04 Gnome Wayland / 16 Go RAM |
| **Usage** | Tourne 24/7, sert de backup pour Hermes |
| **Outils de build** | PAS de Docker / podman / QEMU / live-build installé localement |
| **Workhorse build** | **GitHub Actions** (cloud, survit à la machine) — `.github/workflows/build.yml` |
| **Comment flasher** | `sudo ./scripts/flash-iso.sh <iso>` — cherche clé label `NOMADE_DEEP` |
| **Comment récup l'ISO** | GH Actions → onglet Actions → run ✅ → artifact `voila-iso.zip` |
| **Tokens** | `~/Documents/.MP/env` (lettres côte-à-côte sur qwerty, PAS `.MD`) |
| **GitHub PAT** | clé `ghp_Ar...1x9u` (intitulé `voila-ci`) dans le fichier ci-dessus, perms 644 |
| **Style Jeff** | Direct, analytique, pas de cérémonie. OK = feu vert. Hands-on > doc. |
| **Langue** | français (réponses + code + commits) |

---

## 2. Architecture technique (résumé 1 page)

### 2.1 Couches
- **Boot** : GRUB UEFI + Legacy BIOS, ISO hybride (dd ou Rufus)
- **Système** : Debian bookworm minimal, xfce4 + lightdm
- **Anonymat** : Tor transparent proxy (iptables), DNS via Tor DNSPort 9053
- **Amnésie** : `/home`, `/tmp`, `/var/log`, `/var/tmp` en tmpfs. Swap masqué. MAC random.
- **Réseau** : NetworkManager + dispatcher pour ré-appliquer iptables à chaque event `up`

### 2.2 Hooks live-build (ordre d'exécution = nommage)
```
live-build-config/config/hooks/normal/
├── 0050-voila-keyboard-locale.hook.chroot   # Clavier AZERTY + locale FR au boot
├── 0100-voila-hardening.hook.chroot         # Tor iptables + tmpfs + AppArmor + user
└── 0150-voila-autologin.hook.chroot         # Autologin XFCE + wizard YAD + watcher
```

### 2.3 Premier boot — flow utilisateur
1. ISO boot → systemd → live-config (créé `user`/`voila`) → LightDM
2. **Autologin** sur `voila` (XFCE) — pas d'écran d'auth
3. Service `voila-first-boot.service` lance `/opt/voila/welcome-launcher.sh`
4. Lanceur attend XFCE, exécute `/opt/voila/welcome.sh` (wizard YAD)
5. Wizard propose : changer mdp / changer langue / changer clavier / quitter
6. Si mdp changé → `pkexec touch /var/lib/voila/pwd-changed` (sentinel)
7. `voila-shadow-watcher.path` détecte modif `/etc/shadow` → service supprime l'autologin

### 2.4 Boots suivants
- Si sentinel `/var/lib/voila/pwd-changed` existe → pas d'autologin, écran LightDM normal
- Sinon → autologin direct sur XFCE

---

## 3. Décisions structurantes (avec rationale)

### 3.1 Autologin au 1er boot, pas de mdp forcé
**Pourquoi** : `passwd -e voila` (expirer le mdp) + lightdm-gtk-greeter = boucle infinie
(PAM voit `sp_lstchg=0`, refuse la session, LightDM relance le greeter).
**Décision** : autologin XFCE + wizard graphique YAD post-boot, l'utilisateur
clique "Changer mdp" s'il veut. **Pour un live amnésique, aucune donnée à
protéger sur la machine**, donc pas de "lock obligatoire" — c'est de la
fausse sécurité qui coûte cher en UX.

### 3.2 Clavier FR + locale FR par défaut au boot
**Pourquoi** : un user qui démarre la clé en QWERTY ne peut pas taper son
nouveau mdp en AZERTY s'il n'a pas reconfiguré avant.
**Décision** : hook `0050` pose clavier `fr` AZERTY + locale `fr_FR.UTF-8`
directement dans le squashfs. Wizard permet de switcher si besoin.

### 3.3 Détection "mdp changé" par sentinel, pas par hash
**Pourquoi** : `mkpasswd -m sha-512 voila` regénère un sel aléatoire à
chaque appel, donc la comparaison de hash ne matche JAMAIS le hash de
`/etc/shadow` (sel fixe côté shadow).
**Décision** : sentinel explicite `/var/lib/voila/pwd-changed` posé par
le wizard après chpasswd réussi. Plus fiable, plus simple.

### 3.4 Polkit limité à 3 actions pour user `voila`
**Pourquoi** : première version avait `polkit.Result.YES` global pour
l'user voila (= sudo total). Trop permissif.
**Décision** : on autorise UNIQUEMENT `voila.welcome.passwd` et
`org.freedesktop.policykit.exec` pour l'user voila, rien d'autre.

---

## 4. Bugs résolus (historique)

| Date | Symptôme | Cause | Fix |
|---|---|---|---|
| 2026-06-06 | Boucle infinie login→"change mdp"→re-login | `passwd -e voila` met `sp_lstchg=0`, lightdm-gtk-greeter n'a pas de dialog, PAM refuse | Suppression `passwd -e`, autologin + wizard YAD (hook 0150) |
| 2026-06-06 | Wizard crashe dès qu'on clique Annuler | `set -e` + `return 1` dans boucle `while :` | `set -u` + `return 0` sur annulation, tous les yad en `\|\| true` |
| 2026-06-06 | Watcher ne détecte jamais le chgmt de mdp | `mkpasswd` regénère un sel, comparaison avec `/etc/shadow` échoue toujours | Remplacé par sentinel `/var/lib/voila/pwd-changed` posé explicitement |
| 2026-06-06 | Polkit trop permissif (sudo total pour voila) | `polkit.Result.YES` global | Restreint à 2 actions ciblées (passwd wrapper, exec) |

---

## 5. Workflow de dev (à suivre pour chaque modif)

### 5.1 Modification des hooks live-build
1. Éditer `live-build-config/config/hooks/normal/*.hook.chroot`
2. `cd ~/dev/voila && bash -n live-build-config/config/hooks/normal/<fichier>` (lint syntaxe)
3. `cd ~/dev/voila && make lint` (vérif tous les hooks + scripts bash)
4. **NE PAS tester en local** (pas de QEMU ni Docker). Tester en CI.

### 5.2 Build + test + flash
```bash
# 1. Commit + push
cd ~/dev/voila
git add -A
git commit -m "feat: ..."
git push origin master  # la CI build auto

# 2. Récupérer l'ISO depuis les artifacts
#    → https://github.com/Jeff888Z/Voila/actions
#    → dernier run ✅ → section "Artifacts" en bas → voila-iso.zip
# 3. Télécharger + décompresser
# 4. Vérifier SHA256
cd ~/Downloads && unzip voila-iso.zip && sha256sum -c voila-*.iso.sha256

# 5. Flasher
cd ~/dev/voila
sudo ./scripts/flash-iso.sh ~/Downloads/voila-*.iso
# Confirmer 2 fois. La cible doit être label "NOMADE_DEEP".
```

### 5.3 Release tag (publication publique)
```bash
git tag v0.1.1 -m "Release 0.1.1 — fix login loop"
git push origin v0.1.1
# CI build + publie la release sur GitHub
```

---

## 6. État actuel (au dernier edit)

**Branche** : `master`
**Dernier commit pertinent** : `842326a flash-iso.sh: get transport from parent device` (avant ce fix)
**Modifs locales non commitées** :
- `0100-voila-hardening.hook.chroot` — `passwd -e voila` viré
- `0050-voila-keyboard-locale.hook.chroot` — **NOUVEAU** (clavier FR + locale)
- `0150-voila-autologin.hook.chroot` — **NOUVEAU** (autologin + wizard + watcher)
- `package-lists/voila.list.chroot` — +yad, +whois, +polkitd, +console-setup, +keyboard-configuration
- `.gitignore` — +live-config_*.deb, +*.qcow2, +.tmp/

**À faire en sortant de cette session** :
- [ ] `git add -A && git commit -m "..."`
- [ ] `git push origin master`
- [ ] Attendre CI (~20-30 min)
- [ ] Télécharger artifact → tester sur MacBook Pro fin 2011
- [ ] `scripts/flash-iso.sh` sur la clé USB (label NOMADE_DEEP)
- [ ] Boot, vérifier autologin + wizard AZERTY

---

## 7. TODO / Roadmap

### v0.1.1 (en cours, post-fix-login-loop)
- [ ] Tester autologin + wizard sur matériel
- [ ] Vérifier que wizard YAD ne se déclenche qu'au 1er boot (pas à chaque reboot)
- [ ] Vérifier que mdp change bien désactive l'autologin
- [ ] Mettre à jour `FLASH.md` (mention wizard) — **FAIT en parallèle de ce handoff**
- [ ] Mettre à jour `CHANGELOG.md` — **FAIT en parallèle**
- [ ] Premier ISO de test
- [ ] Release v0.1.1-alpha

### v0.2
- [ ] Locale EN (clavier + langue) en plus de FR
- [ ] Persistance LUKS chiffrée sur 2e support
- [ ] Ollama préchargé avec llama3.2:3b
- [ ] Tests QEMU automatisés en CI (déjà un job QEMU smoke test 90s)

### v1.0
- [ ] Signature GPG JFR-Solutions
- [ ] Site jfrsolution.fr/voila en ligne
- [ ] Premier support préinstallé en vente
- [ ] Documentation multilingue (EN, ES)

### v2 (hors-scope v1)
- Build ARM64 (Raspberry Pi)
- Version serveur (Matrix auto-hébergé)
- App mobile VOILÀ (chat natif Android)
- Intégration Meshtastic (LoRa)

---

## 8. Pièges connus / "gotchas"

1. **`/etc/shadow` permissions** : `passwd` et `chpasswd` refusent de
   tourner dans un contexte sans CAP_AUDIT_WRITE (ex: conteneurs non
   privilégiés). Sur la machine de dev, ça ne fonctionne pas pour
   tester `chpasswd voila:voila`. Le hook `0100` tourne dans le chroot
   du build (root total), pas de problème.

2. **Apparmor en enforce peut casser PAM** : si PAM helpers sont
   bloqués par un profil strict, l'auth silencieusement échoue. Le
   hook `0100` fait `aa-enforce` sur tous les profils. À surveiller
   si le loop revient sans cause évidente.

3. **LightDM et `live-config` (Debian)** : live-config crée un user
   `user` (uid 1000, mdp `live`) PAR DÉFAUT et configure l'autologin
   sur cet user. Le hook `0150` doit **override** cette conf en
   imposant `autologin-user=voila` via le fichier
   `/etc/lightdm/lightdm.conf.d/99-voila-autologin.conf` (priorité sur
   le `lightdm.conf` global).

4. **YAD ne s'affiche pas si DISPLAY pas set** : le wrapper du wizard
   exporte `DISPLAY=:0` et `DBUS_SESSION_BUS_ADDRESS` avant chaque
   invocation. Si l'environnement est mal configuré, le dialog
   n'apparaît pas silencieusement (pollue stderr uniquement).

5. **Les fichiers avec apostrophes françaises** (`D'accord`,
   `L'image`, etc.) cassent `vision_analyze` (tool quirk). Si tu fais
   bosser une IA sur des screenshots de la UI, copie d'abord dans
   `/tmp/` avec un nom ASCII.

6. **live-build hooks = root total** : pas de `sudo`, pas de check
   permissions. Une commande `rm -rf /` tuerait le build. Toujours
   mettre des gardes.

---

## 9. Liens utiles

- **Repo** : https://github.com/Jeff888Z/Voila
- **Actions** : https://github.com/Jeff888Z/Voila/actions
- **Releases** : https://github.com/Jeff888Z/Voila/releases
- **Issues** : https://github.com/Jeff888Z/Voila/issues
- **Doc live-build** : https://live-team.pages.debian.net/live-manual/
- **Doc LightDM** : https://wiki.archlinux.org/title/LightDM
- **Doc YAD** : https://github.com/v1cont/yad
- **Spec Debian password aging** : `passwd(1)`, `chage(1)`, `sp_lstchg` dans `shadow(5)`

---

## 10. Mémoire de session (à updater à chaque session)

### Session 2026-06-06 — Jeff + Hermes (modèle minimax-m3)
- **Contexte initial** : Jeff se plaignait de la boucle d'auth sur la
  clé USB bootée. user=voila, mdp=voila, "change mdp", re-login, etc.
- **Diagnostic** : `passwd -e voila` dans hook `0100` met `sp_lstchg=0`,
  lightdm-gtk-greeter n'a pas de dialog pour changer le mdp, PAM refuse
  la session en boucle.
- **Fix appliqué** : suppression `passwd -e`, ajout hook 0050 (clavier
  FR + locale) et hook 0150 (autologin + wizard YAD + watcher sentinel).
- **3 bugs corrigés** : set -e cassait le wizard, polkit trop permissif,
  hash comparison cassée (mkpasswd sel aléatoire).
- **Décision UX** : autologin + wizard (pas de lock obligatoire sur
  live amnésique).
- **Pas testé** : pas de QEMU/Docker sur la machine, validation
  uniquement par lecture du code + lint bash -n.
- **Prochaine étape** : commit, push, attendre CI, télécharger ISO,
  flasher, tester.

---

> **Mainteneur** : penser à updater ce fichier en fin de session.
> **Format** : Markdown, sections datées, historique des décisions.
