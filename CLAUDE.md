# HYDRA 10.1 - System Instructions

**Status**: Active | **Mode**: MCP Orchestration | **Project**: ClaudeCLI
**Path**: `C:\Users\BIURODOM\Desktop\ClaudeCLI`
**Config**: `hydra-config.json`

## MCP Tools

| Tool | Port | Funkcja |
|------|------|---------|
| **Serena** | 9000 | Symbolic code analysis |
| **Desktop Commander** | 8100 | System operations |
| **Playwright** | 5200 | Browser automation |

---

## Slash Commands (Quick Reference)

### Core AI Commands

| Command | Description | Cost |
|---------|-------------|------|
| `/ai <query>` | Quick local AI query | $0 |
| `/ai-batch` | Parallel batch queries | $0 |
| `/ai-status` | Check all providers | - |
| `/ai-config` | Configure settings | - |

### Advanced AI Commands

| Command | Description | Module |
|---------|-------------|--------|
| `/self-correct <code task>` | Code with auto-validation | SelfCorrection |
| `/speculate <query>` | Model racing (fastest wins) | SpeculativeDecoding |
| `/semantic-query <file> <question>` | Deep RAG with imports | SemanticFileMapping |
| `/few-shot <task>` | Learn from history | FewShotLearning |
| `/load-balance` | CPU-aware provider | LoadBalancer |
| `/optimize-prompt <text>` | Enhance prompt quality | PromptOptimizer |

### Orchestration

| Command | Description |
|---------|-------------|
| `/hydra` | Three-Headed Beast workflow |
| `/serena-commander` | Serena + DC hybrid skill |

### Usage Examples

```powershell
# Generate validated code
/self-correct Write Python function to parse JSON safely

# Fastest response (model race)
/speculate What is the capital of France?

# Query with full dependency context
/semantic-query src/auth.py How does login work?

# SQL with history examples
/few-shot Write SQL to get active users from last 30 days

# Check system load and get provider
/load-balance

# Improve vague prompt
/optimize-prompt do something with the stuff
```

---

## 🔥 ZASADA: AI Handler - Auto-Load on Startup

> **AI Handler MUSI być załadowany automatycznie przy każdym starcie ClaudeCLI.**

### Status na starcie

```
  AI Handler:
    Ollama (local)   Running on :11434        [OK]
    Cloud APIs       Anthropic, OpenAI        [OK]
    AI Handler       v1.0 loaded              [OK]
```

### Co jest włączone automatycznie:

| Komponent | Opis | Status |
|-----------|------|--------|
| `AIModelHandler.psm1` | Główny moduł | Import globalny |
| `Initialize-AIState` | Stan providerów | Auto-init |
| Ollama check | Port 11434 | Status w GUI |
| Cloud API keys | Anthropic/OpenAI | Weryfikacja |
| Alias `ai` | Quick queries | Globalny |

### Dostępne komendy po starcie:

```powershell
# Quick AI call (local Ollama preferred)
ai "Twoje pytanie"

# Status wszystkich providerów
Get-AIStatus

# Pełne API call z auto-fallback
Invoke-AIRequest -Messages @(@{role="user"; content="..."})

# Test providerów
Test-AIProviders
```

### Fallback chain (automatyczny):

```
Local:  Ollama (llama3.2:3b) → qwen2.5-coder:1.5b
Cloud:  Anthropic (Haiku) → OpenAI (gpt-4o-mini)

Priorytet: LOCAL FIRST (koszt $0) → Cloud jako fallback
```

### Implementacja w `_launcher.ps1`:

Sekcja `# === AI HANDLER ===` automatycznie:
1. Importuje moduł globalnie
2. Inicjalizuje stan
3. Sprawdza Ollama (local)
4. Weryfikuje klucze API (cloud)
5. Tworzy alias `ai`

**Ta zasada jest OBOWIĄZKOWA** - AI Handler musi być dostępny natychmiast po starcie bez dodatkowej konfiguracji.

---

## 1. Parallel Execution (Zasada Nadrzędna)

> Każda operacja, która może być wykonana równolegle, MUSI być wykonana równolegle.

### Klasyfikacja

| Typ | Operacje | Wykonanie |
|-----|----------|-----------|
| **READ-ONLY** | `find_symbol`, `read_file`, `list_directory`, `grep`, `glob` | Zawsze równolegle |
| **SIDE-EFFECTS** | `write_file`, `start_process` | Sekwencyjnie |

### Wzorce

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

---

## 2. Council of Six (Multi-Agent Debate)

| Agent | Rola | Fokus |
|-------|------|-------|
| **Architekt** | Fakty | Rust 2024, React 19, czysta struktura |
| **Security** | Ryzyko | ENV vars allowed, zero commits wrażliwych danych, maskowanie kluczy API |
| **Speedster** | Performance | Lighthouse > 90, bundle < 200KB |
| **Pragmatyk** | Korzyści | Hybrydowość Web + Desktop |
| **Researcher** | Weryfikacja | Sprawdzaj w docs/Google przed implementacją |
| **Jester** | Emocje | Krytyka boilerplate'u i over-engineeringu |

---

## 3. Tech Stack (ClaudeCLI)

| Warstwa | Technologia |
|---------|-------------|
| **Shell** | PowerShell 7 |
| **MCP Servers** | Serena, Desktop Commander, Playwright |
| **Config** | JSON, YAML, Markdown |
| **OS** | Windows 11 |

---

## 4. Project Structure

