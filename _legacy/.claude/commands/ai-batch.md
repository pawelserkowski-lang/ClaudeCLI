---
description: "Parallel batch AI queries using local Ollama (cost=$0)"
---

# /ai-batch - Parallel Batch AI Queries

Execute multiple AI queries in parallel using local Ollama. Zero cost, maximum speed.

## Usage

```
/ai-batch "Query 1; Query 2; Query 3"
/ai-batch -File "path/to/queries.txt"
```

## Examples

```
/ai-batch "What is 2+2?; What is 3*3?; What is 10/2?"
/ai-batch "Translate hello to Spanish; Translate hello to French; Translate hello to German"
/ai-batch "Summarize AI; Summarize ML; Summarize DL"
```

## Instructions for Claude

When the user invokes `/ai-batch`, execute this command using Bash tool:

```bash
powershell -ExecutionPolicy Bypass -File "C:\Users\BIURODOM\Desktop\ClaudeCLI\ai-handler\Invoke-QuickAIBatch.ps1" $ARGUMENTS
```

**Flags:**
- `-File <path>` - Load queries from file (one per line)
- `-Model <name>` - Use specific model (default: llama3.2:3b)
- `-MaxConcurrent <N>` - Max parallel requests (default: 4)
- `-MaxTokens <N>` - Max tokens per response (default: 512)

**Query Format:**
- Semicolon-separated: `"Query 1; Query 2; Query 3"`
- From file: `-File queries.txt` (one query per line)

## Performance

| Queries | Sequential | Parallel (4x) | Speedup |
|---------|------------|---------------|---------|
| 4 | ~20s | ~5s | 4x |
| 8 | ~40s | ~10s | 4x |
| 12 | ~60s | ~15s | 4x |

## Cost

**$0.00** - all queries processed locally via Ollama.

## Queries: $ARGUMENTS
