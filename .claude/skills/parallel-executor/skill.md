# Parallel Executor Skill

**Name**: parallel-executor
**Description**: Execute tasks using all CPU cores with maximum parallelization
**Trigger**: /parallel, /par

## Capabilities

This skill leverages all available CPU cores for:
1. **MCP Tool Parallelization** - Multiple simultaneous MCP calls
2. **PowerShell Parallel** - ForEach-Object -Parallel with ThreadJobs
3. **Build Systems** - Parallel builds for Node, Rust, .NET, Python, Go
4. **Git Operations** - Parallel repo management
5. **File Operations** - Parallel read/write/search/compress

## Usage Patterns

### Pattern 1: Parallel MCP Calls
When user requests multiple independent operations, ALWAYS batch them:

```
// GOOD - Single message, multiple tool calls
[Tool Call 1: mcp__desktop-commander__read_file path=file1.txt]
[Tool Call 2: mcp__desktop-commander__read_file path=file2.txt]
[Tool Call 3: mcp__desktop-commander__start_search pattern=*.ts]
[Tool Call 4: mcp__serena__find_symbol name=MyClass]
```

### Pattern 2: Parallel File Operations
```powershell
# Import module
Import-Module "C:\Users\BIURODOM\Desktop\ClaudeHYDRA\parallel\modules\ParallelUtils.psm1"

# Read multiple files
$results = Read-FilesParallel -Paths @("file1.txt", "file2.txt", "file3.txt")

# Search in parallel
$matches = Search-FilesParallel -Paths @("src", "lib", "tests") -Pattern "TODO"

# Execute commands in parallel
$outputs = Invoke-CommandsParallel -Commands @("npm test", "npm run lint", "npm run build")
```

### Pattern 3: Parallel Builds
```powershell
# Build all projects in directory
& "C:\Users\BIURODOM\Desktop\ClaudeHYDRA\parallel\build\Build-Parallel.ps1" -Path "C:\Projects" -Test

# Run tests in parallel
& "C:\Users\BIURODOM\Desktop\ClaudeHYDRA\parallel\build\Test-Parallel.ps1" -Path "C:\Projects" -Type all

# Lint in parallel  
& "C:\Users\BIURODOM\Desktop\ClaudeHYDRA\parallel\build\Lint-Parallel.ps1" -Path "C:\Projects" -Fix
```

### Pattern 4: Parallel Git
```powershell
# Sync all repos
& "C:\Users\BIURODOM\Desktop\ClaudeHYDRA\parallel\scripts\Invoke-ParallelGit.ps1" -BasePath "C:\Repos" -Operation sync

# Status of all repos
& "C:\Users\BIURODOM\Desktop\ClaudeHYDRA\parallel\scripts\Invoke-ParallelGit.ps1" -BasePath "C:\Repos" -Operation status
```

### Pattern 5: Task DAG (Dependencies)
```powershell
$tasks = @{
    "install" = @{ Script = { npm install }; DependsOn = @() }
    "build" = @{ Script = { npm run build }; DependsOn = @("install") }
    "test" = @{ Script = { npm test }; DependsOn = @("build") }
    "lint" = @{ Script = { npm run lint }; DependsOn = @("install") }
    "deploy" = @{ Script = { npm run deploy }; DependsOn = @("test", "lint") }
}

& "C:\Users\BIURODOM\Desktop\ClaudeHYDRA\parallel\scripts\Invoke-TaskDAG.ps1" -Tasks $tasks
```

## Decision Matrix

| Task Type | Tool/Method | Parallelization |
|-----------|-------------|-----------------|
| Read files | `Read-FilesParallel` | All cores |
| Search code | `start_search` × N | Multiple sessions |
| Build projects | `Build-Parallel.ps1` | Per-project parallel |
| Run tests | `Test-Parallel.ps1` | `-n auto` / `--maxWorkers` |
| Git ops | `Invoke-ParallelGit.ps1` | All repos parallel |
| Downloads | `Invoke-ParallelDownload.ps1` | aria2c multi-connection |
| Compression | `Invoke-ParallelCompress.ps1` | 7z `-mmt=on` |

## Best Practices

1. **Always parallelize independent operations** - If tasks don't depend on each other, run them together
2. **Use ThreadJobs over Jobs** - `Start-ThreadJob` is faster than `Start-Job`
3. **Respect dependencies** - Use Task DAG for dependent operations
4. **Monitor resource usage** - Check CPU with `Get-ParallelConfig`
5. **Batch MCP calls** - Send multiple tool calls in single message

## Core Count Detection

```powershell
$cores = [Environment]::ProcessorCount
Write-Host "Available cores: $cores"
```

## Error Handling

All parallel operations return structured results:
```powershell
@{
    Success = $true/$false
    Output = "..."
    Error = "..." # if failed
}
```

Always check `Success` property before using results.
