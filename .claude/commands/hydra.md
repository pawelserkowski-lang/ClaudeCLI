---
description: "HYDRA 10.1 - Four-Headed Beast (Serena + DC + Playwright + Swarm)"
---

# HYDRA 10.1 - Four-Headed Beast

**Status: ACTIVE** | Unified Orchestration | MCP + Agent Swarm

```
┌─────────────────────────────────────────────────────────────────┐
│  🐉 HYDRA 10.1 - Four-Headed Beast                              │
│  ════════════════════════════════════════════════════════       │
│  [●] Serena            → Symbolic code analysis                 │
│  [●] Desktop Commander → System operations                      │
│  [●] Playwright        → Browser automation                     │
│  [●] Agent Swarm       → 12 Witcher Agents (parallel AI)        │
│                                                                 │
│  Mode: MCP + RunspacePool │ YOLO: $YOLO_STATUS                  │
└─────────────────────────────────────────────────────────────────┘
```

## THE FOUR HEADS

| Head | Purpose | Key Tools/Agents |
|------|---------|------------------|
| 🧠 **Serena** | Code Intelligence | `find_symbol`, `replace_symbol_body`, `get_symbols_overview` |
| ⚡ **Desktop Commander** | System Power | `start_process`, `read_file`, `write_file` |
| 🌐 **Playwright** | Browser Automation | `browser_navigate`, `browser_click`, `browser_snapshot` |
| 🐺 **Agent Swarm** | Parallel AI | Geralt, Yennefer, Triss, Ciri + 8 more |

## UNIFIED WORKFLOWS

### 1. Code Analysis + AI Review
```powershell
# MCP: Get code structure
mcp__serena__get_symbols_overview("src/")

# Swarm: AI analysis
Invoke-AgentSwarm -Query "Review this code architecture" -Agents @("Vesemir", "Yennefer")
```

### 2. Implement Feature (Full Stack)
```powershell
# Step 1: Plan with Dijkstra
Invoke-QuickAgent -Query "Plan implementation of: $FEATURE" -Agent "Dijkstra"

# Step 2: Code with Yennefer (via Serena)
mcp__serena__find_symbol("TargetComponent")
mcp__serena__replace_symbol_body("TargetComponent", $newCode)

# Step 3: Test with Triss
Invoke-QuickAgent -Query "Write tests for: $FEATURE" -Agent "Triss"
mcp__desktop-commander__start_process("pnpm test")

# Step 4: E2E with Playwright
mcp__playwright__browser_navigate("http://localhost:3000")
mcp__playwright__browser_snapshot()
```

### 3. Debug Workflow
```powershell
# Parallel: Gather context
mcp__serena__find_symbol("ErrorComponent")
mcp__desktop-commander__read_file("error.log")

# Swarm: Analyze with Lambert (debugger)
Invoke-QuickAgent -Query "Analyze this error: $ERROR" -Agent "Lambert"

# Fix via Serena
mcp__serena__replace_symbol_body("ErrorComponent", $fixedCode)

# Verify
mcp__desktop-commander__start_process("pnpm test")
```

### 4. Full Swarm Protocol
```powershell
# 6-Step Protocol (auto-routes to best agents)
Invoke-AgentSwarm -Query "$ARGUMENTS"

# Steps executed:
# 1. Speculate (Regis)     - Research context
# 2. Plan (Dijkstra)       - Create task JSON
# 3. Execute (Parallel)    - RunspacePool agents
# 4. Synthesize (Vesemir)  - Merge results
# 5. Log (Jaskier)         - Summary
# 6. Archive               - Save transcript
```

## YOLO MODE

Enable fast execution (10 threads, 15s timeout):

```powershell
# Toggle YOLO
Set-YoloMode -Enable    # Fast & Dangerous
Set-YoloMode -Disable   # Standard mode
Get-YoloStatus          # Check current mode
```

| Feature | Standard | YOLO |
|---------|----------|------|
| Concurrency | 5 | 10 |
| Timeout | 60s | 15s |
| Retries | 3 | 1 |

## AGENT ROUTING

| Task Pattern | Agent | Model |
|--------------|-------|-------|
| security, audit, scan | Geralt | llama3.2:3b |
| code, implement, function | Yennefer | qwen2.5-coder |
| test, validate, qa | Triss | qwen2.5-coder |
| doc, readme, explain | Jaskier | llama3.2:3b |
| review, refactor | Vesemir | llama3.2:3b |
| quick, fast, simple | Ciri | llama3.2:1b |
| deploy, ci, docker | Eskel | llama3.2:3b |
| debug, profile, perf | Lambert | qwen2.5-coder |
| data, database, sql | Zoltan | llama3.2:3b |
| research, analyze | Regis | phi3:mini |
| plan, strategy | Dijkstra | llama3.2:3b |
| api, integration | Philippa | qwen2.5-coder |

## PARALLEL EXECUTION

**READ-ONLY (parallel):**
- Serena: `find_symbol`, `get_symbols_overview`
- DC: `read_file`, `list_directory`
- Playwright: `browser_snapshot`
- Swarm: All agents via RunspacePool

**WRITE (sequential):**
- Serena: `replace_symbol_body`, `rename_symbol`
- DC: `write_file`, `start_process`
- Playwright: `browser_click`, `browser_fill`

## QUICK COMMANDS

```powershell
# Full swarm
Invoke-AgentSwarm -Query "Implement user auth"

# Single agent
Invoke-QuickAgent -Query "Write SQL query" -Agent "Zoltan"

# List agents
Get-SwarmAgents

# Check stats
Get-SwarmStats
```

## EXAMPLE: Complete Feature Implementation

```powershell
# 1. YOLO mode for speed
Set-YoloMode -Enable

# 2. Research with Swarm
Invoke-AgentSwarm -Query "Implement dark mode toggle"

# 3. Code via Serena
mcp__serena__find_symbol("ThemeProvider")
mcp__serena__replace_symbol_body("ThemeProvider", $darkModeCode)

# 4. Test
mcp__desktop-commander__start_process("pnpm test")

# 5. Visual verification
mcp__playwright__browser_navigate("http://localhost:3000")
mcp__playwright__browser_click("#dark-mode-toggle")
mcp__playwright__browser_screenshot("dark-mode.png")
```

---

ARGUMENTS: $ARGUMENTS
