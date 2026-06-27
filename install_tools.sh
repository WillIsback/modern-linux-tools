#!/bin/bash

# ==============================================================================
# MODERN LINUX TOOLKIT INSTALLER
# Installs a curated set of modern CLI tools on Linux
# Supports: Debian/Ubuntu, Fedora, Arch Linux
# Architectures: x86_64, aarch64
# ==============================================================================

set -euo pipefail

GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }

# ==============================================================================
# ENVIRONMENT DETECTION
# ==============================================================================
ARCH=$(uname -m)
DISTRO=""
DISTRO_LIKE=""

if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO=$ID
    DISTRO_LIKE=${ID_LIKE:-}
fi

case "$ARCH" in
    x86_64)  log_info "Detected architecture: x86_64" ;;
    aarch64) log_info "Detected architecture: ARM64 (aarch64)" ;;
    *)
        log_error "Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

if [ "$EUID" -ne 0 ]; then
    log_error "Please run this script with sudo."
    exit 1
fi

# ==============================================================================
# PACKAGE MANAGER HELPERS
# ==============================================================================
pm_install() {
    case "$DISTRO" in
        ubuntu|debian|pop|linuxmint|elementary)
            DEBIAN_FRONTEND=noninteractive apt-get install -y "$@"
            ;;
        fedora|rhel|centos)
            dnf install -y "$@"
            ;;
        arch|manjaro|endeavouros)
            pacman -Sy --noconfirm "$@"
            ;;
        *)
            if echo "$DISTRO_LIKE" | grep -qi "debian\|ubuntu"; then
                DEBIAN_FRONTEND=noninteractive apt-get install -y "$@"
            elif echo "$DISTRO_LIKE" | grep -qi "fedora\|rhel\|centos"; then
                dnf install -y "$@"
            elif echo "$DISTRO_LIKE" | grep -qi "arch"; then
                pacman -Sy --noconfirm "$@"
            else
                log_warn "Unknown distro ($DISTRO), cannot install: $*"
                return 1
            fi
            ;;
    esac
}

pm_update() {
    case "$DISTRO" in
        ubuntu|debian|pop|linuxmint|elementary)
            apt-get update -y || true
            ;;
        fedora|rhel|centos)
            dnf check-update || true
            ;;
        arch|manjaro|endeavouros)
            pacman -Sy --noconfirm
            ;;
        *)
            if echo "$DISTRO_LIKE" | grep -qi "debian\|ubuntu"; then
                apt-get update -y || true
            fi
            ;;
    esac
}

is_debian_like() {
    [[ "$DISTRO" =~ ^(ubuntu|debian|pop|linuxmint|elementary)$ ]] || echo "$DISTRO_LIKE" | grep -qi "debian\|ubuntu"
}

is_fedora_like() {
    [[ "$DISTRO" =~ ^(fedora|rhel|centos)$ ]] || echo "$DISTRO_LIKE" | grep -qi "fedora\|rhel\|centos"
}

is_arch_like() {
    [[ "$DISTRO" =~ ^(arch|manjaro|endeavouros)$ ]] || echo "$DISTRO_LIKE" | grep -qi "arch"
}

# ==============================================================================
# BASE DEPENDENCIES
# ==============================================================================
log_info "Installing base dependencies..."

pm_update

# Common tools required everywhere
BASE_DEPS="curl wget git tar unzip gpg ca-certificates"

if is_debian_like; then
    pm_install $BASE_DEPS xz-utils software-properties-common
elif is_fedora_like; then
    pm_install $BASE_DEPS xz
elif is_arch_like; then
    pm_install $BASE_DEPS xz
fi

# Verify essential tools are available
for cmd in curl wget tar unzip gpg; do
    if ! command -v "$cmd" &>/dev/null; then
        log_error "Essential tool '$cmd' is missing after install attempt."
        exit 1
    fi
done

log_success "Base dependencies ready."

# ==============================================================================
# GITHUB RELEASE INSTALLER
# ==============================================================================
INSTALL_DIR="/usr/local/bin"