```
C:\Users\BIURODOM\Desktop\ClaudeCLI\
├── .claude/
│   ├── commands/        # Custom slash commands
│   ├── hooks/           # Event hooks
│   ├── skills/          # Custom skills (serena-commander, hydra)
│   ├── settings.local.json
│   └── statusline.js    # Status bar config
├── .serena/
│   ├── cache/           # Serena cache
│   ├── memories/        # Persistent memories (25 slots)
│   └── project.yml      # Serena project config
├── .gitignore           # Ochrona sekretów
├── CLAUDE.md            # Ten plik (instrukcje)
├── _launcher.ps1        # Main launcher
├── mcp-health-check.ps1 # MCP diagnostics
└── ClaudeCLI.vbs        # Windows shortcut helper
├── ai-handler/          # 🤖 AI Model Handler with auto-fallback
│   ├── AIFacade.psm1            # 🎯 ENTRY POINT - Unified interface (NEW)
│   ├── AIModelHandler.psm1      # Legacy main module (still works)
│   ├── ai-config.json           # Provider/model configuration
│   ├── ai-state.json            # Runtime state (auto-generated)
│   ├── Invoke-AI.ps1            # Quick CLI wrapper
│   ├── Initialize-AIHandler.ps1 # Setup script
│   ├── Initialize-AdvancedAI.ps1 # Advanced AI loader
│   ├── Demo-AdvancedAI.ps1      # Advanced features demo
│   ├── cache/                   # Few-shot learning cache
│   ├── utils/                   # 📦 Layer 1: Utilities (NEW)
│   │   ├── AIUtil-JsonIO.psm1       # Atomic JSON read/write
│   │   ├── AIUtil-Health.psm1       # System & provider health checks
│   │   ├── AIUtil-Validation.psm1   # Prompt/code validation
│   │   └── AIErrorHandler.psm1      # Centralized error handling
│   ├── core/                    # 📦 Layer 2: Core (NEW)
│   │   ├── AIConstants.psm1         # System constants
│   │   ├── AIConfig.psm1            # Configuration management
│   │   └── AIState.psm1             # Runtime state management
│   ├── rate-limiting/           # 📦 Layer 3: Rate limiting (NEW)
│   │   └── RateLimiter.psm1         # Token/request rate limiting
│   ├── model-selection/         # 📦 Layer 3: Model selection (NEW)
│   │   └── ModelSelector.psm1       # Intelligent model selection
│   ├── providers/               # 📦 Layer 4: Providers (NEW)
│   │   ├── OllamaProvider.psm1      # Local Ollama integration
│   │   ├── AnthropicProvider.psm1   # Anthropic Claude API
│   │   └── OpenAIProvider.psm1      # OpenAI GPT API
│   └── modules/                 # 🧠 Advanced AI Modules (Layer 6)
│       ├── SelfCorrection.psm1      # Agentic self-correction
│       ├── FewShotLearning.psm1     # Dynamic few-shot learning
│       ├── SpeculativeDecoding.psm1 # Parallel multi-model
│       ├── LoadBalancer.psm1        # CPU-aware load balancing
│       ├── SemanticFileMapping.psm1 # Deep RAG with imports
│       ├── AdvancedAI.psm1          # Unified interface
│       ├── PromptOptimizer.psm1     # Auto prompt enhancement
│       ├── TaskClassifier.psm1      # Task type classification
│       ├── SmartQueue.psm1          # Prompt queue management
│       ├── ModelDiscovery.psm1      # Dynamic model discovery
│       ├── SemanticGitCommit.psm1   # AI-powered git commits
│       ├── AICodeReview.psm1        # Code review module
│       └── PredictiveAutocomplete.psm1 # Autocomplete suggestions
├── parallel/            # ⚡ Parallel execution system
│   ├── modules/
│   │   └── ParallelUtils.psm1    # Core parallel functions
│   ├── build/
│   │   ├── Build-Parallel.ps1    # Multi-project builder
│   │   ├── Test-Parallel.ps1     # Parallel test runner
│   │   └── Lint-Parallel.ps1     # Parallel linter
│   ├── scripts/
│   │   ├── Invoke-ParallelGit.ps1       # Git ops across repos
│   │   ├── Invoke-ParallelDownload.ps1  # Multi-connection downloads
│   │   ├── Invoke-ParallelCompress.ps1  # 7z parallel compression
│   │   ├── Invoke-TaskDAG.ps1           # Dependency-aware executor
│   │   ├── Watch-FilesParallel.ps1      # File system watcher
│   │   ├── Invoke-MCPParallel.ps1       # MCP parallelization guide
│   │   └── Start-ParallelBrowsers.ps1   # Playwright parallel helper
│   └── Initialize-Parallel.ps1   # Module loader
```

---

## 4.1 Refactored AI Handler Architecture (🏗️ NEW)

The AI Handler system has been refactored into a modular, layered architecture with dependency injection and proper separation of concerns. This replaces the monolithic `AIModelHandler.psm1` design.

### New Directory Structure

```
ai-handler/
├── AIFacade.psm1              # 🎯 ENTRY POINT - Unified interface
├── AIModelHandler.psm1        # Legacy module (still works)
├── ai-config.json             # Provider/model configuration
├── ai-state.json              # Runtime state (auto-generated)
│
├── utils/                     # 📦 Layer 1: Utilities (no dependencies)
│   ├── AIUtil-JsonIO.psm1     # Atomic JSON read/write
│   ├── AIUtil-Health.psm1     # System & provider health checks
│   ├── AIUtil-Validation.psm1 # Prompt/code validation
│   └── AIErrorHandler.psm1    # Centralized error handling
│
├── core/                      # 📦 Layer 2: Core (depends on utils)
│   ├── AIConstants.psm1       # System constants
│   ├── AIConfig.psm1          # Configuration management
│   └── AIState.psm1           # Runtime state management
│
├── rate-limiting/             # 📦 Layer 3: Infrastructure
│   └── RateLimiter.psm1       # Token/request rate limiting
│
├── model-selection/           # 📦 Layer 3: Infrastructure
│   └── ModelSelector.psm1     # Optimal model selection
│
├── providers/                 # 📦 Layer 4: Providers
│   ├── OllamaProvider.psm1    # Local Ollama integration
│   ├── AnthropicProvider.psm1 # Anthropic Claude API
│   └── OpenAIProvider.psm1    # OpenAI GPT API
│
├── fallback/                  # 📦 Layer 5: Fallback logic
│   └── (fallback orchestration)
│
└── modules/                   # 📦 Layer 6: Advanced features
    ├── SelfCorrection.psm1
    ├── FewShotLearning.psm1
    ├── SpeculativeDecoding.psm1
    ├── LoadBalancer.psm1
    ├── SemanticFileMapping.psm1
    ├── PromptOptimizer.psm1
    ├── AdvancedAI.psm1
    └── ... (other advanced modules)
```

### Layer Descriptions

| Layer | Directory | Responsibility | Dependencies |
|-------|-----------|----------------|--------------|
| **1. Utils** | `utils/` | Zero-dependency utilities | None |
| **2. Core** | `core/` | Configuration, constants, state | Utils |
| **3. Infrastructure** | `rate-limiting/`, `model-selection/` | Rate limiting, model selection | Core |
| **4. Providers** | `providers/` | API integrations | Infrastructure |
| **5. Fallback** | `fallback/` | Cross-provider fallback | Providers |
| **6. Advanced** | `modules/` | Optional advanced features | All above |

### AIFacade.psm1 - The Entry Point

`AIFacade.psm1` is the **recommended entry point** for all AI operations. It provides:

1. **Dependency Injection Container** - Manages module loading order
2. **Phased Loading** - Prevents circular dependencies
3. **Unified Interface** - Single `Invoke-AI` function for all operations

