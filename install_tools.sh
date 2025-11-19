#!/bin/bash

# ==============================================================================
# MODERN UNIX STACK INSTALLER
# Adapte l'installation selon l'OS (Debian/Ubuntu, Fedora, Arch) et l'ARCH (x86, ARM)
# ==============================================================================

set -e # Arrête le script en cas d'erreur

# Couleurs pour les logs
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}[INFO] $1${NC}"; }
log_success() { echo -e "${GREEN}[OK] $1${NC}"; }
log_error() { echo -e "${RED}[ERROR] $1${NC}"; }

# 1. DÉTECTION DE L'ENVIRONNEMENT
# ==============================================================================
ARCH=$(uname -m)
OS=""
DISTRO=""

if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO=$ID
fi

case $ARCH in
    x86_64)
        log_info "Architecture détectée : x86_64"
        GITHUB_ARCH="x86_64"
        ;;
    aarch64)
        log_info "Architecture détectée : ARM64"
        GITHUB_ARCH="arm64"
        ;;
    *)
        log_error "Architecture $ARCH non supportée par ce script auto."
        exit 1
        ;;
esac

# Vérification des droits root
if [ "$EUID" -ne 0 ]; then 
  log_error "S'il vous plaît, lancez ce script avec sudo."
  exit 1
fi

# 2. INSTALLATION DES DÉPENDANCES DE BASE
# ==============================================================================
log_info "Mise à jour des paquets de base..."

install_common() {
    # Outils de base nécessaires pour télécharger/extraire
    PACKAGES="curl wget git tar unzip fuse"
    
    # Outils souvent présents dans les dépôts officiels en version correcte
    # ncdu, btop, jq, ripgrep, fzf
    # Note: bat et fd ont souvent des noms bizarres (batcat, fdfind) sur Debian
    
    if [[ "$DISTRO" == "ubuntu" || "$DISTRO" == "debian" || "$DISTRO" == "pop" ]]; then
        apt-get update -y
        apt-get install -y $PACKAGES ncdu btop jq ripgrep fzf fd-find bat
        
        # Fix pour Ubuntu : mapping des noms
        if ! command -v fd &> /dev/null; then ln -s $(which fdfind) /usr/local/bin/fd; fi
        if ! command -v bat &> /dev/null; then ln -s $(which batcat) /usr/local/bin/bat; fi

    elif [[ "$DISTRO" == "fedora" ]]; then
        dnf install -y $PACKAGES ncdu btop jq ripgrep fzf fd-find bat

    elif [[ "$DISTRO" == "arch" || "$DISTRO" == "manjaro" ]]; then
        pacman -Sy --noconfirm $PACKAGES ncdu btop jq ripgrep fzf fd bat
    fi
}

install_common

# 3. INSTALLATION MANUELLE DES OUTILS MODERNES (Pour avoir la dernière version)
# ==============================================================================
INSTALL_DIR="/usr/local/bin"

# Fonction générique pour récupérer la dernière release GitHub
# Usage: install_from_github "user/repo" "filtre_grep" "nom_binaire"
install_from_github() {
    REPO=$1
    FILTER=$2
    BINARY_NAME=$3
    
    log_info "Installation de $BINARY_NAME depuis $REPO..."

    # Récupérer l'URL de la dernière release
    LATEST_URL=$(curl -s "https://api.github.com/repos/$REPO/releases/latest" | \
        grep "browser_download_url" | \
        grep -i "$FILTER" | \
        grep -i "$GITHUB_ARCH" | \
        grep -v "sha" | \
        cut -d '"' -f 4 | head -n 1)

    if [ -z "$LATEST_URL" ]; then
        log_error "Impossible de trouver l'URL pour $BINARY_NAME ($REPO). Vérifiez l'architecture."
        return
    fi

    TEMP_DIR=$(mktemp -d)
    FILENAME=$(basename "$LATEST_URL")
    
    curl -L -o "$TEMP_DIR/$FILENAME" "$LATEST_URL"

    # Extraction intelligente
    if [[ "$FILENAME" == *.tar.gz ]]; then
        tar -xzf "$TEMP_DIR/$FILENAME" -C "$TEMP_DIR"
    elif [[ "$FILENAME" == *.zip ]]; then
        unzip -q "$TEMP_DIR/$FILENAME" -d "$TEMP_DIR"
    fi

    # Recherche du binaire et déplacement
    FIND_BIN=$(find "$TEMP_DIR" -type f -name "$BINARY_NAME" | head -n 1)
    if [ -n "$FIND_BIN" ]; then
        mv "$FIND_BIN" "$INSTALL_DIR/$BINARY_NAME"
        chmod +x "$INSTALL_DIR/$BINARY_NAME"
        log_success "$BINARY_NAME installé avec succès."
    else
        log_error "Binaire non trouvé dans l'archive pour $BINARY_NAME"
    fi

    rm -rf "$TEMP_DIR"
}

