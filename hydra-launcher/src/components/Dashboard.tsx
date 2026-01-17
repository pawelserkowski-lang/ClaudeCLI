import React from 'react';
import { useTheme } from '../contexts/ThemeContext';
import MCPStatus from './MCPStatus';
import SystemMetricsPanel from './SystemMetrics';
import LaunchPanel from './LaunchPanel';
import YoloToggle from './YoloToggle';
import OllamaStatus from './OllamaStatus';
import { Moon, Sun } from 'lucide-react';

const Dashboard: React.FC = () => {
  const { resolvedTheme, toggleTheme } = useTheme();
  const isLight = resolvedTheme === 'light';
  const logoSrc = isLight ? '/logolight.webp' : '/logodark.webp';

  return (
    <div
      className={`w-full h-full p-6 overflow-auto animate-fade-in ${
        isLight ? 'bg-transparent' : 'bg-transparent'
      }`}
    >
      {/* Decorative Runes Header */}
      <div className="text-center mb-2 opacity-40">
        <span className="text-[10px] tracking-[1em] text-amber-600">
          ᚠ ᚢ ᚦ ᚨ ᚱ ᚲ ᚷ ᚹ ᚺ ᚾ ᛁ ᛃ
        </span>
      </div>

      {/* Header */}
      <div className="flex items-center justify-between mb-6">
        {/* Logo */}
        <div className="flex items-center gap-4">
          <img
            src={logoSrc}
            alt="HYDRA"
            className="h-20 w-auto object-contain hydra-logo animate-float"
          />
          <div className="flex flex-col">
            <span className="codex-title text-lg">KODEKS</span>
            <span className={`text-[9px] tracking-[0.3em] ${isLight ? 'text-amber-700/60' : 'text-amber-500/50'}`}>
              FOUR-HEADED BEAST
            </span>
          </div>
        </div>

        <div className="flex items-center gap-3">
          {/* YOLO Toggle */}
          <YoloToggle />

          {/* Theme Toggle */}
          <button
            onClick={toggleTheme}
            className={`p-2.5 rounded glass-button transition-all duration-300`}
            title={isLight ? 'Dark mode' : 'Light mode'}
          >
            {isLight ? <Moon size={16} /> : <Sun size={16} />}
          </button>
        </div>
      </div>

      {/* Decorative Divider */}
      <div className="codex-divider mb-6" />

      {/* Main Grid */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-4 mb-4">
        {/* MCP Servers Status */}
        <MCPStatus />

        {/* Ollama Status */}
        <OllamaStatus />
      </div>

      {/* Bottom Section */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-4">
        {/* System Metrics */}
        <SystemMetricsPanel />

        {/* Launch Panel */}
        <div className="lg:col-span-2">
          <LaunchPanel />
        </div>
      </div>

      {/* Footer Runes */}
      <div className="mt-6 text-center">
        <div className="codex-divider" />
        <p className={`text-[8px] tracking-[0.4em] mt-4 ${isLight ? 'text-amber-700/40' : 'text-amber-500/30'}`}>
          ⚔ SERENA ◆ DESKTOP COMMANDER ◆ PLAYWRIGHT ◆ SWARM ⚔
        </p>
        <div className="mt-2 opacity-30">
          <span className="text-[8px] tracking-[0.8em] text-amber-600">
            ᛟ ᛞ ᛜ ᛗ ᛚ ᛖ ᛒ ᛏ ᛊ ᛉ ᛈ ᛇ
          </span>
        </div>
      </div>
    </div>
  );
};

export default Dashboard;
