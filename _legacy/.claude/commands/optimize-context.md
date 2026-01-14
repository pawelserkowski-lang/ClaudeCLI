# Context Optimization Dashboard

Display the context optimization status and provide recommendations for token savings.

## Instructions

Run the Context Optimizer status check and display results:

```powershell
# Load the module
Import-Module "C:\Users\BIURODOM\Desktop\ClaudeCLI\ai-handler\modules\ContextOptimizer.psm1" -Force

# Show comprehensive status
Show-OptimizationStatus
```

## Available Commands

After showing status, inform the user about available optimization actions:

### MCP Cache Management
```powershell
# Clear old cache entries (older than 30 minutes)
Clear-MCPCache -OlderThanMinutes 30

# Get cache statistics
Get-MCPCacheStats
```

### Context Compression
```powershell
# Compress long text to target tokens
$compressed = Compress-Context -Text $longText -MaxTokens 2000 -Strategy "smart"

# Estimate tokens
Get-TokenEstimate -Text "Your text here" -Language "auto"
```

### Serena Memories
```powershell
# List all memories with token counts
Get-AllSerenaMemories | Format-Table

# Save session notes to Serena
Update-SessionMemory

# Save custom memory
Save-ToSerenaMemory -Name "my_notes" -Content "Important info..." -Category "session_notes"
```

### Session Tracking
```powershell
# View current session state
Get-SessionState

# Record important decision
Add-SessionDecision "Decided to use approach X for feature Y"

# Reset for new session
Reset-SessionState
```

## Token Optimization Tips

1. **Use MCP Cache**: Read-only MCP calls are cached for 5 minutes
2. **Compress Context**: Use `Compress-Context` for long outputs before passing to AI
3. **Session Notes**: Call `Update-SessionMemory` periodically to persist important context
4. **Check Token Usage**: Use `Get-ContextTokenUsage` to analyze where tokens are spent

## Integration

The optimizer integrates with:
- **Serena MCP**: Persistent memory storage (25 slots)
- **AI Handler**: Token-aware model selection
- **Session State**: Cross-message context preservation
