---
description: "Quick local AI query using Ollama (cost=$0)"
---

# /ai - Quick Local AI Query

Execute a quick AI query using local Ollama models. Zero cost, fast response.

## Usage

```
/ai <your question or task>
```

## Examples

```
/ai explain this error: TypeError undefined is not a function
/ai write a regex to match email addresses
/ai translate to Polish: Hello, how are you?
/ai summarize: <paste text>
```

## Instructions for Claude

When the user invokes `/ai`, execute this command using Bash tool:

```bash
powershell -ExecutionPolicy Bypass -File "C:\Users\BIURODOM\Desktop\ClaudeCLI\ai-handler\Invoke-QuickAI.ps1" $ARGUMENTS
```

**Flags:**
- `-Code` - Force code-specialized model (qwen2.5-coder:1.5b)
- `-Fast` - Force fastest model (llama3.2:1b)
- `-MaxTokens N` - Set max output tokens (default: 1024)

**Auto-detection:**
The script automatically detects code queries and uses the appropriate model.

**Important:**
1. Always use local Ollama (cost=$0)
2. Display the full response to user
3. If Ollama not running, script auto-starts it

## Model Selection

| Query Type | Model | Why |
|------------|-------|-----|
| General questions | `llama3.2:3b` | Best quality |
| Code generation | `qwen2.5-coder:1.5b` | Code specialist |
| Quick/simple | `llama3.2:1b` | Fastest |
| Reasoning | `phi3:mini` | Better logic |

## Query: $ARGUMENTS
