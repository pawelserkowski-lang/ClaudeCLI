---
description: "Race multiple models for fastest valid response (Speculative Decoding)"
---

# Speculative Decoding - Model Racing

Run multiple models in parallel, return the fastest valid response.

## Usage

```
/speculate What is the capital of France?
/speculate Explain async/await in JavaScript
/speculate Write a quick Python one-liner for sum
```

## How It Works

1. **Launch**: Start 2-3 models simultaneously
2. **Race**: First valid response wins
3. **Validate**: Check response quality
4. **Return**: Fastest + valid result

## Racing Modes

| Mode | Models | Best For |
|------|--------|----------|
| **Fast** | 1b vs 3b | Simple questions |
| **Code** | 1b + qwen-coder | Code generation |
| **Consensus** | 3 models | Important decisions |

## Module Functions

```powershell
# Basic race (1b vs 3b)
Invoke-SpeculativeDecoding -Prompt "Explain X" -TimeoutMs 30000

# Multi-model race
Invoke-ModelRace -Prompt "Capital of Japan?" -Models @("llama3.2:1b", "phi3:mini", "llama3.2:3b")

# Code-optimized speculation
Invoke-CodeSpeculation -Prompt "Write JS reverse string" -MaxTokens 512

# Consensus (multi-model agreement)
Invoke-ConsensusGeneration -Prompt "Benefits of TypeScript" -Models @("llama3.2:3b", "phi3:mini")
```

## Example Output

```
Model Race Results
==================
Models: llama3.2:1b, phi3:mini, llama3.2:3b

Winner: llama3.2:1b
Time:   1.76s
Valid:  YES

Response: The capital of France is Paris.

Runner-up: phi3:mini (2.1s)
Slowest:   llama3.2:3b (3.4s)
```

## Performance

| Scenario | Time Saved |
|----------|-----------|
| Simple Q&A | ~60% faster |
| Code snippets | ~40% faster |
| Analysis | ~30% faster |

## When to Use

- Quick factual questions
- Code one-liners
- When speed > depth
- Time-sensitive responses

## Integration

Module: `ai-handler/modules/SpeculativeDecoding.psm1`

ARGUMENTS: $ARGUMENTS
