---
description: "Analyze and enhance prompt quality before AI call"
---

# Prompt Optimizer - Auto-Enhancement

Automatically analyze, categorize, and improve prompts before sending to AI.

## Usage

```
/optimize-prompt explain python
/optimize-prompt write code for sorting
/optimize-prompt analyze this function
```

## How It Works

1. **Analyze**: Score clarity (0-100), detect issues
2. **Categorize**: code, analysis, question, creative, task, summary
3. **Enhance**: Add task-specific instructions
4. **Optimize**: Model-specific formatting

## Categories & Enhancements

| Category | Triggers | Added Instructions |
|----------|----------|-------------------|
| `code` | write, implement, function | Clean code, error handling, best practices |
| `analysis` | analyze, compare, explain | Structured analysis, multiple perspectives |
| `question` | what, how, why, ? | Concise, examples if helpful |
| `creative` | brainstorm, imagine | Creative, original angles |
| `task` | do, build, setup | Step-by-step, verification |
| `summary` | summarize, tldr | Bullet points, key points only |

## Module Functions

```powershell
# Quick enhancement
"explain python" | Get-BetterPrompt

# Full analysis
Optimize-Prompt -Prompt "write code" -Model "llama3.2:3b" -Detailed

# Quality test
Test-PromptQuality -Prompt "do something with the stuff"

# AI with auto-optimization
Invoke-AIRequest -Messages @(@{role="user"; content="python sort"}) -OptimizePrompt

# Batch optimization
Optimize-PromptBatch -Prompts @("task 1", "task 2") -Model "llama3.2:3b"
```

## Example

```
Original: "explain python"
Score:    45/100
Issues:   Too vague, no specific topic

Optimized: "explain python

Be concise but thorough. Provide examples if helpful."

Category: question
Enhancements: +concise instruction, +examples suggestion
```

## Quality Scoring

| Score | Quality | Action |
|-------|---------|--------|
| 80-100 | Excellent | No changes needed |
| 60-79 | Good | Minor enhancements |
| 40-59 | Fair | Add structure |
| 0-39 | Poor | Major rewrite |

## Model-Specific Optimization

| Model | Style | Prefix |
|-------|-------|--------|
| llama3.2:1b | concise | (none) |
| qwen2.5-coder | technical | "You are an expert programmer. " |
| claude | detailed | (none) |
| gpt-4 | detailed | (none) |

## Integration

Module: `ai-handler/modules/PromptOptimizer.psm1`

ARGUMENTS: $ARGUMENTS
