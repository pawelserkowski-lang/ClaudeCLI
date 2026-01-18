# Codebase Structure

The `ClaudeHYDRA` project follows a modular structure, with key functionalities organized into distinct directories:

- **`.claude/`**
  - `commands/`: Contains custom slash commands for the CLI (e.g., `ai.md`, `ai-batch.md`).
  - `hooks/`: Stores event hooks.
  - `skills/`: Houses custom skills like `serena-commander` and `hydra`.
  - `statusline.js`: Configuration for the status bar.

- **`.serena/`**
  - `project.yml`: Serena project-specific configuration.

- **`ai-handler/`**
  - `AIModelHandler.psm1`: The main PowerShell module for AI model handling.
  - `ai-config.json`: Configuration for AI providers and models.
  - `modules/`: Contains the Advanced AI Modules, which are individual PowerShell modules (`.psm1` files) implementing core AI functionalities:
    - `SelfCorrection.psm1`
    - `FewShotLearning.psm1`
    - `SpeculativeDecoding.psm1`
    - `LoadBalancer.psm1`
    - `SemanticFileMapping.psm1`
    - `AdvancedAI.psm1`
  - `*.ps1`: Various CLI wrappers and test scripts for the AI handler functionality.

- **`parallel/`**
  - `modules/ParallelUtils.psm1`: Utility module for parallel execution.
  - `scripts/`: Contains PowerShell scripts for parallel operations such as Git, Download, Compress, and TaskDAG.

- **`CLAUDE.md`:** Comprehensive system instructions and documentation (900+ lines).

- **`README.md`:** Provides a high-level overview of the project (this file).

- **`_launcher.ps1`:** The primary PowerShell script for launching the ClaudeHYDRA environment.

- **`mcp-health-check.ps1`:** Script for diagnosing the health of Multi-Context Protocol (MCP) servers.