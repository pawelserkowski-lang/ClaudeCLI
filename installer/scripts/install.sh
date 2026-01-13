#!/usr/bin/env bash
#
# HYDRA 10.0 Installer for Linux and macOS
# Usage: curl -fsSL https://raw.githubusercontent.com/.../install.sh | bash
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Config
HYDRA_VERSION="10.0"
INSTALL_DIR="${HYDRA_HOME:-$HOME/.hydra}"
REPO_URL="https://github.com/pawelserkowski-lang/claudecli"
BRANCH="master"

# Banner
echo -e "${MAGENTA}"
cat << 'EOF'

    ██╗  ██╗██╗   ██╗██████╗ ██████╗  █████╗
    ██║  ██║╚██╗ ██╔╝██╔══██╗██╔══██╗██╔══██╗
    ███████║ ╚████╔╝ ██║  ██║██████╔╝███████║
    ██╔══██║  ╚██╔╝  ██║  ██║██╔══██╗██╔══██║
    ██║  ██║   ██║   ██████╔╝██║  ██║██║  ██║
    ╚═╝  ╚═╝   ╚═╝   ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝
              v10.0 - Three-Headed Beast

EOF
echo -e "${NC}"

# Detect OS
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        OS="linux"
        if command -v apt-get &> /dev/null; then
            PKG_MANAGER="apt"
        elif command -v dnf &> /dev/null; then
            PKG_MANAGER="dnf"
        elif command -v yum &> /dev/null; then
            PKG_MANAGER="yum"
        elif command -v pacman &> /dev/null; then
            PKG_MANAGER="pacman"
        else
            PKG_MANAGER="unknown"
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
        PKG_MANAGER="brew"
    else
        echo -e "${RED}Unsupported OS: $OSTYPE${NC}"
        exit 1
    fi
    echo -e "${CYAN}[HYDRA]${NC} Detected: $OS ($PKG_MANAGER)"
}

# Check command exists
has_cmd() {
    command -v "$1" &> /dev/null
}

# Install package
install_pkg() {
    local pkg=$1
    echo -e "${CYAN}[HYDRA]${NC} Installing $pkg..."

    case $PKG_MANAGER in
        apt)
            sudo apt-get update && sudo apt-get install -y "$pkg"
            ;;
        dnf|yum)
            sudo $PKG_MANAGER install -y "$pkg"
            ;;
        pacman)
            sudo pacman -S --noconfirm "$pkg"
            ;;
        brew)
            brew install "$pkg"
            ;;
        *)
            echo -e "${YELLOW}Please install $pkg manually${NC}"
            return 1
            ;;
    esac
}

