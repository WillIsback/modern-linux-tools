# Modern Linux Toolkit Installer

A simple, fast, and cross-distro shell script to set up a new Linux system with a curated collection of modern, efficient, and productive command-line tools.

This script automatically detects your distribution and architecture to install the latest versions of the tools, preferring official package managers where possible and falling back to direct binary downloads from GitHub for the very latest releases.

## Tools Included

| Tool | Description | Replacement For | Installation Method |
| :--- | :--- | :--- | :--- |
| **[Eza](https://github.com/eza-community/eza)** | A modern replacement for `ls` with more features and better defaults. | `ls` | Package Manager / Binary |
| **[Bat](https://github.com/sharkdp/bat)** | A `cat` clone with syntax highlighting and Git integration. | `cat` | Package Manager |
| **[fd](https://github.com/sharkdp/fd)** | A simple, fast, and user-friendly alternative to `find`. | `find` | Package Manager |
| **[Ripgrep](https://github.com/BurntSushi/ripgrep)** | A line-oriented search tool that recursively searches your current directory for a regex pattern. | `grep` | Package Manager |
| **[fzf](https://github.com/junegunn/fzf)** | A general-purpose command-line fuzzy finder. | `Ctrl+R` | Package Manager |
| **[btop](https://github.com/aristocratos/btop)** | A resource monitor that shows usage and stats for processor, memory, disks, network, and processes. | `htop` | Package Manager |
| **[ncdu](https://dev.yorhel.nl/ncdu)** | A disk usage analyzer with an ncurses interface. | `du` | Package Manager |
| **[jq](https://github.com/jqlang/jq)** | A lightweight and flexible command-line JSON processor. | `grep`/`sed`/`awk` for JSON | Package Manager |
| **[Lazygit](https://github.com/jesseduffield/lazygit)** | A simple terminal UI for git commands. | - | Latest GitHub Release |
| **[Lazydocker](https://github.com/jesseduffield/lazydocker)** | A terminal UI for Docker and Docker-Compose, written in Go with gocui. | - | Latest GitHub Release |
| **[LazySQL](https://github.com/jorgerojas26/lazysql)** | A cross-platform TUI database management tool. | - | Latest GitHub Release |
| **[Helix](https://github.com/helix-editor/helix)** | A post-modern modal text editor inspired by Neovim/Kakoune. | `vim`/`nano` | Package Manager / Binary |
| **[Yazi](https://github.com/sxyazi/yazi)** | A blazingly fast terminal file manager, written in Rust. | `ranger`/`nnn` | Latest GitHub Release |

## Compatibility

The script is designed to be compatible with the following systems:

- **Distributions**:
  - Debian
  - Ubuntu (& Pop!_OS)
  - Fedora
  - Arch Linux (& Manjaro)
- **Architectures**:
  - `x86_64`
  - `aarch64` (ARM64)

## Prerequisites

1.  A compatible Linux distribution as listed above.
2.  **Root privileges** (`sudo` access) are required to run the script.
3.  `curl` or `wget` must be installed to download the script.

## Usage

You can download and run the script with a single command. This will install all the tools system-wide in `/usr/local/bin`.

```bash
curl -sL https://raw.githubusercontent.com/WillIsback/modern-linux-tools/main/install_tools.sh | sudo bash
```
*Note: Remember to replace `YOUR_USERNAME/YOUR_REPO` with your actual GitHub repository path once published.*

## Post-Installation: Configuration

This script does **not** modify your shell configuration files automatically.

After the installation is complete, a list of recommended aliases will be printed to your terminal. To activate the new tools and use them as replacements for their classic counterparts, copy and paste the provided block into your shell's configuration file (e.g., `~/.bashrc`, `~/.zshrc`), then restart your shell or source the file (e.g., `source ~/.bashrc`).

### Recommended Aliases

```bash
# --- MODERN UNIX ALIASES ---
# Add this to your .bashrc or .zshrc

# ls -> eza
alias ls='eza --icons --group-directories-first'
alias ll='eza -alF --icons --group-directories-first'
alias tree='eza --tree --icons'

# cat -> bat
alias cat='bat'

# find -> fd
# (fd is already short, but for memory)
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
```

## Contributing

Contributions are welcome! If you'd like to add a new tool, improve compatibility, or fix a bug, please feel free to open an issue or submit a pull request.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
