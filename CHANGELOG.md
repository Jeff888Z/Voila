# Changelog

Toutes les modifications notables de VOILÀ sont documentées ici.
Format inspiré de [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/).

## [Unreleased]

### Fixed
- **Login loop au 1er boot** (bug critique) : `passwd -e voila` mettait
  `sp_lstchg=0` dans `/etc/shadow`, ce que lightdm-gtk-greeter ne sait
  pas gérer (pas de dialog intégré pour changer le mdp), d'où une boucle
  infinie "login → demande mdp → PAM refuse → re-login". Remplacé par
  un autologin XFCE + wizard graphique YAD post-boot qui propose le
  changement de mdp/locale/clavier. Fix détaillé dans `HANDOFF.md §3.1`.

### Added
- Hook `0050-voila-keyboard-locale.hook.chroot` : clavier AZERTY et
  locale `fr_FR.UTF-8` par défaut au boot (sinon XFCE démarrait en
  QWERTY anglais).
- Hook `0150-voila-autologin.hook.chroot` : autologin LightDM sur
  `voila` + wizard YAD `/opt/voila/welcome.sh` (change mdp, langue,
  clavier) + service `voila-shadow-watcher.path` qui désactive
  l'autologin quand le sentinel `/var/lib/voila/pwd-changed` est posé.
- Paquets ajoutés : `yad` (wizard), `whois` (mkpassmd), `polkitd`,
  `console-setup`, `keyboard-configuration`.
- Fichier `HANDOFF.md` à la racine : contexte complet pour IA agents
  (Claude Code, Hermes, autres). À mettre à jour en fin de session.

### Changed
- Hook `0100-voila-hardening.hook.chroot` : ligne `passwd -e voila`
  supprimée (cause du loop). Création user `voila` avec mdp par défaut
  `voila` conservée.

### En cours
- Specs d'architecture (ARCHITECTURE.md)
- Script de build Docker (live-build)
- Hardening script (Tor transparent proxy, MAC random, tmpfs)
- Configuration GitHub Actions pour rebuilds auto
- Documentation utilisateur FR

## [0.1.0] - 2026-06-04

### Added
- Initialisation du projet
- README et LICENSE (MIT)
- Structure de répertoires

[Unreleased]: https://github.com/Jeff888Z/Voila/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/Jeff888Z/Voila/releases/tag/v0.1.0