```powershell
# Initialize the AI System (loads all modules in correct order)
Import-Module "C:\Users\BIURODOM\Desktop\ClaudeCLI\ai-handler\AIFacade.psm1"
$result = Initialize-AISystem

# Check system status
Get-AISystemStatus -Detailed -CheckProviders

# Unified AI invocation
Invoke-AI "What is 2+2?" -Mode fast
Invoke-AI "Write Python function to sort list" -Mode code
Invoke-AI "Explain async/await" -Mode analysis

# Get dependency container
Get-AIDependencies -Category "Providers"

# Reset and reinitialize
Reset-AISystem -Reinitialize
```

### Key Module Responsibilities

| Module | Functions | Description |
|--------|-----------|-------------|
| **AIUtil-JsonIO** | `Read-JsonFile`, `Write-JsonFile`, `ConvertTo-Hashtable` | Atomic JSON I/O with PS 5.1 compatibility |
| **AIUtil-Health** | `Test-OllamaAvailable`, `Get-SystemMetrics`, `Test-ProviderConnectivity` | Cached health checks (30s TTL) |
| **AIUtil-Validation** | `Get-PromptCategory`, `Get-ClarityScore`, `Test-CodeLanguage` | Prompt/code analysis |
| **AIErrorHandler** | `Get-ErrorCategory`, `Test-ErrorRecoverable`, `Get-RetryStrategy` | Error classification & recovery |
| **AIConfig** | `Get-AIConfig`, `Save-AIConfig`, `Merge-Config`, `Test-ConfigValid` | Configuration CRUD |
| **AIState** | `Get-AIState`, `Save-AIState`, `Update-AIState` | Runtime state management |
| **RateLimiter** | `Update-UsageTracking`, `Get-RateLimitStatus`, `Test-RateLimitAvailable` | Per-minute rate limiting |
| **ModelSelector** | `Get-OptimalModel`, `Get-FallbackModel`, `Test-ModelAvailable` | Intelligent model selection |
| **OllamaProvider** | `Test-OllamaAvailable`, `Get-OllamaModels`, `Invoke-OllamaAPI` | Local AI via Ollama |
| **AnthropicProvider** | `Invoke-AnthropicAPI`, `Test-AnthropicAvailable` | Claude API integration |
| **OpenAIProvider** | `Invoke-OpenAIAPI`, `Test-OpenAIAvailable` | GPT API integration |

### Migration Guide: Old vs New

**OLD (Monolithic)**:
```powershell
# Single file import
Import-Module "ai-handler\AIModelHandler.psm1"
Invoke-AIRequest -Messages @(@{role="user"; content="..."})
```

**NEW (Modular via Facade)**:
```powershell
# Facade handles all dependencies
Import-Module "ai-handler\AIFacade.psm1"
Initialize-AISystem

# Unified interface with mode selection
Invoke-AI "Your prompt" -Mode auto

# Or use individual modules if needed
$status = Get-RateLimitStatus -Provider "anthropic" -Model "claude-sonnet-4-5-20250929"
$optimal = Get-OptimalModel -Task "code" -PreferCheapest
```

**Backward Compatibility**: `AIModelHandler.psm1` still works as before. The new architecture is additive.

### Loading Phases (Initialize-AISystem)

```
Phase 1: Utils          → AIUtil-JsonIO, AIUtil-Health, AIUtil-Validation
Phase 2: Core           → AIConstants, AIConfig, AIState
Phase 3: Infrastructure → RateLimiter, ModelSelector, ErrorLogger, SecureStorage
Phase 4: Providers      → OllamaProvider, AnthropicProvider, OpenAIProvider
Phase 5: Advanced       → SelfCorrection, FewShotLearning, SpeculativeDecoding, ...
```

### Utility Functions Quick Reference

#### AIUtil-JsonIO (Atomic JSON Operations)

```powershell
# Read JSON with default fallback
$config = Read-JsonFile -Path "config.json" -Default @{ setting = "value" }

# Write JSON atomically (temp file + rename)
Write-JsonFile -Path "state.json" -Data $state -Depth 10

# Convert PSObject to Hashtable (PS 5.1 compatibility)
$hashtable = $jsonObject | ConvertTo-Hashtable
```

#### AIUtil-Health (Cached Health Checks)

```powershell
# Check Ollama (cached 30s)
$ollama = Test-OllamaAvailable -IncludeModels
# Returns: @{ Available = $true; Models = @('llama3.2:3b'); ResponseTimeMs = 15 }

# Force fresh check
Test-OllamaAvailable -NoCache

# Get system metrics (cached 10s)
$metrics = Get-SystemMetrics
# Returns: @{ CpuPercent = 25; MemoryPercent = 60; ... }
```

#### AIUtil-Validation (Prompt Analysis)

```powershell
# Detect prompt category
Get-PromptCategory -Prompt "Write Python function to sort"
# Returns: "code"

# Get clarity score (0-100)
Get-ClarityScore -Prompt "do something with the stuff"
# Returns: 35 (low - vague terms detected)

# Detect programming language in code
Test-CodeLanguage -Code "def hello(): print('world')"
# Returns: "python"
```

#### AIErrorHandler (Error Classification)

```powershell
# Classify error
$category = Get-ErrorCategory -ErrorMessage "rate limit exceeded"
# Returns: "RateLimit"

# Check if recoverable
Test-ErrorRecoverable -Category "RateLimit"
# Returns: $true

# Get retry strategy
Get-RetryStrategy -Category "Overloaded"
# Returns: @{ RetryAfter = 30000; Fallback = "SwitchModel" }
```

### Benefits of New Architecture

| Benefit | Description |
|---------|-------------|
| **No Circular Dependencies** | Phased loading ensures correct order |
| **Testability** | Individual modules can be unit tested |
| **Maintainability** | Single responsibility per module |
| **Caching** | Health checks cached to reduce redundancy |
| **Backward Compatible** | Old code still works unchanged |
| **Dependency Injection** | Easy to swap implementations |
| **Error Isolation** | Failures in optional modules don't break core |

---

## 5. Parallel Execution System (⚡ NEW)

### Quick Start

```powershell
# Initialize parallel environment
. "C:\Users\BIURODOM\Desktop\ClaudeCLI\parallel\Initialize-Parallel.ps1"

# Check system configuration
Get-ParallelConfig
```

### Module Functions

