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
      className={`w-full h-full p-8 overflow-auto animate-fade-in ${
        isLight ? 'bg-transparent' : 'bg-transparent'
      }`}
    >
      {/* Header */}
      <div className="flex items-center justify-between mb-8">
        <div className="flex items-center gap-4">
          <img
            src={logoSrc}
            alt="HYDRA"
            className={`h-12 w-auto object-contain ${
              isLight
                ? 'drop-shadow-[0_0_20px_rgba(16,185,129,0.15)]'
                : 'drop-shadow-[0_0_30px_rgba(0,255,65,0.2)]'
            }`}
          />
          <p className={`text-[9px] tracking-[0.2em] font-medium ${isLight ? 'text-slate-400' : 'text-slate-500/70'}`}>
            FOUR-HEADED BEAST
          </p>
        </div>

        <div className="flex items-center gap-4">
          {/* YOLO Toggle */}
          <YoloToggle />

          {/* Theme Toggle */}
          <button
            onClick={toggleTheme}
            className={`p-2.5 rounded-xl transition-all duration-300 ${
              isLight
                ? 'bg-white/40 hover:bg-white/60 text-slate-500 hover:text-slate-700 shadow-sm'
                : 'bg-white/5 hover:bg-white/10 text-slate-400 hover:text-matrix-accent/80'
            }`}
            title={isLight ? 'Dark mode' : 'Light mode'}
          >
            {isLight ? <Moon size={16} /> : <Sun size={16} />}
          </button>
        </div>
      </div>

      {/* Main Grid */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-5 mb-5">
        {/* MCP Servers Status */}
        <MCPStatus />

        {/* Ollama Status */}
        <OllamaStatus />
      </div>

      {/* Bottom Section */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-5">
        {/* System Metrics */}
        <SystemMetricsPanel />

        {/* Launch Panel */}
        <div className="lg:col-span-2">
          <LaunchPanel />
        </div>
      </div>

      {/* Footer */}
      <div
        className={`mt-8 text-center text-[8px] tracking-[0.25em] font-light ${
          isLight ? 'text-slate-400/60' : 'text-slate-600/50'
        }`}
      >
        SERENA + DESKTOP COMMANDER + PLAYWRIGHT + SWARM
      </div>
    </div>
  );
};

export default Dashboard;
