# Code Style and Conventions

**1. Parallel Execution Principle:**
- **Mandate:** "Every operation that CAN be executed in parallel MUST be executed in parallel."
- **Implementation:** Utilize constructs like PowerShell Jobs, `tokio::join!` (Rust example), and `Promise.all` (TypeScript example) for independent operations.

**2. Error Handling:**
- **Requirement:** "Zawsze używaj error handling (try/catch)" (Always use error handling).
- **PowerShell Specific:** Implement `-ErrorAction Stop` for critical operations to ensure errors are not silently ignored.

**3. Path Management:**
- **Recommendation:** "Preferuj absolute paths" (Prefer absolute paths).
- **Rationale:** Ensures reliability and avoids issues with relative path resolution.

**4. Logging and Output:**
- **Guideline:** "Loguj z kolorami" (Log with colors).
- **PowerShell Specific:** Use `Write-Host -ForegroundColor` for enhanced readability and clarity in terminal output.

**5. API Key Management:**
- **Security:** API keys (e.g., `ANTHROPIC_API_KEY`) must be stored in environment variables (e.g., `[Environment]::SetEnvironmentVariable`).
- **Version Control:** Do NOT commit API keys or other sensitive data directly into Git repositories.
- **Output Masking:** Mask API keys in any output (show only the first 15 characters) to prevent accidental exposure.

**6. General Best Practices (from README.md):**
- Use ENV vars instead of hardcoded keys (Critical).
- Do NOT commit API keys to Git (Critical).
- Mask API keys in outputs (Medium).
- Prefer absolute paths (Low).
- Always use error handling (try/catch) (Medium).
- Perform parallel MCP calls when possible (Medium).
- Create backups before system changes (Medium).