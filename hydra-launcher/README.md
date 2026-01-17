# HYDRA 10.4 Launcher

**Four-Headed Beast** - Tauri (Rust) + React launcher dla Claude CLI z integracją MCP.

## Features

- **Serena** (port 9000) - Symbolic code analysis
- **Desktop Commander** (port 8100) - System operations
- **Playwright** (port 5200) - Browser automation
- **Ollama** (port 11434) - Local AI (cost $0)
- **YOLO Mode** - Skip permission prompts

## Tech Stack

| Layer | Technology |
|-------|------------|
| Frontend | React 19, TailwindCSS, Lucide Icons |
| Backend | Rust, Tauri 2.0 |
| Build | Vite, TypeScript |

## Quick Start

### Prerequisites

- Node.js 20+
- pnpm
- Rust (rustup)
- Tauri CLI

### Install Dependencies

```bash
cd hydra-launcher
pnpm install
```

### Development

```bash
# Run in dev mode (with hot reload)
pnpm tauri dev
```

### Build

```bash
# Build for production
pnpm tauri build
```

The installer will be in `src-tauri/target/release/bundle/`.

## Project Structure

```
hydra-launcher/
├── src-tauri/              # Rust backend
│   ├── src/
│   │   ├── main.rs
│   │   ├── lib.rs
│   │   ├── config.rs       # hydra-config.json parser
│   │   ├── commands.rs     # Tauri IPC commands
│   │   ├── mcp/
│   │   │   ├── health.rs   # TCP health checks
│   │   │   └── server.rs   # MCP server management
│   │   └── process/
│   │       ├── claude.rs   # Claude CLI spawning
│   │       └── ollama.rs   # Ollama management
│   ├── Cargo.toml
│   └── tauri.conf.json
│
├── src/                    # React frontend
│   ├── components/
│   │   ├── Launcher.tsx    # Loading screen
│   │   ├── MatrixRain.tsx  # Matrix rain effect
│   │   ├── Dashboard.tsx   # Main dashboard
│   │   ├── MCPStatus.tsx   # MCP server status
│   │   ├── OllamaStatus.tsx
│   │   ├── SystemMetrics.tsx
│   │   ├── LaunchPanel.tsx
│   │   └── YoloToggle.tsx
│   ├── hooks/
│   │   ├── useMCPHealth.ts
│   │   ├── useSystemMetrics.ts
│   │   └── useOllama.ts
│   ├── contexts/
│   │   └── ThemeContext.tsx
│   ├── App.tsx
│   ├── main.tsx
│   └── index.css           # Matrix theme
│
├── package.json
├── tailwind.config.js
└── vite.config.ts
```

## Configuration

The launcher reads `hydra-config.json` from the ClaudeHYDRA directory.

## Theme

Matrix theme with glassmorphism, supporting dark and light modes.

### Colors

```css
--matrix-bg-primary: #0a1f0a;
--matrix-bg-secondary: #001a00;
--matrix-accent: #00ff41;
```

## License

MIT

---

*"Four heads, twelve wolves, one goal. HYDRA YOLO."*
