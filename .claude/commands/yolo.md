# YOLO Mode Toggle

Toggle YOLO mode for Agent Swarm - fast execution with reduced safety.

## Arguments
- `$ARGUMENTS` - "on", "off", or "status" (default: toggle)

## Instructions

1. Import the AgentSwarm module if not loaded:
```powershell
Import-Module "C:\Users\BIURODOM\Desktop\ClaudeHYDRA\ai-handler\modules\AgentSwarm.psm1" -Force
```

2. Based on arguments:

**If "on" or "enable":**
```powershell
Set-YoloMode -Enable
```

**If "off" or "disable":**
```powershell
Set-YoloMode -Disable
```

**If "status" or no argument:**
```powershell
Get-YoloStatus
```

## Mode Comparison

| Feature | Standard | YOLO |
|---------|----------|------|
| Concurrency | 5 threads | 10 threads |
| Timeout | 60s | 15s |
| Retries | 3 | 1 |
| Risk Blocking | ON | OFF |

## Warning

YOLO mode disables safety guardrails for maximum speed. Use only in trusted environments.

## Examples

```powershell
# Enable YOLO
/yolo on

# Disable YOLO
/yolo off

# Check current status
/yolo status
```