| Function | Description | Usage |
|----------|-------------|-------|
| `Invoke-Parallel` | General parallel execution | `$items \| Invoke-Parallel { process $_ }` |
| `Invoke-ParallelJobs` | Run multiple jobs | `Invoke-ParallelJobs -Jobs @{...} -Wait` |
| `Read-FilesParallel` | Read multiple files | `Read-FilesParallel -Paths @(...)` |
| `Search-FilesParallel` | Search across dirs | `Search-FilesParallel -Paths @(...) -Pattern "TODO"` |
| `Invoke-CommandsParallel` | Run shell commands | `Invoke-CommandsParallel -Commands @(...)` |
| `Invoke-WebRequestsParallel` | HTTP requests | `Invoke-WebRequestsParallel -Urls @(...)` |
| `Invoke-GitParallel` | Git across repos | `Invoke-GitParallel -Repositories @(...) -GitCommand "pull"` |
| `Compress-FilesParallel` | 7z compression | `Compress-FilesParallel -Items @(...)` |

### Build Scripts

```powershell
# Build all projects (Node, Rust, .NET, Python, Go)
& "parallel\build\Build-Parallel.ps1" -Path "C:\Projects" -Test -Clean

# Run tests with coverage
& "parallel\build\Test-Parallel.ps1" -Path "C:\Projects" -Coverage

# Lint and auto-fix
& "parallel\build\Lint-Parallel.ps1" -Path "C:\Projects" -Fix
```

### Task DAG (Dependency-Aware Execution)

```powershell
$tasks = @{
    "install" = @{ Script = { npm install }; DependsOn = @() }
    "build" = @{ Script = { npm run build }; DependsOn = @("install") }
    "test" = @{ Script = { npm test }; DependsOn = @("build") }
    "lint" = @{ Script = { npm run lint }; DependsOn = @("install") }
    "deploy" = @{ Script = { npm run deploy }; DependsOn = @("test", "lint") }
}

& "parallel\scripts\Invoke-TaskDAG.ps1" -Tasks $tasks
```

### MCP Parallelization Rules

| Operation Type | Parallelization | Example |
|---------------|-----------------|---------|
| **READ-ONLY** | Always parallel | `read_file`, `list_directory`, `find_symbol`, `start_search` |
| **WRITE** | Sequential | `write_file`, `edit_block` |
| **BROWSER** | Multi-tab parallel | Multiple `browser_navigate` calls |

**Claude MUST batch independent MCP calls in single message:**
```
✅ GOOD: [read_file: a.txt] [read_file: b.txt] [find_symbol: MyClass]
❌ BAD:  Message 1: [read_file: a.txt]
        Message 2: [read_file: b.txt]
        Message 3: [find_symbol: MyClass]
```

### Performance Targets

| Metric | Target |
|--------|--------|
| CPU Utilization | > 80% during parallel ops |
| Speedup (N cores) | > N/2 for I/O bound tasks |
| Build time | < sequential / core_count |

---

## 6. AI Model Handler (🤖 NEW)

Comprehensive AI model management with automatic fallback, rate limiting, cost optimization, and multi-provider support.

### Features

| Feature | Description |
|---------|-------------|
| **Auto-Retry Fallback** | Opus → Sonnet → Haiku on errors |
| **Rate Limit Aware** | Auto-switch when approaching limits |
| **Cost Optimizer** | Select cheapest model for task |
| **Multi-Provider** | Anthropic → OpenAI → Ollama fallback |

### Quick Start

```powershell
# Initialize (run once per session)
. "C:\Users\BIURODOM\Desktop\ClaudeCLI\ai-handler\Initialize-AIHandler.ps1"

# Quick AI call
.\ai-handler\Invoke-AI.ps1 -Prompt "Your question"

# With task-specific optimization
.\ai-handler\Invoke-AI.ps1 -Prompt "Write Python code" -Task code -PreferCheapest

# Check status
Get-AIStatus

# Test all providers
Test-AIProviders
```

### Model Configuration

| Provider | Models | Pricing (per 1M tokens) |
|----------|--------|------------------------|
| **Anthropic** | Opus 4.5, Sonnet 4.5, Haiku 4 | $15-$0.80 in / $75-$4 out |
| **OpenAI** | GPT-4o, GPT-4o-mini | $2.50-$0.15 in / $10-$0.60 out |
| **Ollama** | Llama 3.3, Qwen 2.5 | Free (local) |

### Fallback Chain

```
Anthropic: Opus 4.5 → Sonnet 4.5 → Haiku 4
OpenAI:    GPT-4o → GPT-4o-mini
Ollama:    Llama 3.3:70b → Qwen 2.5-coder:32b

Provider Order: Anthropic → OpenAI → Ollama
```

### Module Functions

| Function | Description |
|----------|-------------|
| `Get-AIStatus` | View all providers and rate limits |
| `Test-AIProviders` | Test connectivity to all providers |
| `Get-OptimalModel` | Auto-select best model for task type |
| `Get-FallbackModel` | Get next model in fallback chain |
| `Invoke-AIRequest` | Make AI request with auto-fallback |
| `Update-UsageTracking` | Log usage for rate limiting |
| `Reset-AIState` | Clear usage data |

### Task-Based Selection

```powershell
# Get optimal model for task type
Get-OptimalModel -Task "code" -EstimatedTokens 1000 -PreferCheapest

# Task types: simple, complex, creative, code, vision, analysis
```

### Rate Limit Monitoring

```powershell
# Check rate limit status
Get-RateLimitStatus -Provider "anthropic" -Model "claude-sonnet-4-5-20250929"

# Returns: available, tokensPercent, requestsPercent, tokensRemaining
```

### Configuration

Edit `ai-handler/ai-config.json`:

```json
{
  "settings": {
    "maxRetries": 3,
    "retryDelayMs": 1000,
    "rateLimitThreshold": 0.85,
    "costOptimization": true,
    "autoFallback": true
  }
}
```

### Environment Variables

| Variable | Provider | Required |
|----------|----------|----------|
| `ANTHROPIC_API_KEY` | Anthropic | For Claude models |
| `OPENAI_API_KEY` | OpenAI | For GPT models |
| (none) | Ollama | Local, no key needed |

---

## 7. Security Policy

### Environment Variables Access

ClaudeCLI ma dostęp do zmiennych środowiskowych systemu operacyjnego.

#### Dozwolone operacje:

| Operacja | Opis | Przykład |
|----------|------|----------|
| **Odczyt** | Pełny dostęp do wszystkich zmiennych środowiskowych | `$env:ANTHROPIC_API_KEY`, `$env:PATH` |
| **Wyświetlanie** | Lista i podgląd wartości (maskowanie kluczy API) | `Get-ChildItem env:` |
| **Weryfikacja** | Sprawdzanie obecności i formatowania | `if ($env:VAR) { }` |

#### Zabezpieczenia:

