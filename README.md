# VOILÀ

> Système d'exploitation amnésique bootable sur USB/SSD M.2, conçu pour protéger la liberté d'expression et la vie privée.

**VOILÀ** est une distribution Linux live, amnésique (tout en RAM, aucune trace sur le support), bootable sur clé USB ou SSD M.2 externe. Pensée pour les journalistes, associations, avocats, et particuliers soucieux de leur vie privée, en particulier dans un contexte de censure numérique croissante.

---

## ✨ Caractéristiques

- **🔒 Amnésique** : tout en RAM, rien n'est écrit sur le support. Débranchez, éteignez : plus rien n'existe.
- **🧅 Anonymat par défaut** : tout le trafic passe par Tor, sans configuration.
- **💬 Communication sécurisée** : Element (Matrix), Signal, Briar (mesh Bluetooth/WiFi sans internet).
- **🤖 LLM local** : Ollama avec modèles 2-3B, utilisable hors-ligne.
- **🔐 VPN maison** : WireGuard préconfiguré (optionnel, pour quand Tor est trop lent).
- **🛡️ Sans trace** : swap désactivé, MAC randomisée, /home en tmpfs.
- **🪶 Léger** : fonctionne sur 4 Go de RAM minimum, idéal sur MacBook fin 2011 et machines modestes.

---

## 🎯 Pour qui ?

- **Journalistes** : protéger leurs sources et communications.
- **Associations / militants** : communiquer sans surveillance.
- **Avocats / notaires** : traiter des dossiers sensibles.
- **Particuliers** : naviguer et échanger en préservant leur vie privée.
- **Tous** : parce que la vie privée est un droit, pas un privilège.

---

## 🚀 Démarrage rapide (utilisateur)

1. Téléchargez la dernière release : [github.com/Jeff888Z/Voila/releases](https://github.com/Jeff888Z/Voila/releases)
2. Flashez l'ISO sur une clé USB (≥ 8 Go) ou un SSD M.2 externe (≥ 128 Go recommandé)
3. Bootez dessus (F12 / Option / Echap au démarrage de la machine)
4. Choisissez le mode "Anonyme" ou "Normal" (VPN)
5. Utilisez Element, Signal, Briar, Ollama selon vos besoins
6. **Éteignez et débranchez** : tout disparaît, aucune trace.

**Documentation complète** : [docs/user-guide/](docs/user-guide/)

> **Note** : le repo GitHub du projet est `Jeff888Z/Voila` (compte de
> Jean-François). L'organisation `JFR-Solutions` est utilisée pour
> l'hébergement de la page web, pas du code source.

---

## 🏗️ Build (développeur)

```bash
# Build de l'ISO (dans un container pour la reproductibilité)
docker build -t voila-builder docker/
docker run --rm -v "$(pwd)/dist:/dist" voila-builder

# Ou via GitHub Actions : voir .github/workflows/build.yml
```

**Prérequis** : Docker, 4 Go d'espace libre, 30 minutes de patience.

---

## 📐 Architecture

Voir [docs/specs/ARCHITECTURE.md](docs/specs/ARCHITECTURE.md) pour le détail complet.

**Stack** :
- **Base** : Debian Live (live-build)
- **Hardening** : Tor transparent proxy, MAC randomisation, tmpfs sur /home, swap désactivé
- **Chat** : Element (Matrix), Signal Desktop, Briar
- **LLM local** : Ollama (llama3.2 3B par défaut)
- **VPN** : WireGuard (config client fournie)
- **Bureautique** : LibreOffice, Firefox (Tor Browser quand en ligne)

---

## 🤝 Contribution

Le projet est **open source** (licence MIT) et accepte les contributions :
- Bugs / issues : ouvrez un ticket
- Améliorations : fork + PR
- Traductions : docs/ est en français, toute aide pour l'anglais/multilingue bienvenue
- Tests : essayez sur votre matériel, remontez les bugs

---

## 🛒 Supports préinstallés

Vous préférez recevoir une clé USB ou SSD M.2 avec VOILÀ déjà flashé ?
**Disponible à prix coûtant** sur [jfrsolution.fr/voila](https://jfrsolution.fr/voila).
(Le projet lui-même reste 100% gratuit et open source.)

---

## ⚖️ Licence

MIT — voir [LICENSE](LICENSE).

## 🔐 Sécurité

Pour signaler une faille de sécurité : **security@jfrsolution.fr** (chiffré GPG recommandé, clé publique dans le repo).

---

**JFR-Solutions** — [jfrsolution.fr](https://jfrsolution.fr)
"Des outils, pas des armes."
