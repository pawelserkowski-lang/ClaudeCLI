---
description: "Query code with full dependency context (Deep RAG)"
---

# Semantic Query - Deep RAG with Import Analysis

Query your codebase with automatic context expansion based on imports and dependencies.

## Usage

```
/semantic-query How does authentication work in auth.py?
/semantic-query Explain the data flow in main.ts
/semantic-query What does UserService depend on?
```

## How It Works

1. **Analyze File**: Extract imports, requires, uses from target file
2. **Build Graph**: Follow dependencies up to 3 levels deep
3. **Expand Context**: Include related files in AI context
4. **Query**: Ask question with full dependency awareness

## Features

| Feature | Description |
|---------|-------------|
| Import Tracking | Follows `import`, `require`, `using`, `use` |
| Function Detection | Extracts function/class definitions |
| Dependency Graph | Visualizes file relationships |
| Smart Context | Only includes relevant files |

## Supported Languages

- Python (`import`, `from X import`)
- JavaScript/TypeScript (`import`, `require`)
- PowerShell (`Import-Module`, `. source`)
- Rust (`use`, `mod`)
- Go (`import`)
- C# (`using`)

## Module Functions

```powershell
# Get related files
Get-RelatedFiles -FilePath "src/app.py" -MaxDepth 2

# Build full dependency graph
Build-DependencyGraph -ProjectPath "C:\Project" -Language "python"

# Query with expanded context
Invoke-SemanticQuery -FilePath "auth.py" -Query "How does login work?" -IncludeRelated

# Get AI-ready context
Get-ExpandedContext -FilePath "main.ts" -MaxRelatedFiles 5
```

## Example

```
Query: "How does UserController handle requests?"

Context Expansion:
  - UserController.ts (main file)
  - UserService.ts (imported)
  - UserRepository.ts (imported by service)
  - types/User.ts (shared types)

Total context: 4 files, ~2000 tokens
```

## Integration

Module: `ai-handler/modules/SemanticFileMapping.psm1`

ARGUMENTS: $ARGUMENTS