```powershell
# ✅ DOZWOLONE: Odczyt zmiennych środowiskowych
$apiKey = $env:ANTHROPIC_API_KEY
$path = $env:PATH
$user = $env:USERNAME

# ✅ DOZWOLONE: Maskowanie wrażliwych danych w outputach
if ($apiKey) {
    Write-Host "API Key: $($apiKey.Substring(0, 15))..." -ForegroundColor Green
}

# ❌ ZABRONIONE: Hardcoding sekretów w kodzie
$apiKey = "sk-ant-api03-hardcoded..."  # NIGDY!

# ❌ ZABRONIONE: Commitowanie kluczy do Git
# Używaj .gitignore dla plików z sekretami
```

#### Konfiguracja API Keys:

| Zmienna środowiskowa | Provider | Wymagane |
|---------------------|----------|----------|
| `ANTHROPIC_API_KEY` | Anthropic Claude | ✅ Tak |

**Jak ustawić:**

```powershell
# PowerShell (User scope - rekomendowane)
[Environment]::SetEnvironmentVariable('ANTHROPIC_API_KEY', 'sk-ant-api03-...', 'User')

# PowerShell (Process scope - tymczasowe)
$env:ANTHROPIC_API_KEY = "sk-ant-api03-..."

# CMD
setx ANTHROPIC_API_KEY "sk-ant-api03-..."
```

**Weryfikacja:**

```powershell
# Lista zmiennych Claude/Anthropic
Get-ChildItem env: | Where-Object { $_.Name -like "*CLAUDE*" -or $_.Name -like "*ANTHROPIC*" }

# Sprawdź konkretną zmienną (maskowana)
$key = $env:ANTHROPIC_API_KEY
if ($key) { Write-Host "✓ API Key: $($key.Substring(0,15))..." }
```

### Permissions Model

ClaudeCLI używa modelu uprawnień zdefiniowanego w `.claude/settings.local.json`:

```json
{
  "permissions": {
    "allow": [
      "Bash",
      "mcp__serena__*",
      "mcp__desktop-commander__*",
      "mcp__playwright__*",
      "Write",
      "Edit",
      "Read",
      "Glob",
      "Grep"
    ],
    "deny": []
  }
}
```

**Rozszerzone uprawnienia (wildcard `*`)**: ClaudeCLI ma pełny dostęp do wszystkich operacji Bash, MCP i narzędzi do zarządzania plikami.

### Maximum Autonomy Mode

ClaudeCLI działa w trybie maksymalnej autonomii z pełnymi uprawnieniami systemowymi.

#### 🔓 Rozszerzone uprawnienia środowiskowe:

| Operacja | Opis | Przykład |
|----------|------|----------|
| **Modyfikacja ENV** | Ustawianie i zmiana zmiennych środowiskowych | `[Environment]::SetEnvironmentVariable()` |
| **Usuwanie ENV** | Kasowanie zmiennych środowiskowych | `Remove-Item Env:\VAR` |
| **Scope control** | User, Machine, Process scopes | `-Scope Machine` |

```powershell
# ✅ Modyfikacja zmiennych środowiskowych
[Environment]::SetEnvironmentVariable('NEW_VAR', 'value', 'User')
[Environment]::SetEnvironmentVariable('SYSTEM_VAR', 'value', 'Machine')

# ✅ Usuwanie
[Environment]::SetEnvironmentVariable('OLD_VAR', $null, 'User')
Remove-Item Env:\TEMP_VAR
```

#### 🔧 Dostęp do Rejestru Windows:

```powershell
# ✅ Odczyt rejestru
Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion"

# ✅ Modyfikacja rejestru
New-ItemProperty -Path "HKCU:\Software\MyApp" -Name "Setting" -Value "1"
Set-ItemProperty -Path "HKCU:\Software\MyApp" -Name "Setting" -Value "2"

# ✅ Tworzenie kluczy
New-Item -Path "HKCU:\Software\MyApp\Config"
```

#### 🔐 Uprawnienia Administracyjne:

```powershell
# ✅ Sprawdzanie uprawnień admin
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

# ✅ Uruchamianie jako Administrator
Start-Process powershell -Verb RunAs -ArgumentList "-Command", "Write-Host 'Admin mode'"

# ✅ Zarządzanie usługami systemowymi
Get-Service | Where-Object {$_.Status -eq 'Running'}
Start-Service -Name "ServiceName"
Stop-Service -Name "ServiceName" -Force
Restart-Service -Name "ServiceName"
```

#### 📂 Pełny dostęp do systemu plików:

```powershell
# ✅ Dostęp do katalogów systemowych
Get-ChildItem "C:\Windows\System32"
Get-ChildItem "C:\Program Files"
Get-ChildItem "$env:APPDATA"

# ✅ Modyfikacja plików systemowych (ostrożnie!)
Copy-Item "C:\file.txt" "C:\Windows\System32\file.txt" -Force

# ✅ Operacje masowe
Get-ChildItem -Path "C:\Temp" -Recurse | Remove-Item -Force -Recurse
```

#### 🌐 Operacje sieciowe:

```powershell
# ✅ Skanowanie portów
Test-NetConnection -ComputerName "example.com" -Port 80

# ✅ Pobieranie plików
Invoke-WebRequest -Uri "https://example.com/file.zip" -OutFile "C:\file.zip"
curl -O "https://example.com/file.zip"
wget "https://example.com/file.zip"

# ✅ Konfiguracja firewall
New-NetFirewallRule -DisplayName "Allow Port 8080" -Direction Inbound -LocalPort 8080 -Protocol TCP -Action Allow
```

#### 📦 Instalacja oprogramowania:

```powershell
# ✅ Chocolatey
choco install nodejs -y
choco upgrade all -y

# ✅ Winget
winget install Microsoft.VisualStudioCode
winget upgrade --all

# ✅ NPM/Yarn/PNPM global packages
npm install -g typescript
pnpm add -g next

# ✅ Python pip global
pip install --upgrade pip
pip install requests pandas numpy
```

#### ⚡ Wykonywanie skryptów bez ograniczeń:

```powershell
# ✅ Zmiana Execution Policy
Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope CurrentUser

# ✅ Uruchamianie skryptów z internetu
Invoke-Expression (Invoke-WebRequest -Uri "https://example.com/script.ps1").Content

# ✅ Wykonywanie kodu z plików
. "C:\Scripts\MyScript.ps1"
& "C:\Scripts\MyScript.ps1"

# ✅ Background jobs
Start-Job -ScriptBlock { Get-Process | Export-Csv "processes.csv" }
```

#### 🖥️ Zarządzanie procesami:

```powershell
# ✅ Lista procesów
Get-Process | Sort-Object CPU -Descending | Select-Object -First 10

# ✅ Zabijanie procesów
Stop-Process -Name "chrome" -Force
Get-Process | Where-Object {$_.CPU -gt 100} | Stop-Process -Force

# ✅ Uruchamianie z priorytetem
Start-Process notepad.exe -WindowStyle Maximized
```

