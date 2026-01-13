---
description: "Check system load and get optimal AI provider recommendation"
---

# Load Balancer - CPU-Aware Provider Selection

Automatically select local or cloud AI based on current system load.

## Usage

```
/load-balance              # Check current load and recommendation
/load-balance status       # Detailed system metrics
/load-balance watch        # Real-time monitoring
```

## How It Works

| CPU Load | Memory | Recommendation | Provider |
|----------|--------|----------------|----------|
| < 70% | < 85% | LOCAL | ollama (free) |
| 70-90% | < 85% | HYBRID | ollama + cloud fallback |
| > 90% | any | CLOUD | openai/anthropic |
| any | > 85% | CLOUD | openai/anthropic |

## Features

- **Real-time CPU monitoring**: Checks load before each AI call
- **Adaptive concurrency**: Adjusts parallel jobs based on load
- **Cost optimization**: Prefers local ($0) when resources available
- **Automatic fallback**: Switches to cloud when overloaded

## Module Functions

```powershell
# Quick CPU check
Get-CpuLoad

# Full system status
Get-SystemLoad
# Returns: @{ CpuPercent = 45; MemoryPercent = 60; Recommendation = "local" }

# Get provider for task
Get-LoadBalancedProvider -Task "code"

# Batch with adaptive balancing
Invoke-LoadBalancedBatch -Prompts @("Q1", "Q2", "Q3") -AdaptiveBalancing

# Real-time watch
Watch-SystemLoad -IntervalSeconds 2

# View config
Get-LoadBalancerConfig
```

## Example Output

```
System Load Status
==================
CPU:        45% [||||||||          ]
Memory:     62% [||||||||||        ]
Recommendation: LOCAL

Optimal Provider: ollama/llama3.2:3b
Reason: CPU < 70%, sufficient resources for local inference
Cost: $0.00
```

## Thresholds (Configurable)

```json
{
  "cpu_threshold_local": 70,
  "cpu_threshold_cloud": 90,
  "memory_threshold": 85
}
```

## Integration

Module: `ai-handler/modules/LoadBalancer.psm1`

ARGUMENTS: $ARGUMENTS
