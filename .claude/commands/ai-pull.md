---
description: "Pull/download Ollama models"
---

# /ai-pull - Download Ollama Models

Download new Ollama models or manage installed models.

## Usage

```
/ai-pull -List
/ai-pull -Popular
/ai-pull <model-name>
/ai-pull -Remove <model-name>
```

## Instructions for Claude

When the user invokes `/ai-pull`, execute this command using Bash tool:

```bash
powershell -ExecutionPolicy Bypass -File "C:\Users\BIURODOM\Desktop\ClaudeHYDRA\ai-handler\Invoke-AIPull.ps1" $ARGUMENTS
```

## Options

| Option | Description |
|--------|-------------|
| `-List` | List installed models with sizes |
| `-Popular` | Show popular models to download |
| `<model>` | Pull/download specified model |
| `-Remove <model>` | Remove an installed model |

## Popular Models

**General Purpose:**
- `llama3.2:1b` (1.3 GB) - Fast, lightweight
- `llama3.2:3b` (2.0 GB) - Balanced (recommended)
- `llama3.1:8b` (4.7 GB) - High quality
- `mistral:7b` (4.1 GB) - Strong reasoning

**Code Specialists:**
- `qwen2.5-coder:1.5b` (0.9 GB) - Fast code generation
- `qwen2.5-coder:7b` (4.7 GB) - Quality code generation
- `codellama:7b` (3.8 GB) - Meta's code model
- `deepseek-coder:6.7b` (3.8 GB) - DeepSeek code

**Reasoning:**
- `phi3:mini` (2.2 GB) - Microsoft reasoning
- `phi3:medium` (7.9 GB) - Larger reasoning

## Examples

```
/ai-pull -List              # Show installed
/ai-pull -Popular           # Show recommendations
/ai-pull mistral:7b         # Download mistral
/ai-pull codellama:7b       # Download codellama
/ai-pull -Remove phi3:mini  # Remove model
```

## Arguments: $ARGUMENTS
