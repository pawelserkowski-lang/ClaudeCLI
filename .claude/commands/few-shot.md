---
description: "AI with dynamic few-shot learning from success history"
---

# Few-Shot Learning - Learn from History

Automatically include successful examples from past interactions in prompts.

## Usage

```
/few-shot Write SQL query to get active users
/few-shot Create API endpoint for user login
/few-shot Generate test cases for Calculator
```

## How It Works

1. **Categorize**: Detect prompt category (sql, code, api, etc.)
2. **Search**: Find similar successful responses from cache
3. **Inject**: Add top examples to prompt context
4. **Generate**: AI learns from your past successes

## Categories

| Category | Triggers | Example |
|----------|----------|---------|
| `sql` | query, select, join | SQL queries |
| `api` | endpoint, route, REST | API design |
| `code` | function, implement | General code |
| `file` | read, write, parse | File operations |
| `config` | setup, configure | Configuration |
| `docs` | document, explain | Documentation |
| `test` | test, spec, assert | Testing |

## Module Functions

```powershell
# Save successful response
Save-SuccessfulResponse -Prompt "Write SQL query" -Response "SELECT * FROM users" -Rating 5

# Get similar examples
Get-SuccessfulExamples -Prompt "SQL for active users" -MaxExamples 3

# Generate with few-shot
Invoke-AIWithFewShot -Prompt "Write SQL to get orders" -Model "llama3.2:3b"

# View cache stats
Get-FewShotStats

# Clear old entries
Clear-FewShotCache -OlderThanDays 30
```

## Example

```
Prompt: "Write SQL to get inactive users"

Found 2 similar examples:
1. "Write SQL to get active users" -> "SELECT * FROM users WHERE status = 'active'"
2. "SQL query for user count" -> "SELECT COUNT(*) FROM users"

Enhanced prompt includes these examples as context.
```

## Cache Stats

```powershell
Get-FewShotStats

TotalEntries:  45
Categories:    sql(12), code(18), api(8), test(7)
AverageRating: 4.2
TotalUses:     156
CacheSize:     128KB
```

## Integration

- Module: `ai-handler/modules/FewShotLearning.psm1`
- Cache: `ai-handler/cache/success_history.json`

ARGUMENTS: $ARGUMENTS
