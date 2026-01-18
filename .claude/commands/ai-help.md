---
description: "Show all AI Handler commands"
---

# /ai-help - AI Handler Command Reference

Display all available AI commands with usage examples.

## Instructions for Claude

When the user invokes `/ai-help`, execute this command using Bash tool:

```bash
powershell -ExecutionPolicy Bypass -File "C:\Users\BIURODOM\Desktop\ClaudeHYDRA\ai-handler\Invoke-AIHelp.ps1"
```

## Commands Overview

| Command | Description |
|---------|-------------|
| `/ai` | Single local AI query |
| `/ai-batch` | Multiple parallel queries |
| `/ai-status` | Provider & model status |
| `/ai-config` | Configuration settings |
| `/ai-pull` | Download Ollama models |
| `/ai-help` | This help screen |
