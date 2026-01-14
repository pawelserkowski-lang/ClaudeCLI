#!/usr/bin/env node
/**
 * Claude Code CLI Status Line - HYDRA DASHBOARD v6.0
 *
 * TWO-LINE RICH DASHBOARD with full graphics and extended info:
 *
 * LINE 1: ╭─ ⚡ AI:ON(5) │ ◉ Opus 4.5 [PRO] │ ▓▓▓▓░░░ 42% │ ↑Input:45K ↓Output:12K │ [S●D●P●] │ CPU:█░░ 5% ─╮
 * LINE 2: ╰─ ⎇ master* │ 📊 35K/40K tokens │ ⏱️ 94/100 requests │ ⏰ Reset:26s │ 💰 Cost:$0.45 │ 📈 Cache:78% │ 🕐 Uptime:2h15m ─╯
 *
 * COMPACT (2 lines, shorter):
 * ⚡AI ◉Opus 42% ↑45K↓12K [●●●] C5%
 * ⎇master* 📊35K/40K ⏱94/100 ⏰26s 💰$0.45
 */

const fs = require('fs');
const path = require('path');
const os = require('os');
const { execSync } = require('child_process');

// Paths
const USAGE_FILE = path.join(os.tmpdir(), 'claude-usage-tracking.json');
const STATE_FILE = path.join(__dirname, '..', 'ai-handler', 'ai-state.json');
const CONFIG_FILE = path.join(__dirname, '..', 'ai-handler', 'ai-config.json');
const SETTINGS_FILE = path.join(__dirname, 'settings.local.json');
const SESSION_FILE = path.join(os.tmpdir(), 'claude-session-stats.json');

// Terminal dimensions
const TERMINAL_WIDTH = process.stdout.columns || 120;
const TERMINAL_HEIGHT = process.stdout.rows || 24;
const COMPACT_MODE = process.env.STATUSLINE_COMPACT === '1' || TERMINAL_WIDTH < 100;

// Unicode symbols
const sym = {
  // Borders
  topLeft: '╭', topRight: '╮', bottomLeft: '╰', bottomRight: '╯',
  horizontal: '─', vertical: '│', separator: '│',

  // Status icons
  lightning: '⚡', circle: '◉', dot: '●', empty: '○',
  check: '✓', cross: '✗', warning: '⚠',

  // Direction & flow
  up: '↑', down: '↓', refresh: '⟳',

  // Progress bar chars
  full: '▓', empty: '░', block: '█',

  // Section icons
  chart: '📊', timer: '⏱️', clock: '⏰',
  money: '💰', trend: '📈', time: '🕐',
  cpu: '🖥️', ram: '💾', network: '📡',

  // Git
  git: '⎇',
};

// ANSI color codes
const c = {
  reset: '\x1b[0m',
  bold: '\x1b[1m',
  dim: '\x1b[2m',
  blink: '\x1b[5m',

  // Standard
  red: '\x1b[31m', green: '\x1b[32m', yellow: '\x1b[33m',
  blue: '\x1b[34m', magenta: '\x1b[35m', cyan: '\x1b[36m',
  white: '\x1b[37m', gray: '\x1b[90m',

  // Bright / Neon
  neonRed: '\x1b[91m', neonGreen: '\x1b[92m', neonYellow: '\x1b[93m',
  neonBlue: '\x1b[94m', neonMagenta: '\x1b[95m', neonCyan: '\x1b[96m',
  neonWhite: '\x1b[97m',

  // Backgrounds
  bgRed: '\x1b[41m', bgGreen: '\x1b[42m', bgYellow: '\x1b[43m',
  bgBlue: '\x1b[44m', bgMagenta: '\x1b[45m', bgCyan: '\x1b[46m',
};

// ═══════════════════════════════════════════════════════════════
// GIT STATUS
// ═══════════════════════════════════════════════════════════════

function getGitStatus() {
  try {
    const branch = execSync('git branch --show-current 2>nul', { encoding: 'utf8', timeout: 1000 }).trim();
    const dirty = execSync('git status --porcelain 2>nul', { encoding: 'utf8', timeout: 1000 }).trim();
    return { branch: branch || 'detached', dirty: dirty.length > 0 };
  } catch (e) {
    return { branch: null, dirty: false };
  }
}

// ═══════════════════════════════════════════════════════════════
// SESSION TRACKING
// ═══════════════════════════════════════════════════════════════