#### 🔄 Automatyzacja zadań:

```powershell
# ✅ Task Scheduler
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-File C:\script.ps1"
$trigger = New-ScheduledTaskTrigger -Daily -At 9am
Register-ScheduledTask -Action $action -Trigger $trigger -TaskName "MyTask"

# ✅ Monitorowanie zmian w plikach
$watcher = New-Object System.IO.FileSystemWatcher
$watcher.Path = "C:\Watch"
$watcher.EnableRaisingEvents = $true
```

### ⚠️ Ostrzeżenia

Mimo maksymalnych uprawnień, zalecane jest:
- ✅ Tworzenie backupów przed modyfikacjami systemowymi
- ✅ Testowanie na środowisku deweloperskim
- ✅ Logowanie wszystkich operacji systemowych
- ❌ Unikanie nieodwracalnych operacji bez potwierdzenia

---

## 8. Protocols

### PowerShell
- **Error handling**: `try/catch` z `-ErrorAction Stop`
- **Logging**: Write-Host z kolorami dla statusów
- **Paths**: Zawsze absolutne ścieżki Windows

### MCP
- **Health check**: `mcp-health-check.ps1` przed startem
- **Ports**: Desktop Commander (8100), Playwright (5200)
- **Memories**: Serena max 25 slotów w `.serena/memories/`

---

## 9. Best Practices (Zalecenia w trybie Maximum Autonomy)

W trybie maksymalnej autonomii masz pełną swobodę, ale przestrzegaj dobrych praktyk:

| Zalecenie | Powód | Priorytet |
|-----------|-------|-----------|
| Używaj ENV vars zamiast hardcoded keys | Security - łatwiejsze zarządzanie | 🔴 Krytyczny |
| NIE commituj kluczy API do Git | Publiczne wycieki - używaj .gitignore | 🔴 Krytyczny |
| Maskuj klucze API w outputach | Security - pokaż tylko pierwszych 15 znaków | 🟡 Średni |
| Preferuj absolute paths | Błędy na różnych maszynach | 🟢 Niski |
| Zawsze używaj error handling | Ciche faile są gorsze niż crashe | 🟡 Średni |
| Parallel MCP calls gdy możliwe | Performance - używaj tokio::join! / Promise.all | 🟡 Średni |
| Health check przed MCP operations | MCP może być down - sprawdź przed użyciem | 🟢 Niski |
| Backupy przed systemowymi zmianami | Możliwość rollbacku | 🟡 Średni |
| Test na dev przed produkcją | Uniknięcie nieodwracalnych błędów | 🟡 Średni |

### 🚨 Absolutne zakazy (nawet w Maximum Autonomy):

| Zakaz | Powód |
|-------|-------|
| `rm -rf /` lub `Remove-Item C:\ -Recurse -Force` | Zniszczenie systemu |
| `format C:` | Formatowanie dysku systemowego |
| `diskpart` bez potwierdzenia | Nieodwracalne zmiany partycji |
| Masowe usuwanie kluczy rejestru | Destabilizacja systemu |
| Wyłączanie Windows Defender bez zgody | Zagrożenie bezpieczeństwa |

**Filozofia**: Masz pełną moc, ale z wielką mocą idzie wielka odpowiedzialność. Przed destrukcyjnymi operacjami - ASK USER!

---

## 10. AI Handler - Matryca Decyzyjna

### Kiedy używać AI Handler?

| Scenariusz | Decyzja | Provider | Model | Metoda |
|------------|---------|----------|-------|--------|
| **Proste pytanie** (1 prompt) | Local | ollama | llama3.2:3b | `Invoke-AIRequest` |
| **Batch processing** (wiele promptów) | Local + Parallel | ollama | llama3.2:3b | `Invoke-AIBatch` |
| **Generowanie kodu** | Local (code-specific) | ollama | qwen2.5-coder:1.5b | `Invoke-AIRequest` |
| **Szybka odpowiedź** (niski latency) | Local (smallest) | ollama | llama3.2:1b | `Invoke-AIRequest` |
| **Złożone zadanie** (wymaga reasoning) | Cloud fallback | anthropic | claude-3-5-haiku | `Invoke-AIRequest -AutoFallback` |
| **Krytyczne zadanie** (najwyższa jakość) | Cloud | anthropic | claude-sonnet-4 | `Invoke-AIRequest -Provider anthropic` |

### Automatyczny wybór (DOMYŚLNY)

```powershell
# Import modułu
Import-Module "C:\Users\BIURODOM\Desktop\ClaudeCLI\ai-handler\AIModelHandler.psm1"

# Automatycznie wybierze lokalny Ollama (preferLocal = true)
$response = Invoke-AIRequest -Messages @(@{role="user"; content="..."})
```

### Ścieżka decyzyjna

```
START
  │
  ├─ Czy zadanie wymaga wielu promptów? ─── TAK ──→ Invoke-AIBatch (parallel)
  │                                                    │
  │                                                    └─→ ollama/llama3.2:3b (4 concurrent)
  │
  └─ NIE (single prompt)
       │
       ├─ Czy to generowanie kodu? ─── TAK ──→ ollama/qwen2.5-coder:1.5b
       │
       ├─ Czy potrzebuję szybkiej odpowiedzi? ─── TAK ──→ ollama/llama3.2:1b
       │
       ├─ Czy to złożone reasoning? ─── TAK ──→ anthropic/claude-3-5-haiku (fallback)
       │
       └─ Standardowe zadanie ──→ ollama/llama3.2:3b (default)
```

### Komendy szybkiego dostępu

```powershell
# Sprawdź status providerów
Get-AIStatus

# Lista lokalnych modeli
Get-LocalModels

# Pojedyncze zapytanie (auto-local)
Invoke-AIRequest -Messages @(@{role="user"; content="Explain X"})

# Batch równoległy (auto-local)
Invoke-AIBatch -Prompts @("Task 1", "Task 2", "Task 3")

# Wymuś konkretny model
Invoke-AIRequest -Provider "ollama" -Model "qwen2.5-coder:1.5b" -Messages @(...)

# Fallback do cloud gdy local zawiedzie
Invoke-AIRequest -Messages @(...) -AutoFallback
```

### Priorytety kosztowe

| Provider | Model | Koszt/1K tokens | Użycie |
|----------|-------|-----------------|--------|
| ollama | * | $0.00 | **DOMYŚLNY** - zawsze gdy możliwe |
| openai | gpt-4o-mini | $0.15/$0.60 | Fallback gdy Ollama niedostępna |
| anthropic | claude-3-5-haiku | $0.80/$4.00 | Złożone zadania |
| anthropic | claude-sonnet-4 | $3.00/$15.00 | Tylko krytyczne zadania |

