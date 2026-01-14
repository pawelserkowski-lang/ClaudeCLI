---
description: "HYDRA - Three-Headed Beast (Serena + Desktop Commander + Playwright)"
---

# HYDRA v9.0 - Three-Headed Beast

**Status: ACTIVE** | Zero backend required | Direct MCP tools

```
┌─────────────────────────────────────────────────────────────────┐
│  🐉 HYDRA - Three-Headed Beast                                  │
│  ═════════════════════════════════════                          │
│  [●] Serena           → Symbolic code analysis                  │
│  [●] Desktop Commander → System operations                      │
│  [●] Playwright        → Browser automation                     │
│                                                                 │
│  Mode: Pure MCP │ No backend required │ Direct tool access      │
└─────────────────────────────────────────────────────────────────┘
```

## THE THREE HEADS

| Head | Purpose | Key Tools |
|------|---------|-----------|
| 🧠 **Serena** | Code Intelligence | `find_symbol`, `replace_symbol_body`, `get_symbols_overview` |
| ⚡ **Desktop Commander** | System Power | `start_process`, `read_file`, `list_directory`, `write_file` |
| 🌐 **Playwright** | Browser Automation | `browser_navigate`, `browser_click`, `browser_screenshot`, `browser_fill` |

## QUICK WORKFLOWS

### Debug Workflow
```
1. mcp__serena__find_symbol          → Find error location
2. mcp__desktop-commander__start_process → Run tests
3. mcp__serena__replace_symbol_body  → Fix the bug
4. mcp__desktop-commander__start_process → Verify fix
```

### Refactor Workflow
```
1. mcp__serena__get_symbols_overview → Understand structure
2. mcp__serena__find_referencing_symbols → Find all usages
3. mcp__serena__rename_symbol        → Safe rename
4. mcp__desktop-commander__start_process → Run tests
```

### E2E Testing Workflow
```
1. mcp__playwright__browser_navigate → Open test URL
2. mcp__playwright__browser_fill     → Fill form inputs
3. mcp__playwright__browser_click    → Submit form
4. mcp__playwright__browser_screenshot → Capture result
5. mcp__playwright__browser_snapshot → Get accessibility tree
```

### Web Scraping Workflow
```
1. mcp__playwright__browser_navigate → Navigate to page
2. mcp__playwright__browser_snapshot → Get page structure
3. mcp__playwright__browser_evaluate → Extract data via JS
4. mcp__desktop-commander__write_file → Save results
```

### Visual Regression Workflow
```
1. mcp__desktop-commander__start_process → Start dev server
2. mcp__playwright__browser_navigate → Open app
3. mcp__playwright__browser_screenshot → Capture baseline
4. mcp__serena__replace_symbol_body  → Make UI changes
5. mcp__playwright__browser_screenshot → Capture new state
```

## PARALLEL EXECUTION RULES

**Read-only tools** (can run in parallel):
- Serena: `find_symbol`, `get_symbols_overview`, `search_for_pattern`
- DC: `read_file`, `list_directory`, `get_file_info`
- Playwright: `browser_snapshot`, `browser_tab_list`, `browser_console_messages`

**Side-effect tools** (must run sequentially):
- Serena: `replace_symbol_body`, `rename_symbol`, `insert_*`
- DC: `write_file`, `start_process`, `create_directory`
- Playwright: `browser_navigate`, `browser_click`, `browser_fill`, `browser_screenshot`

## EXAMPLE: Full Debug Session

```
# Step 1: Gather context (PARALLEL)
mcp__serena__find_symbol("ErrorComponent")
mcp__desktop-commander__read_file("/path/to/error.log")

# Step 2: Analyze (PARALLEL)
mcp__serena__find_referencing_symbols("ErrorComponent")
mcp__serena__get_symbols_overview("src/components/Error.tsx")

# Step 3: Fix (SEQUENTIAL)
mcp__serena__replace_symbol_body("ErrorComponent", new_code)

# Step 4: Verify (SEQUENTIAL)
mcp__desktop-commander__start_process("pnpm test")
```

## EXAMPLE: E2E Test Session

```
# Step 1: Start app (SEQUENTIAL)
mcp__desktop-commander__start_process("pnpm dev")

# Step 2: Navigate and interact (SEQUENTIAL)
mcp__playwright__browser_navigate("http://localhost:5173")
mcp__playwright__browser_fill("#email", "test@example.com")
mcp__playwright__browser_fill("#password", "secret123")
mcp__playwright__browser_click("button[type=submit]")

# Step 3: Verify (PARALLEL)
mcp__playwright__browser_snapshot()
mcp__playwright__browser_console_messages()

# Step 4: Screenshot (SEQUENTIAL)
mcp__playwright__browser_screenshot({ fullPage: true })
```

## PLAYWRIGHT TOOLS REFERENCE

| Tool | Description |
|------|-------------|
| `browser_navigate` | Navigate to URL |
| `browser_click` | Click element |
| `browser_fill` | Fill input field |
| `browser_select` | Select dropdown option |
| `browser_hover` | Hover over element |
| `browser_screenshot` | Capture screenshot |
| `browser_snapshot` | Get accessibility tree |
| `browser_evaluate` | Execute JavaScript |
| `browser_press_key` | Press keyboard key |
| `browser_scroll` | Scroll page/element |
| `browser_wait` | Wait for condition |
| `browser_tab_new` | Open new tab |
| `browser_tab_close` | Close tab |
| `browser_tab_list` | List all tabs |
| `browser_resize` | Resize viewport |
| `browser_close` | Close browser |

## MEMORIES TO CHECK

- `project_overview` - Project structure
- `suggested_commands` - Common commands
- `style_conventions` - Code style rules
- `troubleshooting` - Known issues
- `playwright_workflows` - Browser automation patterns

## NO BACKEND NEEDED

This version uses MCP tools directly:
- No `uvicorn` required
- No REST API endpoints
- No Python backend for HYDRA
- Just pure MCP tool orchestration

ARGUMENTS: $ARGUMENTS