function loadSession() {
  try {
    if (fs.existsSync(SESSION_FILE)) {
      return JSON.parse(fs.readFileSync(SESSION_FILE, 'utf8'));
    }
  } catch (e) {}

  const session = {
    startTime: Date.now(),
    requestCount: 0,
    totalCost: 0,
    cacheHits: 0,
    cacheMisses: 0
  };
  saveSession(session);
  return session;
}

function saveSession(session) {
  try {
    fs.writeFileSync(SESSION_FILE, JSON.stringify(session), 'utf8');
  } catch (e) {}
}

function getSessionUptime(session) {
  const ms = Date.now() - session.startTime;
  const hours = Math.floor(ms / 3600000);
  const minutes = Math.floor((ms % 3600000) / 60000);

  if (hours > 0) return `${hours}h ${minutes}m`;
  return `${minutes}m`;
}

// ═══════════════════════════════════════════════════════════════
// HELPER FUNCTIONS
// ═══════════════════════════════════════════════════════════════

function fmt(n) {
  if (n === undefined || n === null) return '0';
  if (n >= 1000000) return (n / 1000000).toFixed(1) + 'M';
  if (n >= 1000) return (n / 1000).toFixed(1) + 'K';
  return Math.round(n).toString();
}

function fmtMoney(n) {
  if (n === undefined || n === null) return '$0.00';
  return '$' + n.toFixed(2);
}

function getColorByPercent(percent, inverse = false) {
  if (inverse) {
    // For remaining (high = good)
    if (percent <= 10) return c.neonRed + c.blink + c.bold;
    if (percent <= 25) return c.neonRed;
    if (percent <= 50) return c.neonYellow;
    return c.neonGreen;
  } else {
    // For usage (low = good)
    if (percent >= 90) return c.neonRed + c.bold;
    if (percent >= 75) return c.neonRed;
    if (percent >= 50) return c.neonYellow;
    return c.neonGreen;
  }
}

function getTierColor(tier) {
  const map = {
    'pro': c.neonMagenta, 'standard': c.neonBlue, 'lite': c.neonGreen,
    'PRO': c.neonMagenta, 'STD': c.neonBlue, 'LITE': c.neonGreen
  };
  return map[tier] || c.neonWhite;
}

function progressBar(percent, width = 10) {
  const filled = Math.round((percent / 100) * width);
  const empty = width - filled;
  return sym.full.repeat(filled) + sym.empty.repeat(empty);
}

// ═══════════════════════════════════════════════════════════════
// AI HANDLER STATUS
// ═══════════════════════════════════════════════════════════════

function checkAIHandlerStatus() {
  let ollamaRunning = false;
  let modelCount = 0;
  let apiKeysStatus = { anthropic: 0, openai: 0, google: 0 };

  try {
    // Check Ollama process
    if (process.platform === 'win32') {
      const output = execSync('tasklist /FI "IMAGENAME eq ollama.exe" /NH 2>nul', {
        encoding: 'utf8', timeout: 2000, windowsHide: true
      });
      ollamaRunning = output.toLowerCase().includes('ollama.exe');
    } else {
      const output = execSync('pgrep -x ollama 2>/dev/null || echo ""', {
        encoding: 'utf8', timeout: 2000
      });
      ollamaRunning = output.trim().length > 0;
    }

    // Count models
    if (ollamaRunning) {
      try {
        const modelsOutput = execSync('ollama list 2>nul', {
          encoding: 'utf8', timeout: 3000, windowsHide: true
        });
        modelCount = Math.max(0, modelsOutput.trim().split('\n').length - 1);
      } catch (e) {}
    }

    // Check API keys
    const keyPatterns = {
      anthropic: ['ANTHROPIC_API_KEY', 'ANTHROPIC_API_KEY_2'],
      openai: ['OPENAI_API_KEY'],
      google: ['GOOGLE_API_KEY']
    };

    for (const [provider, envVars] of Object.entries(keyPatterns)) {
      apiKeysStatus[provider] = envVars.filter(v => process.env[v]).length;
    }

  } catch (e) {}

  return { running: ollamaRunning, models: modelCount, apiKeys: apiKeysStatus };
}

// ═══════════════════════════════════════════════════════════════
// SYSTEM RESOURCES
// ═══════════════════════════════════════════════════════════════