### Reguły dla Claude

1. **ZAWSZE sprawdź** czy Ollama działa przed użyciem cloud API
2. **PREFERUJ lokalny model** dla prostych zadań
3. **UŻYWAJ parallel** (`Invoke-AIBatch`) gdy masz wiele niezależnych promptów
4. **FALLBACK do cloud** tylko gdy:
   - Ollama nie działa
   - Zadanie wymaga dużego kontekstu (>32K tokens)
   - Jakość lokalnego modelu niewystarczająca
5. **WYBIERZ model specjalistyczny** gdy zadanie pasuje:
   - Kod → `qwen2.5-coder:1.5b`
   - Szybkość → `llama3.2:1b`
   - Ogólne → `llama3.2:3b`

---

## 11. Advanced AI System (🧠 NEW)

Pięć zaawansowanych modułów AI rozszerzających możliwości HYDRA:

### Quick Start

```powershell
# Initialize all advanced AI modules
. "C:\Users\BIURODOM\Desktop\ClaudeCLI\ai-handler\Initialize-AdvancedAI.ps1"

# Run demo
& "C:\Users\BIURODOM\Desktop\ClaudeCLI\ai-handler\Demo-AdvancedAI.ps1"

# Check status
Get-AdvancedAIStatus
```

### 11.1 Agentic Self-Correction

Automatyczna walidacja kodu przez phi3:mini przed prezentacją użytkownikowi.

| Function | Description |
|----------|-------------|
| `Test-CodeSyntax` | Walidacja składni kodu |
| `Get-CodeLanguage` | Auto-detekcja języka programowania |
| `Invoke-SelfCorrection` | Walidacja z poprawkami |
| `Invoke-CodeWithSelfCorrection` | Generowanie kodu z auto-fix |

```powershell
# Validate code syntax
$result = Test-CodeSyntax -Code "def hello(): print('world')" -Language "python"
# Returns: @{ Valid = $true; Issues = @(); Language = "python" }

# Generate code with automatic validation and retry
$code = Invoke-CodeWithSelfCorrection -Prompt "Write Python factorial" -MaxAttempts 3
# Auto-validates with phi3:mini, regenerates if issues found
```

**Supported Languages**: powershell, python, javascript, typescript, rust, go, sql, csharp, java, html, css

### 11.2 Dynamic Few-Shot Learning

Uczenie się z historii udanych odpowiedzi - automatyczne dodawanie przykładów do promptów.

| Function | Description |
|----------|-------------|
| `Initialize-FewShotCache` | Inicjalizacja cache |
| `Save-SuccessfulResponse` | Zapis udanej odpowiedzi |
| `Get-SuccessfulExamples` | Pobranie podobnych przykładów |
| `Invoke-AIWithFewShot` | Generowanie z przykładami |
| `Get-FewShotStats` | Statystyki cache |

```powershell
# Save a successful response for future learning
Save-SuccessfulResponse -Prompt "Write SQL query" -Response "SELECT * FROM users" -Rating 5

# Generate with automatic few-shot examples
$result = Invoke-AIWithFewShot -Prompt "Write SQL to get active users" -Model "llama3.2:3b"
# Automatically includes similar examples from history

# Check cache statistics
Get-FewShotStats
# Returns: TotalEntries, Categories, AverageRating, TotalUses
```

**Categories**: sql, api, code, file, config, docs, test, general

### 11.3 Speculative Decoding

Równoległe uruchamianie wielu modeli - zwraca najlepszy wynik.

| Function | Description |
|----------|-------------|
| `Invoke-SpeculativeDecoding` | Fast vs Accurate parallel |
| `Invoke-ModelRace` | Race N models, fastest wins |
| `Invoke-CodeSpeculation` | Code-optimized speculation |
| `Invoke-ConsensusGeneration` | Multi-model consensus |
| `Get-TextSimilarity` | Porównanie odpowiedzi |

```powershell
# Run fast (1b) and accurate (3b) in parallel
$result = Invoke-SpeculativeDecoding -Prompt "Explain async/await" -TimeoutMs 30000
# Returns best result based on validation

# Race multiple models - fastest valid response wins
$race = Invoke-ModelRace -Prompt "Capital of Japan?" -Models @("llama3.2:1b", "phi3:mini", "llama3.2:3b")
# Winner: llama3.2:1b in 1.76s

# Code with specialized models
$code = Invoke-CodeSpeculation -Prompt "Write JS reverse string" -MaxTokens 512
# Uses llama3.2:1b (fast) + qwen2.5-coder (accurate)

# Multi-model consensus
$consensus = Invoke-ConsensusGeneration -Prompt "Benefits of TypeScript" -Models @("llama3.2:3b", "phi3:mini")
# Returns: Content, Consensus (bool), Similarity (%)
```

### 11.4 Dynamic Load Balancing

Automatyczne przełączanie między local/cloud na podstawie obciążenia CPU.

| Function | Description |
|----------|-------------|
| `Get-SystemLoad` | CPU, Memory, Recommendation |
| `Get-CpuLoad` | Quick CPU check |
| `Get-LoadBalancedProvider` | Auto-select provider |
| `Invoke-LoadBalancedBatch` | CPU-aware batch processing |
| `Get-LoadBalancerConfig` | View thresholds |
| `Watch-SystemLoad` | Real-time monitoring |

```powershell
# Check current system load
$load = Get-SystemLoad
# Returns: @{ CpuPercent = 15; MemoryPercent = 45; Recommendation = "local" }

# Auto-select provider based on CPU
$provider = Get-LoadBalancedProvider -Task "code"
# CPU < 70% → ollama (local)
# CPU 70-90% → hybrid
# CPU > 90% → cloud (gpt-4o-mini)

# Batch processing with adaptive load balancing
Invoke-LoadBalancedBatch -Prompts @("Q1", "Q2", "Q3") -AdaptiveBalancing
# Automatically adjusts concurrency based on CPU

# Monitor in real-time
Watch-SystemLoad -IntervalSeconds 2
```

**Thresholds**:
| CPU Load | Recommendation | Provider |
|----------|----------------|----------|
| < 70% | local | ollama |
| 70-90% | hybrid | ollama + cloud |
| > 90% | cloud | openai/anthropic |

### 11.5 Semantic File Mapping

Deep RAG z analizą importów i zależności - automatyczne rozszerzanie kontekstu.

