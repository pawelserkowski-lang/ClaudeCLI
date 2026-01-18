---
description: "Check AI providers, models and configuration status"
---

# /ai-status - AI Handler Status

Display status of all AI providers, local models, configuration and costs.

## Usage

```
/ai-status
/ai-status -Test
```

## Instructions for Claude

When the user invokes `/ai-status`, execute this command using Bash tool:

```bash
powershell -ExecutionPolicy Bypass -File "C:\Users\BIURODOM\Desktop\ClaudeHYDRA\ai-handler\Invoke-AIStatus.ps1" $ARGUMENTS
```

**Flags:**
- `-Test` - Run connectivity test for each provider (sends test request)
- `-Models` - Show detailed model information

## What It Shows

1. **PROVIDERS** - Status of ollama, openai, anthropic (API keys, connectivity)
2. **LOCAL MODELS** - Installed Ollama models with sizes
3. **CONFIGURATION** - preferLocal, autoFallback, costOptimization settings
4. **FALLBACK CHAIN** - Model fallback order per provider
5. **CONNECTIVITY TEST** - (with -Test flag) Response time for each provider
6. **COST SUMMARY** - Price per 1K tokens for each model

## Arguments: $ARGUMENTS
