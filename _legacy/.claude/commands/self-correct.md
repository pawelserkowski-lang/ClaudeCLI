---
description: "Generate code with automatic validation and self-correction"
---

# Self-Correction Code Generator

Generate code with automatic syntax validation using phi3:mini validator.
If code has issues, it will be automatically regenerated (up to 3 attempts).

## Usage

```
/self-correct Write a Python function to calculate factorial
/self-correct Create PowerShell script to backup files
/self-correct Implement TypeScript async queue
```

## How It Works

1. **Generate**: Create code using primary model (llama3.2:3b or qwen2.5-coder)
2. **Validate**: Check syntax with phi3:mini validator
3. **Correct**: If issues found, regenerate with error context
4. **Return**: Only valid code reaches you

## Supported Languages

| Language | Validation Method |
|----------|------------------|
| PowerShell | AST Parser |
| Python | py_compile |
| JavaScript | Acorn/ESLint patterns |
| TypeScript | TSC patterns |
| Rust | rustc patterns |
| Go | go build patterns |
| SQL | Basic syntax check |
| C# | Roslyn patterns |

## Module Functions

```powershell
# Direct validation
Test-CodeSyntax -Code "def hello(): print('world')" -Language "python"

# Generate with self-correction
Invoke-CodeWithSelfCorrection -Prompt "Write factorial" -MaxAttempts 3

# Auto-detect language
Get-CodeLanguage -Code "function test() { return 42; }"
```

## Example Output

```
Attempt 1/3: Generating code...
Validation: PASSED (python)
------------------------------------------
def factorial(n):
    if n <= 1:
        return 1
    return n * factorial(n - 1)
------------------------------------------
```

## Integration

This command uses the SelfCorrection module from AI Handler:
- Module: `ai-handler/modules/SelfCorrection.psm1`
- Validator: Local phi3:mini (fast, free)
- Primary: qwen2.5-coder:1.5b for code tasks

ARGUMENTS: $ARGUMENTS