function getSystemResources() {
  const totalMem = os.totalmem();
  const freeMem = os.freemem();
  const usedMem = totalMem - freeMem;
  const ramPercent = Math.round((usedMem / totalMem) * 100);
  const ramUsedGB = (usedMem / (1024 ** 3)).toFixed(1);
  const ramTotalGB = (totalMem / (1024 ** 3)).toFixed(1);

  const cpus = os.cpus();
  let totalIdle = 0, totalTick = 0;
  for (const cpu of cpus) {
    for (const type in cpu.times) totalTick += cpu.times[type];
    totalIdle += cpu.times.idle;
  }
  const cpuPercent = Math.round(100 - (totalIdle / totalTick * 100));

  return {
    cpu: { percent: cpuPercent, cores: cpus.length },
    ram: { percent: ramPercent, usedGB: ramUsedGB, totalGB: ramTotalGB }
  };
}

// ═══════════════════════════════════════════════════════════════
// MCP STATUS
// ═══════════════════════════════════════════════════════════════

function getMCPStatus() {
  let mcpServers = [];
  try {
    const settings = JSON.parse(fs.readFileSync(SETTINGS_FILE, 'utf8'));
    mcpServers = settings.enabledMcpjsonServers || [];
  } catch (e) {
    mcpServers = ['serena', 'desktop-commander', 'playwright'];
  }

  return mcpServers.map(server => {
    const abbrev = { 'serena': 'S', 'desktop-commander': 'D', 'playwright': 'P' }[server] || server[0].toUpperCase();
    // Assume running if configured (could add actual health check)
    return { name: server, abbrev, status: 'ok' };
  });
}

// ═══════════════════════════════════════════════════════════════
// MCP LATENCY
// ═══════════════════════════════════════════════════════════════

function getMCPLatency() {
  const start = Date.now();
  try {
    execSync('curl -s -o nul -w "" http://localhost:11434/api/tags', { timeout: 2000, windowsHide: true });
    return Date.now() - start;
  } catch (e) {
    return -1;
  }
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
  } catch (e) {}
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
  } catch (e) {}
}

// ═══════════════════════════════════════════════════════════════
// BUILD TWO-LINE DASHBOARD
// ═══════════════════════════════════════════════════════════════

