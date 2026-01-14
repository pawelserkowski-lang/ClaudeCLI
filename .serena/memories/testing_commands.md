# Testing Commands

The ClaudeCLI project utilizes a custom PowerShell-based testing framework, primarily located within the `ai-handler/` directory. The ClaudeCLI project utilizes a custom PowerShell-based testing framework, primarily located within the `ai-handler/` directory. Linting is performed via a dedicated script. While a single comprehensive test command is not explicitly defined in the `README.md`, individual test scripts and functions can be executed to verify specific modules and functionalities.

**1. Running Individual Test Scripts:**
- To execute tests for the Advanced AI modules, you would typically run the `test-advanced-ai.ps1` script, potentially with specific module parameters:
  ```powershell
  .\ai-handler\test-advanced-ai.ps1
  # Or for a specific module, e.g., SelfCorrection
  .\ai-handler\test-advanced-ai.ps1 -Module SelfCorrection
  ```

**2. Key Testing Functions:**
- The `test-advanced-ai.ps1` script and other `test-*.ps1` files employ custom PowerShell functions for assertions and checks, including:
  - `Test-Assert`: For general assertions within test cases.
  - `Test-CodeSyntax`: To validate code syntax (e.g., `Test-CodeSyntax -Code "print('hello')" -Language "python"`).
  - `Test-OllamaAvailable`: Checks if Ollama is installed and running.
  - `Test-ResponseValidity`: Verifies the validity of AI responses.
  - `Test-AIProviders`: Checks connectivity to all configured AI providers.

**3. No Explicit Formatting/Linting Commands:**
- **3. Linting:**
  - To lint all projects, run the `Lint-Parallel.ps1` script:
    ```powershell
    .\parallel\scripts\Lint-Parallel.ps1
    ```
- **4. No Explicit Formatting Commands:**
  - Explicit commands for code formatting (e.g., using a dedicated formatter) were not found in the project documentation or through file analysis. It is assumed that code style is maintained manually, through IDE integrations, or via implicit processes not exposed in the provided documentation.