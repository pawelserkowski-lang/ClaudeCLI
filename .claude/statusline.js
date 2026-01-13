#!/usr/bin/env node
/**
 * Claude Code CLI Status Line - AI HANDLER EDITION v5
 *
 * FULL:    AI | Model | Context | Tokens | Limits | [MCP] | Sys:CPU/RAM
 * COMPACT: AI | Model | Ctx | I/O | Lim | MCP | C%/R%
 *
 * Config: ../ai-models.json | Settings: ./settings.local.json
 * Env: STATUSLINE_COMPACT=1 for forced compact mode
 */

const fs = require('fs');
const path = require('path');
const os = require('os');
const { execSync } = require('child_process');

// Paths
const USAGE_FILE = path.join(os.tmpdir(), 'claude-usage-tracking.json');
const CONFIG_FILE = path.join(__dirname, '..', 'ai-models.json');
const SETTINGS_FILE = path.join(__dirname, 'settings.local.json');

// Detect compact mode: env var or terminal width < 120
const TERMINAL_WIDTH = process.stdout.columns || 120;
const COMPACT_MODE = process.env.STATUSLINE_COMPACT === '1' || TERMINAL_WIDTH < 100;

// ANSI color codes
const c = {
  reset: '\x1b[0m',
  bold: '\x1b[1m',
  dim: '\x1b[2m',
  italic: '\x1b[3m',
  blink: '\x1b[5m',

  // Standard
  red: '\x1b[31m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  magenta: '\x1b[35m',
  cyan: '\x1b[36m',
  white: '\x1b[37m',
  gray: '\x1b[90m',

  // Bright / Neon
  neonRed: '\x1b[91m',
  neonGreen: '\x1b[92m',
  neonYellow: '\x1b[93m',
  neonBlue: '\x1b[94m',
  neonMagenta: '\x1b[95m',
  neonCyan: '\x1b[96m',
  neonWhite: '\x1b[97m',

  // Backgrounds
  bgRed: '\x1b[41m',
  bgGreen: '\x1b[42m',
  bgYellow: '\x1b[43m',
  bgBlue: '\x1b[44m',
  bgMagenta: '\x1b[45m',
};

// Load configuration
let aiConfig;
try {
  aiConfig = JSON.parse(fs.readFileSync(CONFIG_FILE, 'utf8'));
} catch (e) {
  aiConfig = {
    models: {},
    tiers: {
      pro: { label: 'PRO', color: 'magenta' },
      standard: { label: 'STD', color: 'blue' },
      lite: { label: 'LITE', color: 'green' }
    }
  };
}

// Load MCP settings
let mcpServers = [];
try {
  const settings = JSON.parse(fs.readFileSync(SETTINGS_FILE, 'utf8'));
  mcpServers = settings.enabledMcpjsonServers || [];
} catch (e) {
  mcpServers = ['serena', 'desktop-commander', 'playwright'];
}

// ═══════════════════════════════════════════════════════════════
// HELPER FUNCTIONS
// ═══════════════════════════════════════════════════════════════

function getColorCode(colorName) {
  const map = {
    'magenta': c.neonMagenta, 'blue': c.neonBlue, 'green': c.neonGreen,
    'cyan': c.neonCyan, 'yellow': c.neonYellow, 'red': c.neonRed, 'white': c.neonWhite
  };
  return map[colorName] || c.neonWhite;
}

function fmt(n) {
  if (n === undefined || n === null) return '0';
  if (n >= 1000000) return (n / 1000000).toFixed(1) + 'M';
  if (n >= 1000) return (n / 1000).toFixed(1) + 'K';
  return Math.round(n).toString();
}

function getRemainColor(percent) {
  if (percent <= 10) return c.neonRed + c.blink + c.bold;
  if (percent <= 25) return c.neonRed;
  if (percent <= 50) return c.neonYellow;
  return c.neonGreen;
}

function getUsageColor(percent) {
  if (percent >= 90) return c.neonRed;
  if (percent >= 70) return c.neonYellow;
  return c.neonGreen;
}

function getModelConfig(modelId) {
  if (!modelId) return null;
  const id = modelId.toLowerCase();
  if (aiConfig.models[id]) return { ...aiConfig.models[id], id };
  for (const [key, model] of Object.entries(aiConfig.models)) {
    if (id.includes(key)) return { ...model, id: key };
  }
  return null;
}

// ═══════════════════════════════════════════════════════════════
// AI HANDLER STATUS CHECK
// ═══════════════════════════════════════════════════════════════

function checkAIHandlerStatus() {
  let ollamaRunning = false;
  let modelCount = 0;

  try {
    // Check if Ollama process is running
    if (process.platform === 'win32') {
      const output = execSync('tasklist /FI "IMAGENAME eq ollama.exe" /NH 2>nul', {
        encoding: 'utf8',
        timeout: 2000,
        windowsHide: true
      });
      ollamaRunning = output.toLowerCase().includes('ollama.exe');
    } else {
      const output = execSync('pgrep -x ollama 2>/dev/null || echo ""', {
        encoding: 'utf8',
        timeout: 2000
      });
      ollamaRunning = output.trim().length > 0;
    }

    // Count local models if Ollama is running
    if (ollamaRunning) {
      try {
        const modelsOutput = execSync('ollama list 2>nul', {
          encoding: 'utf8',
          timeout: 3000,
          windowsHide: true
        });
        modelCount = modelsOutput.trim().split('\n').length - 1; // Minus header
        if (modelCount < 0) modelCount = 0;
      } catch (e) {
        modelCount = 0;
      }
    }
  } catch (e) {
    ollamaRunning = false;
  }

  return {
    running: ollamaRunning,
    models: modelCount
  };
}

// ═══════════════════════════════════════════════════════════════
// SYSTEM RESOURCES (CPU & RAM only)
// ═══════════════════════════════════════════════════════════════

function getSystemResources() {
  // RAM Usage
  const totalMem = os.totalmem();
  const freeMem = os.freemem();
  const usedMem = totalMem - freeMem;
  const ramPercent = Math.round((usedMem / totalMem) * 100);
  const ramUsedGB = (usedMem / (1024 ** 3)).toFixed(1);
  const ramTotalGB = (totalMem / (1024 ** 3)).toFixed(1);

  // CPU Usage (average load over all cores)
  const cpus = os.cpus();
  let totalIdle = 0;
  let totalTick = 0;

  for (const cpu of cpus) {
    for (const type in cpu.times) {
      totalTick += cpu.times[type];
    }
    totalIdle += cpu.times.idle;
  }

  const cpuPercent = Math.round(100 - (totalIdle / totalTick * 100));

  return {
    cpu: {
      percent: cpuPercent,
      cores: cpus.length
    },
    ram: {
      percent: ramPercent,
      usedGB: ramUsedGB,
      totalGB: ramTotalGB
    }
  };
}

function getResourceColor(percent) {
  if (percent >= 90) return c.neonRed + c.bold;
  if (percent >= 75) return c.neonRed;
  if (percent >= 50) return c.neonYellow;
  return c.neonGreen;
}

// ═══════════════════════════════════════════════════════════════
// USAGE TRACKING
// ═══════════════════════════════════════════════════════════════

function loadUsage() {
  try {
    if (fs.existsSync(USAGE_FILE)) {
      const data = JSON.parse(fs.readFileSync(USAGE_FILE, 'utf8'));
      const now = Date.now();
      if (data.lastMinuteStart < now - 60000) {
        return {
          lastMinuteStart: now,
          tokensThisMinute: 0,
          requestsThisMinute: 0,
          lastTotalTokens: data.lastTotalTokens || 0,
          lastTotalRequests: data.lastTotalRequests || 0
        };
      }
      return data;
    }
  } catch (e) { }
  return {
    lastMinuteStart: Date.now(),
    tokensThisMinute: 0,
    requestsThisMinute: 0,
    lastTotalTokens: 0,
    lastTotalRequests: 0
  };
}

function saveUsage(usage) {
  try {
    fs.writeFileSync(USAGE_FILE, JSON.stringify(usage), 'utf8');
  } catch (e) { }
}

// ═══════════════════════════════════════════════════════════════
// MAIN
// ═══════════════════════════════════════════════════════════════

let inputData = '';

process.stdin.setEncoding('utf8');
process.stdin.on('readable', () => {
  let chunk;
  while ((chunk = process.stdin.read()) !== null) {
    inputData += chunk;
  }
});

process.stdin.on('end', () => {
  let data;

  try {
    data = JSON.parse(inputData);
  } catch {
    const aiStatus = checkAIHandlerStatus();
    const aiLabel = aiStatus.running
      ? `${c.neonGreen}${c.bold}AI:ON${c.reset}${c.gray}(${aiStatus.models})${c.reset}`
      : `${c.neonRed}${c.bold}AI:OFF${c.reset}`;
    console.log(`${aiLabel} ${c.gray}║${c.reset} ${c.neonCyan}${c.bold}Claude Code${c.reset} ${c.gray}║${c.reset} ${c.dim}Waiting...${c.reset}`);
    return;
  }

  const parts = [];
  const modelConfig = getModelConfig(data.model?.id) || {
    name: data.model?.display_name || 'Unknown',
    tier: 'standard',
    contextWindow: 200000,
    limits: { tokensPerMinute: 40000, requestsPerMinute: 100 }
  };

  // Update usage tracking
  let usage = loadUsage();
  const now = Date.now();

  if (now - usage.lastMinuteStart >= 60000) {
    usage.lastMinuteStart = now;
    usage.tokensThisMinute = 0;
    usage.requestsThisMinute = 0;
  }

  const currentTotalTokens = (data.context_window?.total_input_tokens || 0) +
                              (data.context_window?.total_output_tokens || 0);
  const tokensDelta = Math.max(0, currentTotalTokens - usage.lastTotalTokens);

  if (tokensDelta > 0) {
    usage.tokensThisMinute += tokensDelta;
    usage.requestsThisMinute += 1;
    usage.lastTotalTokens = currentTotalTokens;
  }

  saveUsage(usage);

  // Get limits info
  const limits = modelConfig.limits || {};
  const tokensLimit = limits.tokensPerMinute || Infinity;
  const reqLimit = limits.requestsPerMinute || Infinity;
  const tokensRemaining = Math.max(0, tokensLimit - usage.tokensThisMinute);
  const requestsRemaining = Math.max(0, reqLimit - usage.requestsThisMinute);
  const tokensPercent = tokensLimit === Infinity ? 100 : Math.round((tokensRemaining / tokensLimit) * 100);
  const reqPercent = reqLimit === Infinity ? 100 : Math.round((requestsRemaining / reqLimit) * 100);
  const timeToReset = Math.max(0, Math.ceil((60000 - (now - usage.lastMinuteStart)) / 1000));

  // ═══════════════════════════════════════════════════════════════
  // BUILD STATUS LINE
  // ═══════════════════════════════════════════════════════════════

  // AI HANDLER STATUS (FIRST POSITION)
  const aiStatus = checkAIHandlerStatus();
  if (COMPACT_MODE) {
    const aiLabel = aiStatus.running
      ? `${c.neonGreen}${c.bold}AI${c.reset}`
      : `${c.neonRed}${c.bold}AI${c.reset}`;
    parts.push(aiLabel);
  } else {
    const aiLabel = aiStatus.running
      ? `${c.neonGreen}${c.bold}AI:ON${c.reset}${c.gray}(${aiStatus.models} models)${c.reset}`
      : `${c.neonRed}${c.bold}AI:OFF${c.reset}`;
    parts.push(aiLabel);
  }

  if (COMPACT_MODE) {
    // ─────────────────────────────────────────────────────────────
    // COMPACT MODE
    // ─────────────────────────────────────────────────────────────

    // Model (short)
    const tierInfo = aiConfig.tiers[modelConfig.tier] || aiConfig.tiers.standard;
    const tierColor = getColorCode(tierInfo.color);
    let shortName = modelConfig.name
      .replace(/Claude\s*\d*\.?\d*\s*/i, '')
      .replace('latest', '')
      .trim()
      .substring(0, 8);
    parts.push(`${tierColor}${c.bold}${shortName}${c.reset}`);

    // Context %
    if (data.context_window) {
      const ctx = data.context_window;
      const used = ctx.current_usage
        ? (ctx.current_usage.input_tokens || 0) + (ctx.current_usage.output_tokens || 0)
        : 0;
      const max = ctx.context_window_size || modelConfig.contextWindow;
      const pct = Math.round((used / max) * 100);
      parts.push(`${getUsageColor(pct)}${pct}%${c.reset}`);
    }

    // I/O
    if (data.context_window) {
      const i = data.context_window.total_input_tokens || 0;
      const o = data.context_window.total_output_tokens || 0;
      parts.push(`${c.neonBlue}${fmt(i)}${c.gray}/${c.neonGreen}${fmt(o)}${c.reset}`);
    }

    // Limits (compact: remaining only)
    const tokColor = getRemainColor(tokensPercent);
    const displayTok = tokensLimit === Infinity ? '∞' : fmt(tokensRemaining);
    parts.push(`${tokColor}${displayTok}${c.gray}/${c.dim}${timeToReset}s${c.reset}`);

    // MCP dots (compact)
    const dots = mcpServers.map(s => `${c.neonGreen}●${c.reset}`).join('');
    if (dots) parts.push(dots);

    // System Resources (compact) - CPU and RAM only
    const res = getSystemResources();
    parts.push(
      `${getResourceColor(res.cpu.percent)}C${res.cpu.percent}%${c.reset}` +
      `${c.gray}/${c.reset}` +
      `${getResourceColor(res.ram.percent)}R${res.ram.percent}%${c.reset}`
    );

  } else {
    // ─────────────────────────────────────────────────────────────
    // FULL MODE
    // ─────────────────────────────────────────────────────────────

    // MODEL + TIER
    const tierInfo = aiConfig.tiers[modelConfig.tier] || aiConfig.tiers.standard;
    const tierBadge = `[${tierInfo.label}]`;
    const tierColor = getColorCode(tierInfo.color);
    let displayName = modelConfig.name
      .replace('Claude 3.5 ', '').replace('Claude 3 ', '')
      .replace('latest', '').trim();
    parts.push(`${tierColor}${c.bold}${tierBadge} ${displayName}${c.reset}`);

    // CONTEXT WINDOW
    if (data.context_window) {
      const ctx = data.context_window;
      const used = ctx.current_usage
        ? (ctx.current_usage.input_tokens || 0) +
          (ctx.current_usage.output_tokens || 0) +
          (ctx.current_usage.cache_creation_input_tokens || 0)
        : 0;
      const max = ctx.context_window_size || modelConfig.contextWindow;
      const usedPercent = Math.round((used / max) * 100);
      parts.push(`${c.gray}Context:${c.reset}${getUsageColor(usedPercent)}${usedPercent}%${c.reset}`);
    }

    // TOKENS I/O
    if (data.context_window) {
      const input = data.context_window.total_input_tokens || 0;
      const output = data.context_window.total_output_tokens || 0;
      parts.push(`${c.gray}Tokens:${c.reset}${c.neonBlue}↑${fmt(input)}${c.reset}${c.gray}/${c.reset}${c.neonGreen}↓${fmt(output)}${c.reset}`);
    }

    // RATE LIMITS (remaining/limit format)
    const tokColor = getRemainColor(tokensPercent);
    const reqColor = getRemainColor(reqPercent);
    const timeColor = timeToReset < 10 ? c.neonRed + c.blink : c.dim;

    const displayTokRemain = tokensLimit === Infinity ? '∞' : fmt(tokensRemaining);
    const displayTokLimit = tokensLimit === Infinity ? '∞' : fmt(tokensLimit);
    const displayReqRemain = reqLimit === Infinity ? '∞' : requestsRemaining;
    const displayReqLimit = reqLimit === Infinity ? '∞' : reqLimit;

    parts.push(
      `${c.gray}Limits:${c.reset}` +
      `${tokColor}${displayTokRemain}${c.gray}/${c.dim}${displayTokLimit}${c.reset}${c.gray}tok ${c.reset}` +
      `${reqColor}${displayReqRemain}${c.gray}/${c.dim}${displayReqLimit}${c.reset}${c.gray}req ${c.reset}` +
      `${timeColor}${timeToReset}s${c.reset}`
    );

    // MCP STATUS
    const mcpDots = mcpServers.map(server => {
      const abbrev = { 'serena': 'S', 'desktop-commander': 'D', 'playwright': 'P' }[server] || server[0].toUpperCase();
      return `${c.neonGreen}${abbrev}${c.reset}`;
    }).join('');
    if (mcpDots) {
      parts.push(`${c.gray}MCP:[${c.reset}${mcpDots}${c.gray}]${c.reset}`);
    }

    // SYSTEM RESOURCES (full mode) - CPU and RAM only
    const resources = getSystemResources();
    const cpuColor = getResourceColor(resources.cpu.percent);
    const ramColor = getResourceColor(resources.ram.percent);
    parts.push(
      `${c.gray}Sys:${c.reset}` +
      `${cpuColor}CPU ${resources.cpu.percent}%${c.reset}` +
      `${c.gray}(${resources.cpu.cores}c)${c.reset} ` +
      `${ramColor}RAM ${resources.ram.usedGB}/${resources.ram.totalGB}GB${c.reset}`
    );
  }

  // Output
  const separator = COMPACT_MODE ? ` ${c.gray}│${c.reset} ` : ` ${c.gray}║${c.reset} `;
  console.log(parts.join(separator));
});

// Fallback when stdin is not piped
setTimeout(() => {
  if (!inputData) {
    const mode = COMPACT_MODE ? 'COMPACT' : 'FULL';
    const res = getSystemResources();
    const aiStatus = checkAIHandlerStatus();
    const cpuCol = getResourceColor(res.cpu.percent);
    const ramCol = getResourceColor(res.ram.percent);

    const aiLabel = aiStatus.running
      ? `${c.neonGreen}${c.bold}AI:ON${c.reset}${c.gray}(${aiStatus.models})${c.reset}`
      : `${c.neonRed}${c.bold}AI:OFF${c.reset}`;

    console.log(
      `${aiLabel} ${c.gray}║${c.reset} ` +
      `${c.neonBlue}${c.bold}[STD]${c.reset} ${c.neonCyan}Claude${c.reset} ${c.gray}║${c.reset} ` +
      `${cpuCol}CPU ${res.cpu.percent}%${c.reset} ` +
      `${ramCol}RAM ${res.ram.usedGB}/${res.ram.totalGB}GB${c.reset} ` +
      `${c.gray}║${c.reset} ${c.dim}${mode} (${TERMINAL_WIDTH}cols)${c.reset}`
    );
    process.exit(0);
  }
}, 100);