install_from_github() {
    local repo="$1"
    local filter="$2"
    local binary_name="$3"
    local needs_runtime="${4:-false}"

    log_info "Installing $binary_name from $repo..."

    # Arch filter: some projects use "x86_64"/"aarch64", others "x86_64"/"arm64"
    local arch_filter
    if [ "$ARCH" = "x86_64" ]; then
        arch_filter="x86_64|amd64"
    else
        arch_filter="(aarch64|arm64)"
    fi

    local api_response
    api_response=$(curl -sfL "https://api.github.com/repos/$repo/releases/latest" 2>/dev/null || true)

    if [ -z "$api_response" ]; then
        log_warn "Could not reach GitHub API for $repo. Check your internet connection. Skipping."
        return 1
    fi

    local download_url
    download_url=$(echo "$api_response" \
        | grep "browser_download_url" \
        | grep -iE "$filter" \
        | grep -iE "$arch_filter" \
        | grep -viE 'no_libgit|-dbg-|-debug-' \
        | grep -vE '\.(sha256|sha512|asc|sig|sum)$' \
        | grep -v 'sha256sum' \
        | cut -d '"' -f 4 \
        | head -n 1)

    if [ -z "$download_url" ]; then
        log_warn "Could not find a matching download for $binary_name (filter: $filter, arch: $ARCH). Skipping."
        return 1
    fi

    local tmpdir
    tmpdir=$(mktemp -d)
    local filename
    filename=$(basename "$download_url")

    log_info "  Downloading $filename..."
    curl -#fL -o "$tmpdir/$filename" "$download_url" || {
        log_warn "Download failed for $binary_name. Skipping."
        rm -rf "$tmpdir"
        return 1
    }

    case "$filename" in
        *.tar.xz)
            tar -xJf "$tmpdir/$filename" -C "$tmpdir"
            ;;
        *.tar.gz|*.tgz)
            tar -xzf "$tmpdir/$filename" -C "$tmpdir"
            ;;
        *.zip)
            unzip -qo "$tmpdir/$filename" -d "$tmpdir"
            ;;
        *.deb)
            log_info "  Installing .deb package directly..."
            dpkg -i "$tmpdir/$filename" 2>/dev/null || {
                log_warn "Direct .deb install failed, extracting binary..."
                mkdir -p "$tmpdir/deb_extract"
                dpkg-deb -x "$tmpdir/$filename" "$tmpdir/deb_extract"
                local bin_path
                bin_path=$(find "$tmpdir/deb_extract" -type f -name "$binary_name" 2>/dev/null | head -n 1)
                if [ -n "$bin_path" ]; then
                    cp "$bin_path" "$INSTALL_DIR/$binary_name"
                    chmod +x "$INSTALL_DIR/$binary_name"
                    log_success "$binary_name extracted from .deb to $INSTALL_DIR/$binary_name"
                fi
            }
            rm -rf "$tmpdir"
            return 0
            ;;
        *)
            log_warn "Unknown archive format: $filename. Skipping $binary_name."
            rm -rf "$tmpdir"
            return 1
            ;;
    esac

    local binary_path
    binary_path=$(find "$tmpdir" -type f -name "$binary_name" 2>/dev/null | head -n 1)

    if [ -n "$binary_path" ]; then
        cp "$binary_path" "$INSTALL_DIR/$binary_name"
        chmod +x "$INSTALL_DIR/$binary_name"
        log_success "$binary_name installed to $INSTALL_DIR/$binary_name"
    else
        log_warn "Binary '$binary_name' not found inside the extracted archive."
        ls -la "$tmpdir" 2>/dev/null | head -5
        rm -rf "$tmpdir"
        return 1
    fi

    # Install runtime support directory if requested (e.g., helix runtime/ tree)
    if [ "$needs_runtime" = "true" ]; then
        local runtime_src
        runtime_src=$(find "$tmpdir" -type d -name "runtime" 2>/dev/null | head -n 1)
        if [ -n "$runtime_src" ]; then
            mkdir -p "/usr/lib/$binary_name"
            cp -r "$runtime_src" "/usr/lib/$binary_name/"
            log_success "Runtime files installed to /usr/lib/$binary_name/runtime"
        else
            log_warn "No 'runtime' directory found for $binary_name."
        fi
    fi

    rm -rf "$tmpdir"
}

# ==============================================================================
# TOOL INSTALLATION
# ==============================================================================

# --- EZA (modern ls replacement) ---
if command -v eza &>/dev/null; then
    log_success "eza already installed."
