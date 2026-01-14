# Guidelines and Design Patterns

**1. Council of Six (Multi-Agent Debate):**
- **Purpose:** A decision-making and architectural review pattern used within the HYDRA 10.0 system.
- **Roles:** The council consists of six distinct roles, each focusing on a specific aspect:
  - **Architect:** Focuses on facts, clean structure, and best practices (e.g., Rust 2024, React 19).
  - **Security:** Concentrates on risks, environment variables, preventing hardcoded secrets, and API key masking.
  - **Speedster:** Prioritizes performance (e.g., Lighthouse > 90, bundle < 200KB).
  - **Pragmatyk (Pragmatist):** Emphasizes practical solutions and hybrid approaches (e.g., Web + Desktop).
  - **Researcher:** Focuses on verification, checking documentation and external sources before implementation.
  - **Jester:** Provides critique, challenging boilerplate and over-engineering.

**2. Maximum Autonomy Mode Philosophy:**
- **Principle:** "Pełna moc, ale z odpowiedzialnością. Przed destrukcyjnymi operacjami - pytaj użytkownika!" (Full power, but with responsibility. Before destructive operations - ask the user!).
- **Implication:** The system has extensive permissions (wildcard Bash, Write, Edit, Read, registry access, admin privileges, network operations, software installation), but critical or destructive actions require user confirmation.

**3. Parallel Execution Principle:**
- **Core Mandate:** "Every operation that CAN be executed in parallel MUST be executed in parallel."
- **Application:** This principle is deeply ingrained in the system's design, aiming to maximize efficiency by concurrently executing independent tasks (e.g., PowerShell Jobs for MCP health checks).

**4. Security Policy:**
- **Environment Variables:** Full access for read, write, and delete operations on environment variables.
- **Permissions:** Broad permissions including `Bash(*)`, `Write(*)`, `Edit(*)`, `Read(*)` for various MCP tools (Serena, Desktop Commander, Playwright).
- **Absolute Prohibitions:** Explicitly forbidden actions include `rm -rf /`, `format C:`, `diskpart` without confirmation, mass registry key deletion, and disabling Windows Defender without consent.