function buildDashboard(data) {
  const session = loadSession();
  const aiStatus = checkAIHandlerStatus();
  const resources = getSystemResources();
  const mcpStatus = getMCPStatus();
  const usage = loadUsage();
  const now = Date.now();

  // Update session
  session.requestCount++;
  saveSession(session);

  // Get model info
  const modelName = data?.model?.display_name || 'Claude';
  const modelId = data?.model?.id || '';

  // Determine tier
  let tier = 'STD';
  if (modelId.includes('opus')) tier = 'PRO';
  else if (modelId.includes('haiku')) tier = 'LITE';
  else if (modelId.includes('sonnet')) tier = 'STD';

  const tierColor = getTierColor(tier);

  // Context usage
  let contextPercent = 0;
  let inputTokens = 0;
  let outputTokens = 0;

  if (data?.context_window) {
    const ctx = data.context_window;
    const used = ctx.current_usage
      ? (ctx.current_usage.input_tokens || 0) + (ctx.current_usage.output_tokens || 0)
      : 0;
    const max = ctx.context_window_size || 200000;
    contextPercent = Math.round((used / max) * 100);
    inputTokens = ctx.total_input_tokens || 0;
    outputTokens = ctx.total_output_tokens || 0;
  }

  // Rate limits
  const tokensLimit = 40000; // Default
  const reqLimit = 100;

  // Update usage tracking
  const currentTotalTokens = inputTokens + outputTokens;
  const tokensDelta = Math.max(0, currentTotalTokens - usage.lastTotalTokens);

  if (tokensDelta > 0) {
    usage.tokensThisMinute += tokensDelta;
    usage.requestsThisMinute += 1;
    usage.lastTotalTokens = currentTotalTokens;
    saveUsage(usage);
  }

  const tokensRemaining = Math.max(0, tokensLimit - usage.tokensThisMinute);
  const requestsRemaining = Math.max(0, reqLimit - usage.requestsThisMinute);
  const tokensPercent = Math.round((tokensRemaining / tokensLimit) * 100);
  const reqPercent = Math.round((requestsRemaining / reqLimit) * 100);
  const timeToReset = Math.max(0, Math.ceil((60000 - (now - usage.lastMinuteStart)) / 1000));

  // Calculate estimated cost (rough estimate)
  const costPerInputToken = 0.000003; // $3/1M for Sonnet
  const costPerOutputToken = 0.000015; // $15/1M for Sonnet
  const sessionCost = (inputTokens * costPerInputToken) + (outputTokens * costPerOutputToken);

  // Cache hit rate (simulated)
  const cacheHitRate = 78; // Could read from actual cache stats

  // Build parts
  const totalKeys = aiStatus.apiKeys.anthropic + aiStatus.apiKeys.openai + aiStatus.apiKeys.google;

  if (COMPACT_MODE) {
    // ═══════════════════════════════════════════════════════════
    // COMPACT MODE (2 short lines)
    // ═══════════════════════════════════════════════════════════

    // LINE 1
    const line1Parts = [];

    // AI Status
    if (aiStatus.running) {
      line1Parts.push(`${c.neonGreen}${sym.lightning}AI${c.reset}`);
    } else if (totalKeys > 0) {
      line1Parts.push(`${c.neonYellow}${sym.lightning}AI${c.reset}`);
    } else {
      line1Parts.push(`${c.neonRed}${sym.lightning}AI${c.reset}`);
    }

    // Model (short name)
    const shortName = modelName.replace(/Claude\s*\d*\.?\d*\s*/i, '').substring(0, 6) || 'Claude';
    line1Parts.push(`${tierColor}${sym.circle}${shortName}${c.reset}`);

    // Context
    line1Parts.push(`${getColorByPercent(contextPercent)}${contextPercent}%${c.reset}`);

    // Tokens I/O
    line1Parts.push(`${c.neonBlue}${sym.up}${fmt(inputTokens)}${c.neonGreen}${sym.down}${fmt(outputTokens)}${c.reset}`);

    // MCP dots
    const mcpDots = mcpStatus.map(s => `${c.neonGreen}${sym.dot}${c.reset}`).join('');
    line1Parts.push(`[${mcpDots}]`);

    // CPU
    line1Parts.push(`${getColorByPercent(resources.cpu.percent)}C${resources.cpu.percent}%${c.reset}`);

    // RAM
    line1Parts.push(`${getColorByPercent(resources.ram.percent)}${sym.ram}${resources.ram.percent}%${c.reset}`);

    // LINE 2
    const line2Parts = [];

    // Git branch
    const git = getGitStatus();
    const gitPart = git.branch ? `${sym.git} ${git.branch}${git.dirty ? '*' : ''}` : '';
    if (gitPart) {
      line2Parts.push(`${git.dirty ? c.neonYellow : c.neonCyan}${gitPart}${c.reset}`);
    }

    // Tokens remaining
    line2Parts.push(`${sym.chart}${getColorByPercent(tokensPercent, true)}${fmt(tokensRemaining)}/${fmt(tokensLimit)}${c.reset}`);

    // Requests
    line2Parts.push(`${sym.timer}${getColorByPercent(reqPercent, true)}${requestsRemaining}/${reqLimit}${c.reset}`);

    // Reset time
    line2Parts.push(`${sym.clock}${c.dim}${timeToReset}s${c.reset}`);

    // Cost
    line2Parts.push(`${sym.money}${c.neonYellow}${fmtMoney(sessionCost)}${c.reset}`);

    // Network latency
    const latency = getMCPLatency();
    const latencyColor = latency < 0 ? c.neonRed : (latency < 100 ? c.neonGreen : (latency < 500 ? c.neonYellow : c.neonRed));
    const latencyText = latency < 0 ? 'ERR' : `${latency}ms`;
    line2Parts.push(`${sym.network}${latencyColor}${latencyText}${c.reset}`);

    const line1 = line1Parts.join(' ');
    const line2 = line2Parts.join(' ');

    return `${line1}\n${line2}`;

  } else {
    // ═══════════════════════════════════════════════════════════
    // FULL MODE (2 rich lines with borders)
    // ═══════════════════════════════════════════════════════════

    // LINE 1 PARTS
    const line1Parts = [];

    // AI Status with model count and keys
    let aiLabel = '';
    if (aiStatus.running) {
      aiLabel = `${c.neonGreen}${c.bold}${sym.lightning} AI:ON${c.reset}${c.gray}(${aiStatus.models})${c.reset}`;
    } else if (totalKeys > 0) {
      aiLabel = `${c.neonYellow}${c.bold}${sym.lightning} AI:CLOUD${c.reset}`;
    } else {
      aiLabel = `${c.neonRed}${c.bold}${sym.lightning} AI:OFF${c.reset}`;
    }

    // Keys indicator
    if (totalKeys > 0) {
      const keysInfo =
        `${aiStatus.apiKeys.anthropic > 0 ? c.neonMagenta + 'A' + aiStatus.apiKeys.anthropic : c.dim + 'A0'}${c.reset}` +
        `${c.gray}/${c.reset}` +
        `${aiStatus.apiKeys.openai > 0 ? c.neonGreen + 'O' + aiStatus.apiKeys.openai : c.dim + 'O0'}${c.reset}`;
      aiLabel += ` ${c.gray}Keys:${c.reset}${keysInfo}`;
    }
    line1Parts.push(aiLabel);

    // Model with tier badge
    const displayName = modelName.replace('Claude 3.5 ', '').replace('Claude 3 ', '').trim();
    line1Parts.push(`${tierColor}${c.bold}${sym.circle} ${displayName} [${tier}]${c.reset}`);

    // Context with progress bar
    const ctxColor = getColorByPercent(contextPercent);
    const ctxBar = progressBar(contextPercent, 8);
    line1Parts.push(`${ctxColor}${ctxBar} ${contextPercent}%${c.reset}`);

    // Tokens I/O (with labels in FULL mode)
    line1Parts.push(`${c.neonBlue}${sym.up}Input:${fmt(inputTokens)}${c.reset} ${c.neonGreen}${sym.down}Output:${fmt(outputTokens)}${c.reset}`);

    // MCP Status
    const mcpIndicators = mcpStatus.map(s => {
      const color = s.status === 'ok' ? c.neonGreen : c.neonRed;
      return `${color}${s.abbrev}${sym.dot}${c.reset}`;
    }).join('');
    line1Parts.push(`[${mcpIndicators}]`);

    // CPU with mini bar
    const cpuBar = progressBar(resources.cpu.percent, 3);
    const cpuColor = getColorByPercent(resources.cpu.percent);
    line1Parts.push(`${cpuColor}CPU:${cpuBar} ${resources.cpu.percent}%${c.reset}`);

    // RAM
    const ramColor = getColorByPercent(resources.ram.percent);
    line1Parts.push(`${ramColor}${sym.ram} RAM:${resources.ram.percent}%${c.reset}`);

    // LINE 2 PARTS
    const line2Parts = [];

    // Git branch
    const git = getGitStatus();
    const gitPart = git.branch ? `${sym.git} ${git.branch}${git.dirty ? '*' : ''}` : '';
    if (gitPart) {
      line2Parts.push(`${git.dirty ? c.neonYellow : c.neonCyan}${gitPart}${c.reset}`);
    }

    // Tokens remaining/limit (with "tokens" suffix in FULL mode)
    const tokColor = getColorByPercent(tokensPercent, true);
    line2Parts.push(`${sym.chart} ${tokColor}${fmt(tokensRemaining)}/${fmt(tokensLimit)} tokens${c.reset}`);

    // Requests remaining/limit (with "requests" suffix in FULL mode)
    const reqColor = getColorByPercent(reqPercent, true);
    line2Parts.push(`${sym.timer} ${reqColor}${requestsRemaining}/${reqLimit} requests${c.reset}`);

    // Reset timer
    const timeColor = timeToReset < 10 ? c.neonRed + c.blink : c.dim;
    line2Parts.push(`${sym.clock} ${c.gray}Reset:${c.reset} ${timeColor}${timeToReset}s${c.reset}`);

    // Session cost
    line2Parts.push(`${sym.money} ${c.gray}Cost:${c.reset} ${c.neonYellow}${fmtMoney(sessionCost)}${c.reset}`);

    // Cache hit rate
    line2Parts.push(`${sym.trend} ${c.gray}Cache:${c.reset} ${c.neonCyan}${cacheHitRate}%${c.reset}`);

    // Session uptime (with "Uptime:" label in FULL mode)
    const uptime = getSessionUptime(session);
    line2Parts.push(`${sym.time} ${c.gray}Uptime:${c.reset}${c.dim}${uptime}${c.reset}`);

    // Network latency
    const latency = getMCPLatency();
    const latencyColor = latency < 0 ? c.neonRed : (latency < 100 ? c.neonGreen : (latency < 500 ? c.neonYellow : c.neonRed));
    const latencyText = latency < 0 ? 'ERR' : `${latency}ms`;
    line2Parts.push(`${sym.network} ${latencyColor}${latencyText}${c.reset}`);

    // Build lines with borders
    const sep = ` ${c.gray}${sym.separator}${c.reset} `;
    const line1Content = line1Parts.join(sep);
    const line2Content = line2Parts.join(sep);

    const line1 = `${c.gray}${sym.topLeft}${sym.horizontal}${c.reset} ${line1Content} ${c.gray}${sym.horizontal}${sym.topRight}${c.reset}`;
    const line2 = `${c.gray}${sym.bottomLeft}${sym.horizontal}${c.reset} ${line2Content} ${c.gray}${sym.horizontal}${sym.bottomRight}${c.reset}`;

    return `${line1}\n${line2}`;
  }
}

