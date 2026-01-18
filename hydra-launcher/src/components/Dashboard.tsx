import React, { useState, useCallback } from 'react';
import { useTheme } from '../contexts/ThemeContext';
import MCPStatus from './MCPStatus';
import SystemMetricsPanel from './SystemMetrics';
import LaunchPanel from './LaunchPanel';
import YoloToggle from './YoloToggle';
import OllamaStatus from './OllamaStatus';
import ChatInterface from './ChatInterface';
import StatusLine from './StatusLine';
import SettingsPanel from './SettingsPanel';
import { Moon, Sun, ChevronLeft, ChevronRight, Settings } from 'lucide-react';
import { useMCPHealth } from '../hooks/useMCPHealth';

const Dashboard: React.FC = () => {
  const { resolvedTheme, toggleTheme } = useTheme();
  const isLight = resolvedTheme === 'light';
  const logoSrc = isLight ? '/logolight.webp' : '/logodark.webp';
  const [sidebarOpen, setSidebarOpen] = useState(false);
  const [settingsOpen, setSettingsOpen] = useState(false);
  const [isConnected, setIsConnected] = useState(false);
  const [yoloEnabled] = useState(() => {
    try {
      return localStorage.getItem('hydra_yolo') !== 'false';
    } catch {
      return true;
    }
  });

  const { onlineCount, totalCount } = useMCPHealth();

  const handleConnectionChange = useCallback((connected: boolean) => {
    setIsConnected(connected);
  }, []);

  return (
    <div className="w-full h-full flex flex-col">
      {/* Settings Panel Modal */}
      <SettingsPanel isOpen={settingsOpen} onClose={() => setSettingsOpen(false)} />

      {/* Main content area */}
      <div className="flex-1 flex overflow-hidden">
        {/* Sidebar - collapsible */}
        <div
          className={`h-full transition-all duration-500 flex flex-col ${
            sidebarOpen ? 'w-80' : 'w-0'
          } overflow-hidden`}
        >
          <div className="w-80 h-full p-4 overflow-auto flex flex-col gap-4">
            {/* Decorative Runes Header */}
            <div className="text-center opacity-40">
              <span className="text-[10px] tracking-[0.5em] text-amber-600">
                ᚠ ᚢ ᚦ ᚨ ᚱ ᚲ ᚷ
              </span>
            </div>

            {/* MCP Servers Status */}
            <MCPStatus />

            {/* Ollama Status */}
            <OllamaStatus />

            {/* System Metrics */}
            <SystemMetricsPanel />

            {/* Launch Panel */}
            <LaunchPanel />

            {/* Footer Runes */}
            <div className="mt-auto text-center">
              <div className="codex-divider" />
              <p className={`text-[8px] tracking-[0.3em] mt-3 ${isLight ? 'text-amber-700/40' : 'text-amber-500/30'}`}>
                ⚔ SERENA ◆ DC ◆ PLAYWRIGHT ◆ SWARM ⚔
              </p>
            </div>
          </div>
        </div>

        {/* Main Content */}
        <div className="flex-1 flex flex-col h-full">
          {/* Header */}
          <div className={`flex items-center justify-between p-4 border-b ${
            isLight ? 'border-amber-300/30' : 'border-amber-500/20'
          }`}>
            {/* Sidebar Toggle + Logo */}
            <div className="flex items-center gap-4">
              <button
                onClick={() => setSidebarOpen(!sidebarOpen)}
                className="glass-button p-2"
                title={sidebarOpen ? 'Ukryj panel' : 'Pokaż panel'}
              >
                {sidebarOpen ? <ChevronLeft size={18} /> : <ChevronRight size={18} />}
              </button>

              {/* Logo - 2x bigger */}
              <img
                src={logoSrc}
                alt="HYDRA"
                className="h-40 w-auto object-contain hydra-logo"
              />

              <div className="flex flex-col">
                <span className="codex-title text-2xl">KODEKS HYDRY</span>
                <span className={`text-[10px] tracking-[0.3em] ${isLight ? 'text-amber-700/60' : 'text-amber-500/50'}`}>
                  ⚔ CZTEROGŁOWA BESTIA ⚔
                </span>
              </div>
            </div>

            {/* Right controls - przełączniki */}
            <div className="flex items-center gap-3">
              {/* Rune decoration */}
              <span className={`text-sm mr-2 ${isLight ? 'text-amber-600/30' : 'text-amber-500/20'}`}>
                ᛟ ᛞ ᛜ
              </span>

              {/* YOLO Toggle */}
              <YoloToggle />

              {/* Settings Button */}
              <button
                onClick={() => setSettingsOpen(true)}
                className="glass-button p-2.5"
                title="Ustawienia"
              >
                <Settings size={16} />
              </button>

              {/* Theme Toggle */}
              <button
                onClick={toggleTheme}
                className="glass-button p-2.5"
                title={isLight ? 'Tryb ciemny' : 'Tryb jasny'}
              >
                {isLight ? <Moon size={16} /> : <Sun size={16} />}
              </button>
            </div>
          </div>

          {/* Chat Area - Main Content with Witcher ornate frame */}
          <div className="flex-1 overflow-hidden relative">
            {/* Ornate frame corners */}
            <div className={`absolute inset-4 pointer-events-none z-10 ${
              isLight ? 'opacity-30' : 'opacity-20'
            }`}>
              {/* Top left corner */}
              <div className="absolute top-0 left-0 w-8 h-8 border-t-2 border-l-2 border-amber-500" />
              <span className="absolute -top-1 left-2 text-amber-500 text-lg">❧</span>

              {/* Top right corner */}
              <div className="absolute top-0 right-0 w-8 h-8 border-t-2 border-r-2 border-amber-500" />
              <span className="absolute -top-1 right-2 text-amber-500 text-lg transform rotate-90">❧</span>

              {/* Bottom left corner */}
              <div className="absolute bottom-0 left-0 w-8 h-8 border-b-2 border-l-2 border-amber-500" />
              <span className="absolute -bottom-1 left-2 text-amber-500 text-lg transform -rotate-90">❧</span>

              {/* Bottom right corner */}
              <div className="absolute bottom-0 right-0 w-8 h-8 border-b-2 border-r-2 border-amber-500" />
              <span className="absolute -bottom-1 right-2 text-amber-500 text-lg transform rotate-180">❧</span>
            </div>

            {/* Chat interface */}
            <div className="h-full m-2">
              <ChatInterface onConnectionChange={handleConnectionChange} />
            </div>
          </div>
        </div>
      </div>

      {/* StatusLine at bottom */}
      <StatusLine
        isConnected={isConnected}
        yoloEnabled={yoloEnabled}
        mcpOnline={onlineCount}
        mcpTotal={totalCount}
      />
    </div>
  );
};

export default Dashboard;
