---
name: serena-commander
description: Hybrid coding workflow combining Serena's symbolic code analysis with Desktop Commander's system operations. Use when working on projects requiring both deep code understanding (refactoring, migrations, architecture analysis) AND system operations (running builds, tests, managing processes, file operations). Provides synergistic workflows for full-stack development, debugging, and project automation.
---

```
┌─────────────────────────────────────────────────────────────────┐
│  ⚡ HYDRA v9.0 - THREE-HEADED BEAST                              │
│  ═════════════════════════════════════════                      │
│  [●] Serena           → Symbolic code analysis                  │
│  [●] Desktop Commander → System operations                      │
│  [●] Playwright        → Browser automation                     │
│  [●] Parallel Groups   → Max 5 concurrent agents                │
│                                                                 │
│  Status: ONLINE │ 3 MCP servers connected                       │
└─────────────────────────────────────────────────────────────────┘
```

# Serena Commander - Hybrid Code Operations

Potężne trio narzędzi: **Serena** (inteligencja symboliczna) + **Desktop Commander** (siła systemowa) + **Playwright** (automatyzacja przeglądarki).

## ⚡ CRITICAL: Parallel Execution Mode

**ALWAYS call multiple read-only tools in parallel!** This is the default behavior.

```
┌─────────────────────────────────────────────────────────────────┐
│  PARALLEL EXECUTION RULES                                       │
│  ════════════════════════                                       │
│                                                                 │
│  ✅ READ-ONLY = PARALLEL (call in single message)              │
│     find_symbol || get_symbols_overview || list_directory      │
│                                                                 │
│  ⛔ SIDE-EFFECT = NEW GROUP (break parallelism)                │
│     replace_symbol_body, write_file, start_process             │
│                                                                 │
│  📊 LIMITS:                                                     │
│     • Max 5 concurrent tools per group                         │
│     • Max ~16KB total params per group                         │
└─────────────────────────────────────────────────────────────────┘
```

### Quick Reference: What Runs in Parallel?

| PARALLEL (read-only) | SEQUENTIAL (side-effect) |
|---------------------|--------------------------|
| find_symbol | replace_symbol_body |
| get_symbols_overview | rename_symbol |
| find_referencing_symbols | add_symbol |
| search_for_pattern | write_file |
| get_file_tree | delete_file |
| read_file | start_process |
| list_directory | write_memory |
| read_memory | browser_navigate |
| browser_snapshot | browser_click |
| browser_tab_list | browser_fill |
| browser_console_messages | browser_screenshot |

## 🎯 When to Use This Skill

- **Complex refactoring** requiring code analysis + running tests
- **Debugging sessions** - understand code + check logs/processes
- **Project setup/migration** - analyze structure + execute commands
- **Build troubleshooting** - find code issues + run builds
- **Full-stack development** - edit code + manage servers
- **E2E testing** - browser automation + code verification
- **Visual regression** - screenshots + UI component changes

## 🧠 Serena - Symbolic Intelligence

Use Serena for **understanding and editing code**:

### Capabilities
| Tool | Use Case |
|------|----------|
| `get_symbols_overview` | First look at any file - understand structure |
| `find_symbol` | Find classes, functions, methods by name |
| `find_referencing_symbols` | Find all usages of a symbol |
| `replace_symbol_body` | Surgically replace function/method code |
| `insert_before/after_symbol` | Add new code at precise locations |
| `rename_symbol` | Rename across entire codebase |
| `search_for_pattern` | Regex search in code and non-code files |
| `list_dir` / `find_file` | Navigate project structure |

### Best Practices
```
✅ DO: Use get_symbols_overview FIRST before diving into code
✅ DO: Use find_symbol with depth=1 to see class methods
✅ DO: Use include_body=True only when you need actual code
✅ DO: Use find_referencing_symbols before renaming/refactoring

❌ DON'T: Read entire files unless absolutely necessary
❌ DON'T: Use search_for_pattern when you know symbol name
❌ DON'T: Forget to check references before breaking changes
```

### Serena Workflow Example
```
1. get_symbols_overview(file) → See what's in the file
2. find_symbol(name, depth=1) → Get class with methods list
3. find_symbol(name, include_body=True) → Read specific method
4. find_referencing_symbols(name) → Check who uses it
5. replace_symbol_body() → Make the change
```

## 🔧 Desktop Commander - System Power

Use Desktop Commander for **system operations**:

### Capabilities
| Tool | Use Case |
|------|----------|
| `start_process` | Run commands, start servers, builds |
| `interact_with_process` | Send input to running REPLs |
| `read_process_output` | Get command output with pagination |
| `list_sessions` | See all running processes |
| `force_terminate` | Kill stuck processes |
| `read_file` | Read any file (text, PDF, Excel, images) |
| `write_file` | Create/overwrite files |
| `edit_block` | Find-replace in files |
| `list_directory` | List with depth control |
| `start_search` | Fast file/content search |
| `get_file_info` | File metadata, line counts |