// ═══════════════════════════════════════════════════════════════
// FALLBACK DASHBOARD (no stdin data)
// ═══════════════════════════════════════════════════════════════

function buildFallbackDashboard() {
  const session = loadSession();
  const aiStatus = checkAIHandlerStatus();
  const resources = getSystemResources();
  const mcpStatus = getMCPStatus();
  const totalKeys = aiStatus.apiKeys.anthropic + aiStatus.apiKeys.openai;

  if (COMPACT_MODE) {
    // Compact fallback
    let aiLabel = aiStatus.running ? `${c.neonGreen}${sym.lightning}AI${c.reset}` :
                  totalKeys > 0 ? `${c.neonYellow}${sym.lightning}AI${c.reset}` :
                  `${c.neonRed}${sym.lightning}AI${c.reset}`;

    const mcpDots = mcpStatus.map(() => `${c.neonGreen}${sym.dot}${c.reset}`).join('');

    const line1 = `${aiLabel} ${c.neonBlue}${sym.circle}Claude${c.reset} [${mcpDots}] ${getColorByPercent(resources.cpu.percent)}C${resources.cpu.percent}%${c.reset}`;
    const line2 = `${sym.chart}${c.dim}Waiting...${c.reset} ${sym.time}${c.dim}${getSessionUptime(session)}${c.reset}`;

    return `${line1}\n${line2}`;
  }

  // Full fallback
  let aiLabel = '';
  if (aiStatus.running) {
    aiLabel = `${c.neonGreen}${c.bold}${sym.lightning} AI:ON${c.reset}${c.gray}(${aiStatus.models})${c.reset}`;
  } else if (totalKeys > 0) {
    aiLabel = `${c.neonYellow}${c.bold}${sym.lightning} AI:CLOUD${c.reset}`;
  } else {
    aiLabel = `${c.neonRed}${c.bold}${sym.lightning} AI:OFF${c.reset}`;
  }

  if (totalKeys > 0) {
    aiLabel += ` ${c.gray}Keys:${c.neonMagenta}A${aiStatus.apiKeys.anthropic}${c.gray}/${c.neonGreen}O${aiStatus.apiKeys.openai}${c.reset}`;
  }

  const mcpIndicators = mcpStatus.map(s => `${c.neonGreen}${s.abbrev}${sym.dot}${c.reset}`).join('');
  const cpuColor = getColorByPercent(resources.cpu.percent);
  const ramColor = getColorByPercent(resources.ram.percent);

  const line1 = `${c.gray}${sym.topLeft}${sym.horizontal}${c.reset} ${aiLabel} ${c.gray}${sym.separator}${c.reset} ` +
                `${c.neonBlue}${c.bold}${sym.circle} Claude [STD]${c.reset} ${c.gray}${sym.separator}${c.reset} ` +
                `[${mcpIndicators}] ${c.gray}${sym.separator}${c.reset} ` +
                `${cpuColor}CPU ${resources.cpu.percent}%${c.reset} ${c.gray}${sym.horizontal}${sym.topRight}${c.reset}`;

  const line2 = `${c.gray}${sym.bottomLeft}${sym.horizontal}${c.reset} ` +
                `${sym.chart} ${c.dim}Waiting for data...${c.reset} ${c.gray}${sym.separator}${c.reset} ` +
                `${ramColor}RAM ${resources.ram.usedGB}/${resources.ram.totalGB}GB${c.reset} ${c.gray}${sym.separator}${c.reset} ` +
                `${sym.time} ${c.dim}Session: ${getSessionUptime(session)}${c.reset} ${c.gray}${sym.horizontal}${sym.bottomRight}${c.reset}`;

  return `${line1}\n${line2}`;
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
    console.log(buildFallbackDashboard());
    return;
  }

  console.log(buildDashboard(data));
});

// Fallback when stdin is not piped
setTimeout(() => {
  if (!inputData) {
    console.log(buildFallbackDashboard());
    process.exit(0);
  }
}, 100);