elif is_debian_like; then
    log_info "Installing eza from official repository..."
    mkdir -p /etc/apt/keyrings
    wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc 2>/dev/null | gpg --dearmor -o /etc/apt/keyrings/gierens.gpg 2>/dev/null || {
        log_warn "eza GPG key import failed. Falling back to binary install."
        install_from_github "eza-community/eza" "linux-gnu" "eza"
    }
    if [ -f /etc/apt/keyrings/gierens.gpg ]; then
        echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] https://deb.gierens.de/ stable main" \
            | tee /etc/apt/sources.list.d/gierens.list > /dev/null
        chmod 644 /etc/apt/keyrings/gierens.gpg /etc/apt/sources.list.d/gierens.list
        apt-get update 2>/dev/null && apt-get install -y eza 2>/dev/null && log_success "eza installed." \
            || { log_warn "eza repo install failed. Removing repo and falling back to binary."; rm -f /etc/apt/sources.list.d/gierens.list; install_from_github "eza-community/eza" "linux-gnu" "eza"; }
    fi
elif is_fedora_like; then
    pm_install eza 2>/dev/null && log_success "eza installed." \
        || { log_warn "eza package not found in repos. Trying binary..."; install_from_github "eza-community/eza" "linux-gnu" "eza"; }
elif is_arch_like; then
    pm_install eza && log_success "eza installed."
else
    install_from_github "eza-community/eza" "linux-gnu" "eza"
fi

# --- REPO-BASED TOOLS (ncdu, btop, jq, ripgrep, fzf, fd, bat) ---
if is_debian_like; then
    log_info "Installing repo-based tools..."
    pm_install ncdu btop jq ripgrep fzf fd-find bat
    # Debian/Ubuntu ship fd as fdfind and bat as batcat
    command -v fd &>/dev/null || command -v fdfind &>/dev/null && ln -sf "$(which fdfind)" /usr/local/bin/fd || true
    command -v bat &>/dev/null || command -v batcat &>/dev/null && ln -sf "$(which batcat)" /usr/local/bin/bat || true
elif is_fedora_like; then
    pm_install ncdu btop jq ripgrep fzf fd-find bat
elif is_arch_like; then
    pm_install ncdu btop jq ripgrep fzf fd bat
fi

# --- HELIX EDITOR ---
if command -v hx &>/dev/null; then
    log_success "Helix (hx) already installed."
else
    install_from_github "helix-editor/helix" "linux" "hx" "true"
fi

if command -v hx &>/dev/null; then
    HELIX_RUNTIME=$(hx --health 2>/dev/null | grep "runtime" | head -1 || echo "")
    if echo "$HELIX_RUNTIME" | grep -qi "not found\|missing\|error"; then
        if [ -d "/usr/lib/hx/runtime" ]; then
            export HELIX_RUNTIME=/usr/lib/hx/runtime
            log_info "Set HELIX_RUNTIME=/usr/lib/hx/runtime"
        fi
    fi
fi

# --- LAZYGIT ---
install_from_github "jesseduffield/lazygit" "Linux" "lazygit"

# --- LAZYDOCKER ---
install_from_github "jesseduffield/lazydocker" "Linux" "lazydocker"

# --- LAZYSQL ---
install_from_github "jorgerojas26/lazysql" "Linux" "lazysql"

# --- YAZI (terminal file manager) ---
# Prefer .deb on Debian/Ubuntu, otherwise use musl zip
if is_debian_like; then
    install_from_github "sxyazi/yazi" "linux-gnu" "yazi"
else
    install_from_github "sxyazi/yazi" "linux-musl" "yazi"
fi

# ==============================================================================
# SUMMARY & SHELL CONFIGURATION
# ==============================================================================
echo ""
echo "================================================================"
echo -e "${GREEN}INSTALLATION COMPLETE${NC}"
echo "================================================================"
echo ""

installed_list=""
for tool in eza hx lazygit lazydocker lazysql yazi ncdu btop jq rg fzf fd bat; do
    if command -v "$tool" &>/dev/null; then
        installed_list+="  ${GREEN}✓${NC} $tool\n"
    else
        installed_list+="  ${RED}✗${NC} $tool\n"
    fi
done
echo -e "$installed_list"

echo ""
echo "To enable the new tools, add these aliases to ~/.bashrc or ~/.zshrc:"
echo ""
cat <<'CONFIG_EOF'
# --- MODERN LINUX ALIASES ---
alias ls='eza --icons --group-directories-first'
alias ll='eza -alF --icons --group-directories-first'
alias tree='eza --tree --icons'
alias cat='bat'
alias grep='rg'
alias fm='yazi'
alias lg='lazygit'
alias ld='lazydocker'
alias usage='ncdu --color dark -rr -x --exclude .git --exclude node_modules'
CONFIG_EOF
echo ""
echo "Then run: source ~/.bashrc"
echo "================================================================"
