---
description: "Configure AI Handler settings (providers, models, parallel)"
---

# /ai-config - AI Handler Configuration

View and modify AI Handler settings.

## Usage

```
/ai-config -Show
/ai-config -PreferLocal true
/ai-config -DefaultModel llama3.2:1b
/ai-config -MaxConcurrent 8
/ai-config -Priority "anthropic,openai,ollama"
/ai-config -Reset
```

## Instructions for Claude

When the user invokes `/ai-config`, execute this command using Bash tool:

```bash
powershell -ExecutionPolicy Bypass -File "C:\Users\BIURODOM\Desktop\ClaudeCLI\ai-handler\Invoke-AIConfig.ps1" $ARGUMENTS
```

## Available Options

| Option | Values | Description |
|--------|--------|-------------|
| `-Show` | - | Display current configuration |
| `-PreferLocal` | true/false | Prefer local Ollama over cloud |
| `-AutoFallback` | true/false | Auto fallback on provider error |
| `-CostOptimization` | true/false | Optimize for lowest cost |
| `-DefaultModel` | model name | Default Ollama model |
| `-MaxConcurrent` | 1-16 | Max parallel requests |
| `-Timeout` | ms | Request timeout in milliseconds |
| `-Priority` | providers | Provider order (comma-separated) |
| `-Reset` | - | Reset to default configuration |

## Quick Presets

**Local-First (default):**
```
/ai-config -PreferLocal true -Priority "ollama,openai,anthropic"
```

**Cloud-First:**
```
/ai-config -PreferLocal false -Priority "anthropic,openai,ollama"
```

**Maximum Parallel:**
```
/ai-config -MaxConcurrent 8
```

**Fast Mode:**
```
/ai-config -DefaultModel llama3.2:1b
```

**Quality Mode:**
```
/ai-config -DefaultModel llama3.2:3b
```

## Arguments: $ARGUMENTS
