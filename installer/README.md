# HYDRA 10.0 Installer

Multi-platform installer for HYDRA (ClaudeCLI + AI Handler + Parallel System + MCP Servers).

## Quick Install

### Windows (PowerShell)
```powershell
iwr -useb https://raw.githubusercontent.com/pawelserkowski-lang/claudecli/master/installer/scripts/bootstrap.ps1 | iex
```

### Linux / macOS
```bash
curl -fsSL https://raw.githubusercontent.com/pawelserkowski-lang/claudecli/master/installer/scripts/install.sh | bash
```

## Manual Installation

### Windows
1. Download `HYDRA-10.0-Setup.exe` from [Releases](../../releases)
2. Run installer with administrator privileges
3. Follow installation wizard

### Linux / macOS
1. Download `hydra-10.0-unix.tar.gz` from [Releases](../../releases)
2. Extract and run:
   ```bash
   tar -xzf hydra-10.0-unix.tar.gz
   cd hydra-10.0-unix
   ./install.sh
   ```

## Components

| Component | Description | Required |
|-----------|-------------|----------|
| **HYDRA Core** | Base configuration, launcher, CLAUDE.md | Yes |
| **AI Handler** | Multi-provider AI with fallback (Ollama → OpenAI → Anthropic) | Yes |
| **Parallel System** | Concurrent execution utilities | Yes |
| **MCP Servers** | Serena, Desktop Commander, Playwright configs | Yes |
| **Ollama** | Local AI (free, no API key) | Optional |

## Prerequisites

| Software | Windows | Linux | macOS |
|----------|---------|-------|-------|
| PowerShell 5.1+ | ✅ Built-in | `pwsh` (optional) | `pwsh` (optional) |
| Node.js 18+ | Required | Required | Required |
| Python 3.8+ | Required | Required | Required |
| Git | Required | Required | Required |
| Ollama | Recommended | Recommended | Recommended |

## Building from Source

```powershell
# Windows - requires NSIS
cd installer
.\Build-Installer.ps1

# Output in installer\dist\
```

## Directory Structure

```
installer/
├── nsis/
│   └── hydra-installer.nsi    # NSIS script for Windows
├── scripts/
│   ├── bootstrap.ps1          # Cross-platform bootstrap
│   ├── install.sh             # Linux/macOS installer
│   ├── uninstall.sh           # Linux/macOS uninstaller
│   ├── Initialize-Hydra.ps1   # Post-install setup
│   └── Test-Prerequisites.ps1 # Prerequisites checker
├── assets/
│   └── hydra.ico              # Installer icon
├── dist/                      # Build output (generated)
├── Build-Installer.ps1        # Build script
└── README.md                  # This file
```

## Post-Installation

After installation, add to your shell profile:

### PowerShell
```powershell
. "$env:LOCALAPPDATA\HYDRA\scripts\hydra-profile.ps1"
```

### Bash/Zsh
```bash
source ~/.hydra/scripts/hydra-profile.sh
```

## Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `ANTHROPIC_API_KEY` | Anthropic API key for Claude | Optional (cloud fallback) |
| `OPENAI_API_KEY` | OpenAI API key | Optional (cloud fallback) |
| `HYDRA_HOME` | Installation directory | Auto-set |

## Uninstallation

### Windows
- Use "Add or Remove Programs" or run `Uninstall.exe` from install directory

### Linux / macOS
```bash
~/.hydra/uninstall.sh
# or
curl -fsSL .../uninstall.sh | bash
```

## Troubleshooting

### NSIS not found (Windows build)
```powershell
winget install NSIS.NSIS
```

### Ollama not starting
```bash
# Linux/macOS
ollama serve

# Windows (run as service)
ollama serve
```

### MCP servers not connecting
```powershell
# Run health check
mcp-check
# or
.\mcp-health-check.ps1
```

## License

MIT License - see [LICENSE](../LICENSE)
