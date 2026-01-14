# Development Commands

This section outlines the primary commands for interacting with and developing in the ClaudeCLI environment.

**1. Project Launching:**
- **Recommended:** Execute the VBS launcher for a streamlined start:
  ```powershell
  .\ClaudeCLI.vbs
  ```
- **Alternative (PowerShell):** Bypass execution policy and run the main launcher script:
  ```powershell
  powershell -ExecutionPolicy Bypass -File _launcher.ps1
  ```

**2. API Key Configuration:**
- **Set API Key (User Scope - Recommended):** This command sets the `ANTHROPIC_API_KEY` environment variable for the current user, making it persistent across sessions.
  ```powershell
  [Environment]::SetEnvironmentVariable('ANTHROPIC_API_KEY', 'sk-ant-api03-...', 'User')
  ```
- **Set API Key (Process Scope - Temporary):** Sets the API key only for the current PowerShell process.
  ```powershell
  $env:ANTHROPIC_API_KEY = "sk-ant-api03-..."
  ```
- **Set API Key (CMD):** Sets the API key via `setx` for persistence.
  ```powershell
  setx ANTHROPIC_API_KEY "sk-ant-api03-..."
  ```

**3. API Key Verification:**
- **List Claude/Anthropic Variables:** Display all environment variables related to Claude or Anthropic:
  ```powershell
  Get-ChildItem env: | Where-Object { $_.Name -like "*CLAUDE*" -or $_.Name -like "*ANTHROPIC*" }
  ```
- **Check Specific API Key (Masked Output):** Verifies if the `ANTHROPIC_API_KEY` is set and displays a masked version for security:
  ```powershell
  $key = $env:ANTHROPIC_API_KEY
  if ($key) { Write-Host "✓ API Key: $($key.Substring(0,15))..." }
  ```

**4. MCP Health Check:**
- Manually check the status of Multi-Context Protocol (MCP) servers using parallel execution:
  ```powershell
  .\mcp-health-check.ps1 -TimeoutSeconds 5
  ```

**5. Creating Desktop Shortcut:**
- Run the script to create a desktop shortcut for ClaudeCLI:
  ```powershell
  .\create-shortcuts.ps1
  ```

**6. Advanced AI System Interaction (Examples):**
- **Invoke Advanced AI with Self-Correction/Few-Shot Learning:** Request AI to write code with intelligent features:
  ```powershell
  Invoke-AdvancedAI "Write Python sort" -Mode code
  ```
- **Quick AI Request (Model Racing):** Get a fast response by racing multiple models:
  ```powershell
  Get-AIQuick "Capital of France?"
  ```
- **New AI Code with Validation:** Generate code with automatic syntax validation:
  ```powershell
  New-AICode "Download file function"
  ```
- **Semantic Query for Codebase Context:** Query the codebase for understanding specific functionalities:
  ```powershell
  Invoke-SemanticQuery -FilePath "app.py" -Query "How does auth work?"
  ```