### Best Practices
```
✅ DO: Use start_process for builds, tests, servers
✅ DO: Use read_file with offset/length for large files
✅ DO: Use start_search for fast file discovery
✅ DO: Always use absolute paths

❌ DON'T: Use for code editing when Serena can do it symbolically
❌ DON'T: Forget to check port conflicts before starting servers
❌ DON'T: Leave zombie processes - always clean up
```

## 🌐 Playwright - Browser Automation

Use Playwright for **browser automation and E2E testing**:

### Capabilities
| Tool | Use Case |
|------|----------|
| `browser_navigate` | Navigate to URL |
| `browser_click` | Click elements (buttons, links) |
| `browser_fill` | Fill form inputs |
| `browser_select` | Select dropdown options |
| `browser_hover` | Hover over elements |
| `browser_screenshot` | Capture screenshots (full page or element) |
| `browser_snapshot` | Get accessibility tree (DOM structure) |
| `browser_evaluate` | Execute JavaScript in page context |
| `browser_press_key` | Press keyboard keys |
| `browser_wait` | Wait for conditions |
| `browser_tab_new` | Open new browser tab |
| `browser_tab_list` | List all open tabs |
| `browser_console_messages` | Get console logs |

### Best Practices
```
✅ DO: Use browser_snapshot to understand page structure
✅ DO: Use CSS selectors or XPath for element targeting
✅ DO: Take screenshots after important interactions
✅ DO: Check console_messages for errors after actions

❌ DON'T: Click without verifying element exists
❌ DON'T: Forget to wait for page load after navigate
❌ DON'T: Leave browser sessions open - use browser_close
```

### Playwright Workflow Example
```
1. browser_navigate(url) → Open page
2. browser_snapshot() → Understand structure
3. browser_fill(selector, value) → Fill form
4. browser_click(submit) → Submit form
5. browser_screenshot() → Capture result
6. browser_console_messages() → Check for errors
```

## 🔄 Hybrid Workflows (with Parallel Execution)

### 1. Debug & Fix Workflow (PARALLEL OPTIMIZED)
```
┌─────────────────────────────────────────────────────────┐
│  GROUP 0 (parallel):                                    │
│    [DC] start_process(test) || [DC] list_directory     │
│                                                         │
│  GROUP 1 (sequential - wait for test):                  │
│    [DC] read_process_output                             │
│                                                         │
│  GROUP 2 (parallel):                                    │
│    [Serena] find_symbol || [Serena] get_symbols_overview│
│                                                         │
│  GROUP 3 (sequential - MUTATES):                        │
│    [Serena] replace_symbol_body ← Fix the bug          │
│                                                         │
│  GROUP 4 (sequential):                                  │
│    [DC] start_process(test) ← Verify fix               │
└─────────────────────────────────────────────────────────┘
```

### 2. Refactoring Workflow (PARALLEL OPTIMIZED)
```
┌─────────────────────────────────────────────────────────┐
│  GROUP 0 (parallel - analysis):                         │
│    [Serena] get_symbols_overview(file1)                │
│    || [Serena] get_symbols_overview(file2)             │
│    || [Serena] find_referencing_symbols                │
│                                                         │
│  GROUP 1 (sequential - MUTATES):                        │
│    [Serena] rename_symbol / replace_symbol_body        │
│                                                         │
│  GROUP 2 (parallel - verify):                           │
│    [DC] start_process(tsc) || [DC] start_process(test) │
│    || [DC] start_process(lint)  ← 3 parallel!          │
└─────────────────────────────────────────────────────────┘
```

### 3. Project Exploration Workflow (PARALLEL OPTIMIZED)
```
┌─────────────────────────────────────────────────────────┐
│  GROUP 0 (parallel - 5 concurrent):                     │
│    [DC] list_directory(depth=2)                        │
│    || [Serena] list_dir                                │
│    || [Serena] get_symbols_overview(App.tsx)           │
│    || [DC] read_file(package.json)                     │
│    || [DC] read_file(tsconfig.json)                    │
│                                                         │
│  GROUP 1 (parallel - more analysis):                    │
│    [Serena] search_for_pattern("TODO")                 │
│    || [Serena] get_symbols_overview(main.ts)           │
│                                                         │
│  GROUP 2 (sequential - side effect):                    │
│    [DC] start_process(pnpm dev)                        │
└─────────────────────────────────────────────────────────┘
```

