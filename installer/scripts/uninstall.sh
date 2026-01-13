#!/usr/bin/env bash
#
# HYDRA 10.0 Uninstaller for Linux and macOS
#

set -e

INSTALL_DIR="${HYDRA_HOME:-$HOME/.hydra}"

echo "HYDRA 10.0 Uninstaller"
echo "======================"
echo ""
echo "This will remove:"
echo "  - $INSTALL_DIR"
echo "  - Shell profile entries"
echo ""

read -p "Are you sure? [y/N] " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

# Remove installation directory
if [ -d "$INSTALL_DIR" ]; then
    echo "Removing $INSTALL_DIR..."
    rm -rf "$INSTALL_DIR"
fi

# Clean shell profiles
for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
    if [ -f "$rc" ]; then
        # Remove HYDRA section
        sed -i.bak '/# HYDRA 10.0 Environment/,/^$/d' "$rc" 2>/dev/null || true
        echo "Cleaned $rc"
    fi
done

echo ""
echo "HYDRA has been uninstalled."
echo "Note: Ollama and its models were not removed."
echo "To remove Ollama: sudo rm -rf /usr/local/bin/ollama ~/.ollama"
