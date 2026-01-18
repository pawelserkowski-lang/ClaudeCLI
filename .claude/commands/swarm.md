# Agent Swarm - 12 Witcher Agents

Execute complex tasks using the 6-Step Swarm Protocol with 12 specialized Witcher agents.

## Arguments
- `$ARGUMENTS` - The query/task to execute

## Instructions

1. Import the AgentSwarm module if not loaded:
```powershell
Import-Module "C:\Users\BIURODOM\Desktop\ClaudeHYDRA\ai-handler\modules\AgentSwarm.psm1" -Force
```

2. Execute the swarm with the user's query:
```powershell
Invoke-AgentSwarm -Query "$ARGUMENTS"
```

3. The 6-Step Protocol will execute:
   - **Step 1 (Speculate)**: Regis gathers context
   - **Step 2 (Plan)**: Dijkstra creates task breakdown
   - **Step 3 (Execute)**: Agents run in parallel via RunspacePool
   - **Step 4 (Synthesize)**: Vesemir merges results
   - **Step 5 (Log)**: Jaskier creates summary
   - **Step 6 (Archive)**: Save transcript to `swarm-logs/`

## Available Agents

| Agent | Role | Model |
|-------|------|-------|
| Geralt | Security/Ops | llama3.2:3b |
| Yennefer | Architecture/Code | qwen2.5-coder:1.5b |
| Triss | QA/Testing | qwen2.5-coder:1.5b |
| Jaskier | Docs/Communication | llama3.2:3b |
| Vesemir | Mentoring/Review | llama3.2:3b |
| Ciri | Speed/Quick | llama3.2:1b |
| Eskel | DevOps/Infrastructure | llama3.2:3b |
| Lambert | Debugging/Profiling | qwen2.5-coder:1.5b |
| Zoltan | Data/Database | llama3.2:3b |
| Regis | Research/Analysis | phi3:mini |
| Dijkstra | Planning/Strategy | llama3.2:3b |
| Philippa | Integration/API | qwen2.5-coder:1.5b |

## Quick Commands

```powershell
# Full swarm
Invoke-AgentSwarm -Query "Implement user authentication"

# Quick single agent
Invoke-QuickAgent -Query "Write unit test" -Agent "Triss"

# List all agents
Get-SwarmAgents

# Check swarm stats
Get-SwarmStats
```

## YOLO Mode

Enable fast mode (10 threads, 15s timeout):
```powershell
Set-YoloMode -Enable
```

Disable YOLO mode:
```powershell
Set-YoloMode -Disable
```