### 4. Build Troubleshooting Workflow
```
┌─────────────────────────────────────────────────────────┐
│  1. [DC] start_process → Run build                     │
│  2. [DC] read_process_output → Capture errors          │
│  3. [Serena] find_symbol → Locate problematic code     │
│  4. [Serena] get_symbols_overview → Check imports      │
│  5. [Serena] replace_symbol_body → Fix issues          │
│  6. [DC] start_process → Rebuild                       │
└─────────────────────────────────────────────────────────┘
```

### 5. Server Management Workflow
```
┌─────────────────────────────────────────────────────────┐
│  1. [DC] start_process → Check ports (netstat)         │
│  2. [DC] force_terminate → Kill conflicting processes  │
│  3. [DC] start_process → Start backend server          │
│  4. [DC] start_process → Start frontend server         │
│  5. [DC] list_sessions → Verify both running           │
│  6. [Serena] ... → Edit code while servers run         │
└─────────────────────────────────────────────────────────┘
```

### 6. E2E Testing Workflow (NEW - Playwright)
```
┌─────────────────────────────────────────────────────────┐
│  GROUP 0 (sequential - start app):                      │
│    [DC] start_process(pnpm dev)                        │
│                                                         │
│  GROUP 1 (sequential - navigate):                       │
│    [Playwright] browser_navigate(http://localhost:5173)│
│                                                         │
│  GROUP 2 (sequential - interact):                       │
│    [Playwright] browser_fill("#email", "test@test.com")│
│    [Playwright] browser_fill("#password", "secret")    │
│    [Playwright] browser_click("button[type=submit]")   │
│                                                         │
│  GROUP 3 (parallel - verify):                           │
│    [Playwright] browser_snapshot()                     │
│    || [Playwright] browser_console_messages()          │
│                                                         │
│  GROUP 4 (sequential - capture):                        │
│    [Playwright] browser_screenshot({ fullPage: true }) │
└─────────────────────────────────────────────────────────┘
```

### 7. Visual Regression Workflow (NEW - Playwright + Serena)
```
┌─────────────────────────────────────────────────────────┐
│  1. [DC] start_process → Start dev server              │
│  2. [Playwright] browser_navigate → Open app           │
│  3. [Playwright] browser_screenshot → Baseline         │
│  4. [Serena] replace_symbol_body → UI changes          │
│  5. [Playwright] browser_navigate → Reload             │
│  6. [Playwright] browser_screenshot → New state        │
│  7. Compare screenshots for visual diff                │
└─────────────────────────────────────────────────────────┘
```

## 🎮 Decision Matrix

| Task | Primary Tool | Why |
|------|-------------|-----|
| Read function code | Serena | Symbolic precision |
| Edit function | Serena | Safe, atomic edits |
| Rename across project | Serena | Handles all references |
| Run tests/builds | DC | Process management |
| Check logs | DC | File reading + tailing |
| Start/stop servers | DC | Process control |
| Search code patterns | Serena | AST-aware search |
| Search any files | DC | Fast grep-like search |
| Read config files | DC | Non-code files |
| Read PDF/Excel | DC | Binary file support |
| Create new files | DC | write_file |
| Add code to existing | Serena | insert_before/after_symbol |
| **Navigate browser** | **Playwright** | **URL navigation** |
| **Click elements** | **Playwright** | **UI interaction** |
| **Fill forms** | **Playwright** | **Form automation** |
| **Take screenshots** | **Playwright** | **Visual capture** |
| **Get page structure** | **Playwright** | **Accessibility tree** |
| **Execute JS in page** | **Playwright** | **DOM manipulation** |
| **E2E testing** | **Playwright** | **Browser automation** |

## ⚡ Quick Reference Commands

### Serena Essentials
```python
# Overview first
get_symbols_overview(relative_path="src/App.tsx", depth=1)

# Find specific symbol
find_symbol(name_path_pattern="UserService", include_body=True, depth=1)

# Find usages
find_referencing_symbols(name_path="handleSubmit", relative_path="src/Form.tsx")

# Edit symbol
replace_symbol_body(name_path="render", relative_path="src/App.tsx", body="new code")

# Pattern search (for non-symbols or unknown locations)
search_for_pattern(substring_pattern="TODO|FIXME", paths_include_glob="*.ts")
```

### Desktop Commander Essentials
```powershell
# Run command
start_process(command="pnpm test", timeout_ms=30000)

# Check ports (Windows)
start_process(command="Get-NetTCPConnection -LocalPort 3000", timeout_ms=5000)

# Kill port (custom script)
start_process(command="pnpm kill-port", timeout_ms=5000)

# Read logs (last 50 lines)
read_file(path="logs/app.log", offset=-50)

# Fast search
start_search(path="C:/project", pattern="*.tsx", searchType="files")
start_search(path="C:/project", pattern="useState", searchType="content")
```

