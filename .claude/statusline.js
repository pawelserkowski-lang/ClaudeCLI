#!/usr/bin/env node
/**
 * Claude Code CLI Status Line - VIBRANT EDITION v4
 *
 * FULL:    Model | Context | Tokens | Cache | Limits | Cost | Lines | [MCP] | Sys:CPU/RAM/Disk | HYDRA
 * COMPACT: Model | Ctx | I/O | Lim | $ | MCP | C%/R%/D%
 *
 * Config: ../ai-models.json | Settings: ./settings.local.json
 * Env: STATUSLINE_COMPACT=1 for forced compact mode
 */

const fs = require('fs');
const path = require('path');
const os = require('os');

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

function fmtCost(cost) {
  if (!cost && cost !== 0) return '$0.00';
  if (cost < 0.01) return '$' + cost.toFixed(4);
  if (cost < 1) return '$' + cost.toFixed(3);
  return '$' + cost.toFixed(2);
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

function rainbow(text) {
  const colors = [c.neonRed, c.neonYellow, c.neonGreen, c.neonCyan, c.neonBlue, c.neonMagenta];
  return text.split('').map((char, i) => `${colors[i % colors.length]}${c.bold}${char}`).join('') + c.reset;
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
// SYSTEM RESOURCES (CPU & RAM)
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

  // Calculate CPU usage (non-idle percentage)
  const cpuPercent = Math.round(100 - (totalIdle / totalTick * 100));

  // Disk Usage (sync method for simplicity)
  let diskInfo = { percent: 0, usedGB: '?', totalGB: '?', freeGB: '?' };
  try {
    const { execSync } = require('child_process');
    // Windows: use PowerShell Get-PSDrive
    if (process.platform === 'win32') {
      const output = execSync(
        'powershell -NoProfile -Command "(Get-PSDrive C).Used,(Get-PSDrive C).Free" ',
        { encoding: 'utf8', timeout: 3000, windowsHide: true }
      );
      const lines = output.trim().split(/\r?\n/);
      if (lines.length >= 2) {
        const usedSpace = parseInt(lines[0]) || 0;
        const freeSpace = parseInt(lines[1]) || 0;
        const totalSize = usedSpace + freeSpace;
        if (totalSize > 0) {
          diskInfo = {
            percent: Math.round((usedSpace / totalSize) * 100),
            usedGB: (usedSpace / (1024 ** 3)).toFixed(0),
            totalGB: (totalSize / (1024 ** 3)).toFixed(0),
            freeGB: (freeSpace / (1024 ** 3)).toFixed(0)
          };
        }
      }
    } else {
      // Unix/Linux/Mac: use df
      const output = execSync('df -B1 / | tail -1', { encoding: 'utf8', timeout: 2000 });
      const parts = output.trim().split(/\s+/);
      if (parts.length >= 4) {
        const totalSize = parseInt(parts[1]) || 1;
        const usedSpace = parseInt(parts[2]) || 0;
        const freeSpace = parseInt(parts[3]) || 0;
        diskInfo = {
          percent: Math.round((usedSpace / totalSize) * 100),
          usedGB: (usedSpace / (1024 ** 3)).toFixed(0),
          totalGB: (totalSize / (1024 ** 3)).toFixed(0),
          freeGB: (freeSpace / (1024 ** 3)).toFixed(0)
        };
      }
    }
  } catch (e) {
    // Disk info unavailable
  }

  return {
    cpu: {
      percent: cpuPercent,
      cores: cpus.length
    },
    ram: {
      percent: ramPercent,
      usedGB: ramUsedGB,
      totalGB: ramTotalGB
    },
    disk: diskInfo
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
    console.log(`${c.neonCyan}${c.bold}[REGIS]${c.reset} ${c.gray}║${c.reset} ${rainbow('HYDRA')} ${c.gray}║${c.reset} ${c.dim}Waiting...${c.reset}`);
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

    // Cost
    if (data.cost?.total_cost_usd != null) {
      const cost = data.cost.total_cost_usd;
      const costColor = cost > 1 ? c.neonRed : cost > 0.1 ? c.neonYellow : c.neonGreen;
      parts.push(`${costColor}${fmtCost(cost)}${c.reset}`);
    }

    // MCP dots (compact)
    const dots = mcpServers.map(s => `${c.neonGreen}●${c.reset}`).join('');
    if (dots) parts.push(dots);

    // System Resources (compact)
    const res = getSystemResources();
    parts.push(
      `${getResourceColor(res.cpu.percent)}C${res.cpu.percent}%${c.reset}` +
      `${c.gray}/${c.reset}` +
      `${getResourceColor(res.ram.percent)}R${res.ram.percent}%${c.reset}` +
      `${c.gray}/${c.reset}` +
      `${getResourceColor(res.disk.percent)}D${res.disk.percent}%${c.reset}`
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

    // CACHE HIT RATIO
    if (data.context_window) {
      const ctx = data.context_window;
      const cacheRead = ctx.total_cache_read_input_tokens ||
                        ctx.cache_read_input_tokens ||
                        (ctx.current_usage?.cache_read_input_tokens) || 0;
      const totalInput = ctx.total_input_tokens || 0;
      if (totalInput > 0) {
        const cachePercent = Math.round((cacheRead / totalInput) * 100);
        const cacheColor = cachePercent >= 70 ? c.neonGreen :
                           cachePercent >= 40 ? c.neonYellow : c.neonRed;
        parts.push(`${c.gray}Cache:${c.reset}${cacheColor}${cachePercent}%${c.reset}`);
      }
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

    // COST
    if (data.cost?.total_cost_usd != null) {
      const cost = data.cost.total_cost_usd;
      const costColor = cost > 1 ? c.neonRed : cost > 0.1 ? c.neonYellow : c.neonGreen;
      parts.push(`${c.gray}Cost:${c.reset}${costColor}${fmtCost(cost)}${c.reset}`);
    }

    // LINES
    if (data.cost) {
      const added = data.cost.total_lines_added || 0;
      const removed = data.cost.total_lines_removed || 0;
      if (added > 0 || removed > 0) {
        parts.push(`${c.gray}Lines:${c.reset}${c.neonGreen}+${added}${c.reset}${c.gray}/${c.reset}${c.neonRed}-${removed}${c.reset}`);
      }
    }

    // MCP STATUS
    const mcpDots = mcpServers.map(server => {
      const abbrev = { 'serena': 'S', 'desktop-commander': 'D', 'playwright': 'P' }[server] || server[0].toUpperCase();
      return `${c.neonGreen}${abbrev}${c.reset}`;
    }).join('');
    if (mcpDots) {
      parts.push(`${c.gray}MCP:[${c.reset}${mcpDots}${c.gray}]${c.reset}`);
    }

    // SYSTEM RESOURCES (full mode)
    const resources = getSystemResources();
    const cpuColor = getResourceColor(resources.cpu.percent);
    const ramColor = getResourceColor(resources.ram.percent);
    const diskColor = getResourceColor(resources.disk.percent);
    parts.push(
      `${c.gray}Sys:${c.reset}` +
      `${cpuColor}CPU ${resources.cpu.percent}%${c.reset}` +
      `${c.gray}(${resources.cpu.cores}c)${c.reset} ` +
      `${ramColor}RAM ${resources.ram.usedGB}/${resources.ram.totalGB}GB${c.reset} ` +
      `${diskColor}C: ${resources.disk.usedGB}/${resources.disk.totalGB}GB${c.reset}`
    );

    // HYDRA
    parts.push(rainbow('HYDRA'));
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
    const cpuCol = getResourceColor(res.cpu.percent);
    const ramCol = getResourceColor(res.ram.percent);
    const diskCol = getResourceColor(res.disk.percent);
    console.log(
      `${c.neonBlue}${c.bold}[STD]${c.reset} ${c.neonCyan}Regis${c.reset} ${c.gray}║${c.reset} ` +
      rainbow('HYDRA') + c.reset + ` ${c.gray}║${c.reset} ` +
      `${cpuCol}CPU ${res.cpu.percent}%${c.reset} ` +
      `${ramCol}RAM ${res.ram.usedGB}/${res.ram.totalGB}GB${c.reset} ` +
      `${diskCol}C: ${res.disk.freeGB}GB free${c.reset} ` +
      `${c.gray}║${c.reset} ${c.dim}${mode} (${TERMINAL_WIDTH}cols)${c.reset}`
    );
    process.exit(0);
  }
}, 100);
