# VOILÀ — Container de build
# Reproduit un environnement Debian propre pour générer l'ISO
# SPDX-License-Identifier: MIT

FROM debian:bookworm-slim

LABEL maintainer="JFR-Solutions <dev@jfrsolution.fr>"
LABEL description="VOILÀ ISO builder"

# Paquets nécessaires au build
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        live-build \
        debootstrap \
        xorriso \
        isolinux \
        syslinux-common \
        syslinux-utils \
        grub-pc-bin \
        grub-efi-amd64-bin \
        grub-efi-ia32-bin \
        grub-common \
        grub2-common \
        mtools \
        dosfstools \
        ca-certificates \
        gnupg \
        git \
        sudo \
    && rm -rf /var/lib/apt/lists/*

# Workspace
WORKDIR /build

# Lance le build
# Usage : docker build -t voila-builder .
#          docker run --rm -v $(pwd)/dist:/build/dist voila-builder
ENTRYPOINT ["bash", "/build/scripts/build-iso.sh"]