# --- EZA (Remplacement ls) ---
# Eza est complexe à installer via binaire simple (dépendances libgit2). 
# On préfère la méthode officielle gpg pour Debian/Ubuntu si possible, sinon cargo.
if [[ "$DISTRO" == "ubuntu" || "$DISTRO" == "debian" ]]; then
    mkdir -p /etc/apt/keyrings
    wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc | gpg --dearmor -o /etc/apt/keyrings/gierens.gpg
    echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de/stable/ ./" | tee /etc/apt/sources.list.d/gierens.list
    chmod 644 /etc/apt/keyrings/gierens.gpg /etc/apt/sources.list.d/gierens.list
    apt-get update && apt-get install -y eza
elif [[ "$DISTRO" == "fedora" ]]; then
    dnf install -y eza
elif [[ "$DISTRO" == "arch" ]]; then
    pacman -S --noconfirm eza
else
    # Fallback binaire (peut échouer selon libs)
    install_from_github "eza-community/eza" "linux-gnu" "eza"
fi

# --- LAZY TOOLS & HELIX & YAZI ---
# Ces outils sont distribués proprement en binaires statiques (Go/Rust)

# LazyGit
install_from_github "jesseduffield/lazygit" "Linux" "lazygit"

# LazyDocker
install_from_github "jesseduffield/lazydocker" "Linux" "lazydocker"

# LazySQL
install_from_github "jorgerojas26/lazysql" "linux" "lazysql"

# Helix (Editeur)
install_from_github "helix-editor/helix" "linux" "hx"
# Note: Helix a besoin de ses fichiers runtime. 
# Pour une install propre via script simple, on télécharge l'AppImage si dispo ou on avertit.
# Ici on a pris le binaire, mais il manquera le dossier 'runtime'.
# Correction pour Helix : Installation via AppImage pour simplicité ou Package Manager si dispo.
if ! command -v hx &> /dev/null; then
    log_info "Tentative installation Helix via PPA/Dépôt (plus fiable pour le runtime)..."
    if [[ "$DISTRO" == "ubuntu" ]]; then
        add-apt-repository -y ppa:maveonair/helix-editor
        apt update && apt install -y helix
    fi
fi

# Yazi (File Manager)
# Yazi est très récent, binaire direct recommandé
install_from_github "sxyazi/yazi" "linux-musl" "yazi"


# 4. CONFIGURATION SHELL (ALIASES)
# ==============================================================================
log_info "Génération des suggestions de configuration..."

CONFIG_TEXT=$(cat <<EOF

# --- MODERN UNIX ALIASES ---
# Ajoutez ceci à votre .bashrc ou .zshrc

# ls -> eza
alias ls='eza --icons --group-directories-first'
alias ll='eza -alF --icons --group-directories-first'
alias tree='eza --tree --icons'

# cat -> bat
alias cat='bat'

# find -> fd
# (fd est déjà court, mais pour mémoire)
alias findfast='fd'

# grep -> rg
alias grep='rg'

# Navigation
alias fm='yazi'
alias lg='lazygit'
alias ld='lazydocker'
alias lsql='lazysql'
alias hx='helix'

# Utils
alias usage='ncdu --color dark -rr -x --exclude .git --exclude node_modules'

EOF
)

echo "----------------------------------------------------------------"
echo -e "${GREEN}INSTALLATION TERMINÉE !${NC}"
echo "----------------------------------------------------------------"
echo "Pour activer les outils, ajoutez les lignes suivantes à votre fichier ~/.bashrc ou ~/.zshrc :"
echo "$CONFIG_TEXT"
echo "----------------------------------------------------------------"