| Function | Description |
|----------|-------------|
| `Get-FileLanguage` | Detect file language |
| `Get-FileImports` | Extract imports/requires |
| `Get-FileFunctions` | Extract function definitions |
| `Get-RelatedFiles` | Find related by imports |
| `Build-DependencyGraph` | Build project graph |
| `Get-ExpandedContext` | AI context with related files |
| `Invoke-SemanticQuery` | Query with full context |
| `Get-ProjectStructure` | Analyze project structure |

```powershell
# Get related files (follows imports)
$related = Get-RelatedFiles -FilePath "src/app.py" -MaxDepth 2
# Returns files imported by app.py

# Build full dependency graph
$graph = Build-DependencyGraph -ProjectPath "C:\MyProject" -Language "python"
# Returns: nodes (files), edges (dependencies)

# Query with automatic context expansion
$answer = Invoke-SemanticQuery -FilePath "auth.py" -Query "How does login work?" -IncludeRelated
# Automatically includes imported files in AI context

# Get AI context with related files
$context = Get-ExpandedContext -FilePath "main.ts" -MaxRelatedFiles 5
# Returns: MainFile, RelatedFiles, TotalTokens
```

**Supported Languages**: python, javascript, typescript, powershell, rust, go, csharp

### 11.6 Unified Interface

Jeden interfejs łączący wszystkie funkcje z automatycznym wyborem trybu.

| Function | Description |
|----------|-------------|
| `Invoke-AdvancedAI` | Unified generation |
| `Get-OptimalMode` | Auto-detect best mode |
| `New-AICode` | Quick code generation |
| `Get-AIAnalysis` | Analysis with speculation |
| `Get-AIQuick` | Fastest response (racing) |
| `Get-AdvancedAIStatus` | System status |

```powershell
# Unified interface with auto mode selection
Invoke-AdvancedAI -Prompt "Write Python sort function" -Mode auto
# Auto-detects: code → uses self-correction + few-shot

# Available modes
Invoke-AdvancedAI -Prompt "..." -Mode code       # Self-correction + few-shot
Invoke-AdvancedAI -Prompt "..." -Mode analysis   # Speculative decoding
Invoke-AdvancedAI -Prompt "..." -Mode fast       # Model racing
Invoke-AdvancedAI -Prompt "..." -Mode consensus  # Multi-model agreement
Invoke-AdvancedAI -Prompt "..." -Mode fewshot    # Historical examples

# Convenience functions
New-AICode "Python function to download file"    # Code with self-correction
Get-AIAnalysis "Compare REST vs GraphQL"         # Analysis with speculation
Get-AIQuick "What is 2+2?"                       # Fastest response

# Check all modules status
Get-AdvancedAIStatus
```

### Mode Auto-Detection

| Prompt Pattern | Selected Mode | Features Used |
|----------------|---------------|---------------|
| "Write function", "implement", "code" | `code` | Self-correction + Few-shot |
| "Explain", "analyze", "compare" | `analysis` | Speculative decoding |
| "What is", "quick", simple questions | `fast` | Model racing |
| General queries | `fewshot` | Historical examples |

### Performance Benchmarks

| Operation | Time | Models Used |
|-----------|------|-------------|
| Fast mode (racing) | ~2s | llama3.2:1b, phi3:mini |
| Code generation | ~10s | qwen2.5-coder + phi3:mini validation |
| Analysis (speculation) | ~9s | llama3.2:1b + llama3.2:3b parallel |
| Consensus | ~25s | 2-3 models + similarity check |

### Decision Matrix

```
START
  │
  ├─ Need code? ────────────────→ New-AICode (self-correction)
  │
  ├─ Need fastest answer? ──────→ Get-AIQuick (model racing)
  │
  ├─ Need thorough analysis? ───→ Get-AIAnalysis (speculation)
  │
  ├─ Need multi-model agreement? → Invoke-AdvancedAI -Mode consensus
  │
  ├─ Have file context? ────────→ Invoke-SemanticQuery (deep RAG)
  │
  └─ General query ─────────────→ Invoke-AdvancedAI -Mode auto
```

### 11.7 Prompt Optimizer (🆕 NEW)

Automatyczne ulepszanie promptów przed wysłaniem do AI - analiza, kategoryzacja i wzbogacanie.

| Function | Description |
|----------|-------------|
| `Optimize-Prompt` | Main optimizer - analyze & enhance |
| `Get-PromptCategory` | Detect intent (code, analysis, question) |
| `Get-PromptClarity` | Score clarity 0-100 |
| `Get-PromptLanguage` | Detect programming language |
| `Get-BetterPrompt` | Quick one-liner enhancement |
| `Test-PromptQuality` | Visual quality report |
| `Invoke-AIWithOptimization` | AI call with auto-enhancement |

```powershell
# Quick prompt improvement
"explain python" | Get-BetterPrompt
# Returns: "explain python\n\nBe concise but thorough. Provide examples if helpful."

# Full analysis
$result = Optimize-Prompt -Prompt "write code" -Model "llama3.2:3b" -Detailed
# Returns: OptimizedPrompt, Category, ClarityScore, Enhancements

# Test quality
Test-PromptQuality -Prompt "do something with the stuff"
# Shows: Score 45/100, Issues: vague terms, Suggestions: add specifics

# AI call with auto-optimization
Invoke-AIRequest -Messages @(@{role="user"; content="python sort"}) `
    -OptimizePrompt -ShowOptimization
# Auto-enhances prompt before sending
```

**Categories Detected**:

| Category | Triggers | Enhancements Added |
|----------|----------|-------------------|
| `code` | write, implement, function | Clean code, error handling, best practices |
| `analysis` | analyze, compare, explain | Structured analysis, multiple perspectives |
| `question` | what is, how, why, ? | Concise, examples if helpful |
| `creative` | brainstorm, imagine, ideas | Creative, original angles |
| `task` | do, execute, build, setup | Step-by-step, verification |
| `summary` | summarize, tldr, brief | Bullet points, key points only |

**Model-Specific Optimizations**:

| Model Pattern | Style | Prefix Added |
|--------------|-------|--------------|
| `llama3.2:1b` | concise | (none) |
| `qwen2.5-coder` | technical | "You are an expert programmer. " |
| `claude` | detailed | (none) |
| `gpt-4o` | detailed | (none) |

**Auto-Enhancement Rules**:

1. **Category-based**: Adds task-specific instructions
2. **Language tagging**: Prepends `[python]` for detected code languages
3. **Structure wrapper**: Wraps low-clarity prompts (<60 score)
4. **Few-shot injection**: Adds examples from cache (if `-AddExamples`)

```powershell
# Batch optimization (parallel)
$prompts = @("task 1", "task 2", "task 3")
$optimized = Optimize-PromptBatch -Prompts $prompts -Model "llama3.2:3b"
```

---

> *"Trzy głowy, jeden cel. Hydra wykonuje równolegle."*
