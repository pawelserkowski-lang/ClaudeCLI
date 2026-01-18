# AI Handler - Refactored Architecture

Version: 2.0.0 | HYDRA 10.1

## Overview

The AI Handler provides comprehensive AI model management with automatic fallback, rate limiting, cost optimization, and multi-provider support. This refactored architecture separates concerns into focused modules for better maintainability and extensibility.

## Directory Structure

```
ai-handler/
├── AIModelHandler.psm1          # Main module (facade)
├── ai-config.json               # Provider/model configuration
├── ai-state.json                # Runtime state (auto-generated)
├── Initialize-AIHandler.ps1     # Setup script
├── Initialize-AdvancedAI.ps1    # Advanced features loader
├── Invoke-AI.ps1                # Quick CLI wrapper
├── Demo-AdvancedAI.ps1          # Advanced features demo
│
├── core/                        # Core infrastructure
│   └── AIConstants.psm1         # Centralized constants and paths
│
├── utils/                       # Utility functions
│   └── (shared helpers)
│
├── rate-limiting/               # Rate limit management
│   └── (rate limit tracking, warnings)
│
├── model-selection/             # Model selection logic
│   └── (optimal model selection, task mapping)
│
├── providers/                   # Provider-specific implementations
│   └── (Anthropic, OpenAI, Ollama, etc.)
│
├── fallback/                    # Fallback chain management
│   └── (automatic retry, provider switching)
│
├── modules/                     # Advanced AI modules
│   ├── SelfCorrection.psm1      # Agentic self-correction
│   ├── FewShotLearning.psm1     # Dynamic few-shot learning
│   ├── SpeculativeDecoding.psm1 # Parallel multi-model
│   ├── LoadBalancer.psm1        # CPU-aware load balancing
│   ├── SemanticFileMapping.psm1 # Deep RAG with imports
│   ├── PromptOptimizer.psm1     # Auto prompt enhancement
│   └── AdvancedAI.psm1          # Unified interface
│
└── cache/                       # Few-shot learning cache
```

## Core Components

### AIConstants.psm1

Centralized configuration for the entire AI Handler system:

| Variable | Description |
|----------|-------------|
| `$Paths` | File system locations (config, state, cache) |
| `$Thresholds` | Operational limits (rate limits, retries, timeouts) |
| `$ProviderPriority` | Provider fallback order |
| `$TierScores` | Quality tier numerical scores |
| `$TaskTierMap` | Task type to tier mapping |
| `$ModelCapabilities` | Feature flags (vision, code, long context) |
| `$ErrorCodes` | Standardized error identification |

### Usage

```powershell
# Import constants
Import-Module "$PSScriptRoot\core\AIConstants.psm1"

# Access paths
$configPath = $Paths.Config

# Check thresholds
if ($usage -gt $Thresholds.RateLimitWarning) {
    Write-Warning "Approaching rate limit"
}

# Get provider priority
$fallbackProvider = $ProviderPriority | Select-Object -Skip 1 -First 1
```

## Architecture Principles

1. **Separation of Concerns**: Each directory handles one aspect of AI management
2. **Single Source of Truth**: All constants in AIConstants.psm1
3. **Facade Pattern**: AIModelHandler.psm1 provides unified interface
4. **Fail-Safe Defaults**: Sensible defaults in all configurations
5. **Local-First**: Prefer Ollama (cost $0) when available

## Module Responsibilities

| Directory | Responsibility |
|-----------|----------------|
| `core/` | Constants, configuration, shared infrastructure |
| `utils/` | Common utility functions (logging, formatting) |
| `rate-limiting/` | Track usage, warn on limits, trigger fallback |
| `model-selection/` | Choose optimal model for task type and budget |
| `providers/` | Provider-specific API implementations |
| `fallback/` | Manage retry logic and provider switching |
| `modules/` | Advanced AI features (self-correction, RAG, etc.) |

## Quick Start

```powershell
# Initialize AI Handler
. "C:\Users\BIURODOM\Desktop\ClaudeHYDRA\ai-handler\Initialize-AIHandler.ps1"

# Quick AI call (auto-selects local/cloud)
ai "Your question here"

# Check status
Get-AIStatus

# Use advanced features
. "C:\Users\BIURODOM\Desktop\ClaudeHYDRA\ai-handler\Initialize-AdvancedAI.ps1"
New-AICode "Write Python function to parse JSON"
```

## Configuration

Edit `ai-config.json` to customize:

```json
{
  "settings": {
    "maxRetries": 3,
    "retryDelayMs": 1000,
    "rateLimitThreshold": 0.85,
    "costOptimization": true,
    "autoFallback": true,
    "preferLocal": true
  }
}
```

## Environment Variables

| Variable | Provider | Required |
|----------|----------|----------|
| `ANTHROPIC_API_KEY` | Anthropic | For Claude models |
| `OPENAI_API_KEY` | OpenAI | For GPT models |
| `GOOGLE_API_KEY` | Google | For Gemini models |
| (none) | Ollama | Local, no key needed |

## Fallback Chain

```
Default: Anthropic -> OpenAI -> Google -> Mistral -> Groq -> Ollama

Anthropic: Opus 4.5 -> Sonnet 4.5 -> Haiku 4
OpenAI:    GPT-4o -> GPT-4o-mini
Ollama:    llama3.2:3b -> qwen2.5-coder:1.5b -> llama3.2:1b
```

## Contributing

When adding new functionality:

1. Place constants in `core/AIConstants.psm1`
2. Add provider-specific code to `providers/`
3. Keep modules focused on single responsibility
4. Export functions via `Export-ModuleMember`
5. Document with comment-based help

---

*Part of HYDRA 10.1 - "Three heads, one goal. Hydra executes in parallel."*