# Check prerequisites
check_prerequisites() {
    echo -e "${CYAN}[HYDRA]${NC} Checking prerequisites..."

    local missing=()

    # Git
    if has_cmd git; then
        echo -e "  ${GREEN}[OK]${NC} Git"
    else
        echo -e "  ${RED}[MISSING]${NC} Git"
        missing+=("git")
    fi

    # Node.js
    if has_cmd node; then
        echo -e "  ${GREEN}[OK]${NC} Node.js $(node --version)"
    else
        echo -e "  ${RED}[MISSING]${NC} Node.js"
        missing+=("nodejs")
    fi

    # Python
    if has_cmd python3; then
        echo -e "  ${GREEN}[OK]${NC} Python $(python3 --version 2>&1 | cut -d' ' -f2)"
    else
        echo -e "  ${RED}[MISSING]${NC} Python 3"
        missing+=("python3")
    fi

    # curl
    if has_cmd curl; then
        echo -e "  ${GREEN}[OK]${NC} curl"
    else
        echo -e "  ${RED}[MISSING]${NC} curl"
        missing+=("curl")
    fi

    # PowerShell Core (optional but recommended)
    if has_cmd pwsh; then
        echo -e "  ${GREEN}[OK]${NC} PowerShell Core"
    else
        echo -e "  ${YELLOW}[OPTIONAL]${NC} PowerShell Core (recommended for full compatibility)"
    fi

    # Ollama (optional)
    if has_cmd ollama; then
        echo -e "  ${GREEN}[OK]${NC} Ollama"
    else
        echo -e "  ${YELLOW}[OPTIONAL]${NC} Ollama (local AI - recommended)"
    fi

    # Install missing
    if [ ${#missing[@]} -gt 0 ]; then
        echo ""
        read -p "Install missing prerequisites? [y/N] " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            for pkg in "${missing[@]}"; do
                install_pkg "$pkg" || true
            done
        fi
    fi
}

# Install Ollama
install_ollama() {
    if has_cmd ollama; then
        echo -e "${CYAN}[HYDRA]${NC} Ollama already installed"
        return 0
    fi

    read -p "Install Ollama for local AI? [y/N] " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${CYAN}[HYDRA]${NC} Installing Ollama..."
        curl -fsSL https://ollama.com/install.sh | sh
    fi
}

# Clone/update repository
setup_repository() {
    echo -e "${CYAN}[HYDRA]${NC} Setting up HYDRA..."

    if [ -d "$INSTALL_DIR" ]; then
        echo -e "${CYAN}[HYDRA]${NC} Updating existing installation..."
        cd "$INSTALL_DIR"
        git pull origin "$BRANCH"
    else
        echo -e "${CYAN}[HYDRA]${NC} Cloning repository..."
        git clone --branch "$BRANCH" "$REPO_URL" "$INSTALL_DIR"
        cd "$INSTALL_DIR"
    fi
}

# Setup shell integration
setup_shell() {
    echo -e "${CYAN}[HYDRA]${NC} Setting up shell integration..."

    # Create shell profile snippet
    local profile_snippet="
# HYDRA 10.0 Environment
export HYDRA_HOME=\"$INSTALL_DIR\"
export PATH=\"\$PATH:\$HYDRA_HOME:\$HYDRA_HOME/scripts\"

# Aliases
alias hydra=\"\$HYDRA_HOME/_launcher.sh\"
alias mcp-check=\"\$HYDRA_HOME/mcp-health-check.sh\"

# AI Handler (if pwsh available)
if command -v pwsh &> /dev/null; then
    alias ai='pwsh -NoProfile -Command \"Import-Module \$HYDRA_HOME/ai-handler/AIModelHandler.psm1; Invoke-AI.ps1\"'
fi
"

    # Detect shell config file
    local shell_rc=""
    if [ -n "$ZSH_VERSION" ] || [ -f "$HOME/.zshrc" ]; then
        shell_rc="$HOME/.zshrc"
    elif [ -n "$BASH_VERSION" ] || [ -f "$HOME/.bashrc" ]; then
        shell_rc="$HOME/.bashrc"
    fi

    if [ -n "$shell_rc" ]; then
        # Check if already added
        if ! grep -q "HYDRA_HOME" "$shell_rc" 2>/dev/null; then
            echo "$profile_snippet" >> "$shell_rc"
            echo -e "  ${GREEN}Added to $shell_rc${NC}"
        else
            echo -e "  ${YELLOW}Already configured in $shell_rc${NC}"
        fi
    fi

    # Create standalone profile
    echo "$profile_snippet" > "$INSTALL_DIR/scripts/hydra-profile.sh"
    chmod +x "$INSTALL_DIR/scripts/hydra-profile.sh"
}

# Create launcher script for Unix
create_launcher() {
    cat > "$INSTALL_DIR/_launcher.sh" << 'LAUNCHER_EOF'
#!/usr/bin/env bash
# HYDRA 10.0 Launcher for Linux/macOS

HYDRA_HOME="${HYDRA_HOME:-$(dirname "$0")}"

echo -e "\033[0;35m"
cat << 'EOF'
    HYDRA 10.0 - Three-Headed Beast
    Serena | Desktop Commander | Playwright
EOF
echo -e "\033[0m"

# Check Claude Code
if ! command -v claude &> /dev/null; then
    echo "Claude Code not found. Install with: npm install -g @anthropic-ai/claude-code"
    exit 1
fi

# Health check
echo "Running MCP health check..."
"$HYDRA_HOME/mcp-health-check.sh"

# Launch Claude
echo ""
echo "Starting Claude Code with HYDRA configuration..."
cd "$HYDRA_HOME"
claude
LAUNCHER_EOF

    chmod +x "$INSTALL_DIR/_launcher.sh"
}

# Create health check script for Unix
create_health_check() {
    cat > "$INSTALL_DIR/mcp-health-check.sh" << 'HEALTHCHECK_EOF'
#!/usr/bin/env bash
# MCP Health Check for HYDRA

echo "=== MCP Server Health Check ==="
echo ""

# Check Ollama
if command -v ollama &> /dev/null; then
    if curl -s http://localhost:11434/api/tags &> /dev/null; then
        echo "[OK] Ollama is running"
        echo "     Models: $(curl -s http://localhost:11434/api/tags | grep -o '"name":"[^"]*"' | cut -d'"' -f4 | tr '\n' ' ')"
    else
        echo "[WARN] Ollama installed but not running. Start with: ollama serve"
    fi
else
    echo "[INFO] Ollama not installed"
fi

# Check Node.js for MCP servers
if command -v npx &> /dev/null; then
    echo "[OK] npx available for MCP servers"
else
    echo "[WARN] npx not found - MCP servers may not work"
fi

# Check uvx for Serena
if command -v uvx &> /dev/null; then
    echo "[OK] uvx available for Serena"
else
    echo "[INFO] uvx not found - install with: pip install uv"
fi

echo ""
echo "=== Done ==="
HEALTHCHECK_EOF

    chmod +x "$INSTALL_DIR/mcp-health-check.sh"
}

# Pull Ollama models
pull_models() {
    if ! has_cmd ollama; then
        return 0
    fi

    read -p "Pull recommended Ollama models? [y/N] " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        local models=("llama3.2:3b" "llama3.2:1b" "qwen2.5-coder:1.5b" "phi3:mini")
        for model in "${models[@]}"; do
            echo -e "${CYAN}[HYDRA]${NC} Pulling $model..."
            ollama pull "$model"
        done
    fi
}

# Main installation
main() {
    echo -e "${CYAN}[HYDRA]${NC} Starting installation..."
    echo ""

    detect_os
    check_prerequisites
    install_ollama
    setup_repository
    create_launcher
    create_health_check
    setup_shell
    pull_models

    echo ""
    echo -e "${GREEN}════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  HYDRA 10.0 Installation Complete!${NC}"
    echo -e "${GREEN}════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "Installation directory: ${CYAN}$INSTALL_DIR${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Reload shell:  source ~/.bashrc  (or ~/.zshrc)"
    echo "  2. Start HYDRA:   hydra"
    echo "  3. Health check:  mcp-check"
    echo ""
    echo "Set API keys (optional):"
    echo "  export ANTHROPIC_API_KEY='sk-ant-...'"
    echo "  export OPENAI_API_KEY='sk-...'"
    echo ""
    echo -e "Documentation: ${CYAN}$INSTALL_DIR/CLAUDE.md${NC}"
    echo ""
}

# Run
main "$@"
