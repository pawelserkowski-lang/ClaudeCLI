# HYDRA 10.0 - ClaudeCLI

**Maximum Autonomy Mode** | **Parallel Execution** | **MCP Orchestration**

```
 _   ___   ______  ____   ___
| | | \ \ / /  _ \|  _ \ / \ \
| |_| |\ V /| | | | |_) / _ \ \
|  _  | | | | |_| |  _ / ___ \ \
|_| |_| |_| |____/|_| /_/   \_\_\

Three Heads, One Goal. Hydra Executes In Parallel.
```

## 🎯 Overview

HYDRA 10.0 to zaawansowane środowisko dla **Claude CLI** działające w trybie **Maximum Autonomy Mode** z pełnym dostępem do:
- Zmiennych środowiskowych (read/write/delete)
- Rejestru Windows (HKLM, HKCU)
- Systemu plików (pełen dostęp)
- Operacji sieciowych (firewall, port scanning)
- Instalacji oprogramowania (chocolatey, winget, npm, pip)

## 📋 Features

### ✨ Maximum Autonomy Mode
- 🔓 **Wildcard permissions**: `Bash(*)`, `Write(*)`, `Edit(*)`, `Read(*)`
- 🔧 **Rejestr Windows**: Pełny R/W dostęp
- 🔐 **Uprawnienia admin**: RunAs, zarządzanie usługami
- 📂 **System plików**: Dostęp do System32, Program Files
- 🌐 **Operacje sieciowe**: Port scanning, firewall rules
- 📦 **Instalacja software**: choco, winget, npm global, pip
- ⚡ **Wykonywanie skryptów**: Unrestricted Execution Policy

### ⚡ Parallel Execution
- Wszystkie niezależne operacje wykonywane równolegle
- PowerShell Jobs dla MCP health checks
- Zgodność z zasadą: *"Każda operacja, która może być wykonana równolegle, MUSI być wykonana równolegle"*

### 🛠️ MCP Tools Integration
| Tool | Port | Transport | Funkcja |
|------|------|-----------|---------|
| **Serena** | 9000 | SSE | Symbolic code analysis |
| **Desktop Commander** | 8100 | Stdio | System operations |
| **Playwright** | 5200 | Stdio | Browser automation |

## 📦 Installation

### Prerequisites
- Windows 11
- PowerShell 7+
- Claude CLI
- API Key: `ANTHROPIC_API_KEY`

### Quick Start

```powershell
# 1. Clone or download projekt do Desktop\ClaudeCLI

# 2. Ustaw API Key
[Environment]::SetEnvironmentVariable('ANTHROPIC_API_KEY', 'sk-ant-api03-...', 'User')

# 3. Uruchom launcher
.\ClaudeCLI.vbs
# LUB
powershell -ExecutionPolicy Bypass -File _launcher.ps1

# 4. (Opcjonalnie) Utwórz shortcut na pulpicie
.\create-shortcuts.ps1
```

## 🗂️ Project Structure

```
C:\Users\BIURODOM\Desktop\ClaudeCLI\
├── .claude/
│   ├── commands/            # Custom slash commands
│   ├── hooks/               # Event hooks
│   ├── skills/              # Custom skills (serena-commander, hydra)
│   ├── settings.local.json  # Permissions & config (Maximum Autonomy)
│   └── statusline.js        # Status bar config
├── .serena/
│   ├── cache/               # Serena cache
│   ├── memories/            # Persistent memories (25 slots)
│   └── project.yml          # Serena project config
├── .gitignore               # Ochrona sekretów
├── CLAUDE.md                # System instructions (386 linii)
├── README.md                # Ten plik
├── ClaudeCLI.vbs            # Windows shortcut helper
├── _launcher.ps1            # Main launcher (try/catch, health check)
├── mcp-health-check.ps1     # MCP diagnostics (parallel execution)
├── create-shortcuts.ps1     # Desktop shortcut creator
└── icon.ico                 # Ikona aplikacji
```

## 🔐 Security Policy

### Environment Variables Access
ClaudeCLI ma **pełny dostęp** do zmiennych środowiskowych:

```powershell
# ✅ DOZWOLONE: Odczyt
$apiKey = $env:ANTHROPIC_API_KEY

# ✅ DOZWOLONE: Modyfikacja (User/Machine/Process scopes)
[Environment]::SetEnvironmentVariable('NEW_VAR', 'value', 'User')

# ✅ DOZWOLONE: Usuwanie
[Environment]::SetEnvironmentVariable('OLD_VAR', $null, 'User')
```

### Permissions Model

```json
{
  "permissions": {
    "allow": [
      "Bash(*)",                    // WSZYSTKIE komendy Bash
      "mcp__serena__*",
      "mcp__desktop-commander__*",
      "mcp__playwright__*",
      "Write(*)", "Edit(*)", "Read(*)",
      "Glob(*)", "Grep(*)",
      "Skill(*)", "SlashCommand(*)"
    ],
    "deny": []                      // Pusta lista
  }
}
```