### Playwright Essentials
```javascript
// Navigate to page
browser_navigate(url="https://example.com")

// Get page structure (always do this first!)
browser_snapshot()

// Fill form fields
browser_fill(selector="#email", value="test@example.com")
browser_fill(selector="#password", value="secret123")

// Click elements
browser_click(selector="button[type=submit]")
browser_click(selector=".menu-item", ref="E12") // with element ref

// Take screenshot
browser_screenshot() // viewport
browser_screenshot(fullPage=true) // full page
browser_screenshot(selector=".modal") // specific element

// Execute JavaScript
browser_evaluate(expression="document.title")
browser_evaluate(expression="Array.from(document.querySelectorAll('a')).map(a => a.href)")

// Get console logs
browser_console_messages()

// Manage tabs
browser_tab_list()
browser_tab_new(url="https://google.com")
browser_tab_close()
```

## 🆕 HYDRA v9.0 Services

| Service | Import | Key Functions |
|---------|--------|---------------|
| Workflows | `hydra_workflows` | `get_workflow()`, `list_workflows()` |
| Cache | `hydra_cache` | `get_hydra_cache()`, `@cacheable` |
| Retry | `hydra_retry` | `@retry_with_backoff` |
| Checkpoint | `hydra_checkpoint` | `CheckpointManager` |
| Git | `hydra_git` | `HydraGit.commit()` |
| Metrics | `hydra_metrics` | `HydraMetrics.format_dashboard()` |
| Visual | `hydra_visual` | `HydraVisual.capture_snapshot()` |
| Deps | `hydra_deps` | `HydraDeps.analyze_impact()` |
| AutoFix | `hydra_autofix` | `HydraAutoFix.analyze_error()` |

### Quick Workflow Run
```
/hydra run debug    → Test → Find → Fix
/hydra run refactor → Overview → Refs → Replace → Test
/hydra run test     → Test → Coverage → Report
/hydra run deploy   → Build → Test → Commit → Deploy
/hydra run analyze  → Tree → Symbols → Patterns
/hydra run e2e      → Navigate → Fill → Click → Screenshot (NEW!)
/hydra run visual   → Screenshot → Edit → Screenshot → Compare (NEW!)
```

## 🚨 Common Pitfalls

### Serena Issues
| Problem | Solution |
|---------|----------|
| `path is on mount '\\\\.\\nul'` | Delete `nul` file from project (Windows reserved name) |
| Symbol not found | Use `search_for_pattern` first to locate |
| Wrong symbol matched | Use full `name_path` like `ClassName/methodName` |

### Desktop Commander Issues
| Problem | Solution |
|---------|----------|
| Port already in use | Check with `Get-NetTCPConnection`, then kill |
| Process timeout | Increase `timeout_ms` or use `read_process_output` |
| Path not found | Always use absolute paths |

### Playwright Issues
| Problem | Solution |
|---------|----------|
| Element not found | Use `browser_snapshot` first to see available elements |
| Click doesn't work | Element may be covered - use `force: true` or scroll |
| Page not loaded | Use `browser_wait` or check `waitUntil` option |
| Wrong element clicked | Use more specific selector or element `ref` from snapshot |
| JavaScript error | Check `browser_console_messages` for errors |
| Screenshot blank | Page may still be loading - add wait before capture |

## 📋 Pre-flight Checklist

Before starting any session:
```
□ Check Serena project is activated (check_onboarding_performed)
□ Read relevant memories if available
□ Check for port conflicts before starting servers
□ Verify working directory is correct
□ No reserved Windows filenames (nul, con, prn, aux, etc.)
```

## 🎯 Example: Full Debug Session

```
User: "Test UserService.login() is failing"

1. [DC] Run test to see error
   start_process("pnpm test -- UserService", timeout_ms=30000)
   
2. [DC] Read output
   read_process_output(pid, timeout_ms=5000)
   → Error: "Cannot read property 'token' of undefined"

3. [Serena] Find the function
   find_symbol("UserService/login", include_body=True, relative_path="src/services")
   → See the code, spot the issue

4. [Serena] Check what calls it
   find_referencing_symbols("login", relative_path="src/services/UserService.ts")
   → 3 usages found

5. [Serena] Fix the bug
   replace_symbol_body("UserService/login", relative_path="...", body="fixed code")

6. [DC] Re-run test
   start_process("pnpm test -- UserService", timeout_ms=30000)
   → ✅ All tests pass!
```

## 🔗 Integration with Memories

Use Serena memories to persist knowledge:
```python
# Save useful info
write_memory(memory_file_name="debug_session_2024", content="...")

# Read later
read_memory(memory_file_name="debug_session_2024")

# List available
list_memories()
```

---

**Pro Tip:** Serena dla chirurgii kodu, Desktop Commander dla ciężkich prac systemowych, Playwright dla automatyzacji przeglądarki. Trzy głowy = unstoppable! 🐉🚀