### 🚨 Absolutne zakazy (nawet w Maximum Autonomy):
- `rm -rf /` lub `Remove-Item C:\ -Recurse -Force`
- `format C:`
- `diskpart` bez potwierdzenia
- Masowe usuwanie kluczy rejestru
- Wyłączanie Windows Defender bez zgody

**Filozofia**: *Pełna moc, ale z odpowiedzialnością. Przed destrukcyjnymi operacjami - pytaj użytkownika!*

## 🚀 Usage

### Podstawowe uruchomienie

```powershell
# Via VBS launcher (zalecane)
.\ClaudeCLI.vbs

# Via PowerShell
powershell -ExecutionPolicy Bypass -File _launcher.ps1
```

### MCP Health Check

```powershell
# Ręczne sprawdzenie MCP servers (parallel execution)
.\mcp-health-check.ps1 -TimeoutSeconds 5
```

### Tworzenie skrótu na pulpicie

```powershell
.\create-shortcuts.ps1
```

## 🔧 Configuration

### API Keys Setup

```powershell
# PowerShell (User scope - rekomendowane)
[Environment]::SetEnvironmentVariable('ANTHROPIC_API_KEY', 'sk-ant-api03-...', 'User')

# PowerShell (Process scope - tymczasowe)
$env:ANTHROPIC_API_KEY = "sk-ant-api03-..."

# CMD
setx ANTHROPIC_API_KEY "sk-ant-api03-..."
```

### Weryfikacja

```powershell
# Lista zmiennych Claude/Anthropic
Get-ChildItem env: | Where-Object { $_.Name -like "*CLAUDE*" -or $_.Name -like "*ANTHROPIC*" }

# Sprawdź konkretną zmienną (maskowana)
$key = $env:ANTHROPIC_API_KEY
if ($key) { Write-Host "✓ API Key: $($key.Substring(0,15))..." }
```

## 📚 Architecture

### Council of Six (Multi-Agent Debate)

| Agent | Rola | Fokus |
|-------|------|-------|
| **Architekt** | Fakty | Rust 2024, React 19, czysta struktura |
| **Security** | Ryzyko | ENV vars allowed, zero commits wrażliwych danych, maskowanie kluczy API |
| **Speedster** | Performance | Lighthouse > 90, bundle < 200KB |
| **Pragmatyk** | Korzyści | Hybrydowość Web + Desktop |
| **Researcher** | Weryfikacja | Sprawdzaj w docs/Google przed implementacją |
| **Jester** | Emocje | Krytyka boilerplate'u i over-engineeringu |

### Parallel Execution Principle

```rust
// DOBRZE: tokio::join! dla niezależnych operacji
let (a, b, c) = tokio::join!(task_a(), task_b(), task_c());

// ŹLE: sekwencyjne await
let a = task_a().await;
let b = task_b().await;  // marnowanie czasu
```

```typescript
// DOBRZE: Promise.all
const [users, products] = await Promise.all([fetchUsers(), fetchProducts()]);

// ŹLE: await waterfall
const users = await fetchUsers();
const products = await fetchProducts();
```

## 🛡️ Best Practices

| Zalecenie | Priorytet |
|-----------|-----------|
| Używaj ENV vars zamiast hardcoded keys | 🔴 Krytyczny |
| NIE commituj kluczy API do Git | 🔴 Krytyczny |
| Maskuj klucze API w outputach (15 znaków) | 🟡 Średni |
| Preferuj absolute paths | 🟢 Niski |
| Zawsze używaj error handling (try/catch) | 🟡 Średni |
| Parallel MCP calls gdy możliwe | 🟡 Średni |
| Backupy przed systemowymi zmianami | 🟡 Średni |

## 📖 Documentation

Pełna dokumentacja systemowa: **[CLAUDE.md](CLAUDE.md)** (386 linii)

Zawiera:
- Parallel Execution (Zasada Nadrzędna)
- Council of Six (Multi-Agent Debate)
- Tech Stack
- Project Structure
- Security Policy (Maximum Autonomy Mode)
- Protocols (PowerShell, MCP)
- Best Practices

## 🤝 Contributing

Ten projekt działa w trybie **Maximum Autonomy**. Przed wprowadzeniem zmian:

1. Przeczytaj **CLAUDE.md** (instrukcje systemowe)
2. Przestrzegaj zasad **Parallel Execution**
3. Używaj **try/catch** z `-ErrorAction Stop`
4. Zawsze **absolute paths**
5. **Loguj z kolorami** (Write-Host -ForegroundColor)

## 📜 License

MIT License - see [LICENSE](LICENSE) for details

## 🔗 Links

- [Claude CLI Documentation](https://docs.anthropic.com/en/docs/claude-code)
- [Anthropic API Console](https://console.anthropic.com/)
- [MCP Servers](https://modelcontextprotocol.io/)

---

> *"Trzy głowy, jeden cel. Hydra wykonuje równolegle."*

**HYDRA 10.0** | Maximum Autonomy Mode | Windows 11
