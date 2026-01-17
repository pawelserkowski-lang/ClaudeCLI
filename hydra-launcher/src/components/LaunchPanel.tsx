import React, { useState } from 'react';
import { Play, Loader2, Terminal, CheckCircle2, AlertCircle } from 'lucide-react';
import { invoke } from '@tauri-apps/api/core';
import { useTheme } from '../contexts/ThemeContext';
import { useMCPHealth } from '../hooks/useMCPHealth';
import { useOllama } from '../hooks/useOllama';

const LaunchPanel: React.FC = () => {
  const { resolvedTheme } = useTheme();
  const isLight = resolvedTheme === 'light';
  const [isLaunching, setIsLaunching] = useState(false);
  const [launchStatus, setLaunchStatus] = useState<'idle' | 'success' | 'error'>('idle');
  const [errorMessage, setErrorMessage] = useState<string>('');

  const { allOnline, onlineCount, totalCount } = useMCPHealth();
  const { isRunning: ollamaRunning } = useOllama();

  const handleLaunch = async () => {
    setIsLaunching(true);
    setLaunchStatus('idle');
    setErrorMessage('');

    try {
      // Get YOLO mode from localStorage
      const yoloEnabled = localStorage.getItem('hydra_yolo') !== 'false';

      await invoke('launch_claude', { yolo_mode: yoloEnabled });
      setLaunchStatus('success');

      // Close the launcher after successful launch
      setTimeout(() => {
        window.close();
      }, 1500);
    } catch (e) {
      setLaunchStatus('error');
      setErrorMessage(e instanceof Error ? e.message : String(e));
    } finally {
      setIsLaunching(false);
    }
  };

  const canLaunch = onlineCount > 0; // At least one MCP server should be online

  return (
    <div className={`glass-card p-5 ${isLight ? 'bg-white/50' : ''}`}>
      {/* Header */}
      <div className="flex items-center gap-2.5 mb-5">
        <Terminal className={isLight ? 'text-slate-500' : 'text-matrix-accent/70'} size={16} />
        <h2 className={`font-medium tracking-wider text-sm ${isLight ? 'text-slate-700' : 'text-white/90'}`}>
          LAUNCH CLAUDE
        </h2>
      </div>

      {/* Status Summary */}
      <div className="grid grid-cols-2 gap-3 mb-5">
        <StatusItem
          label="MCP"
          value={`${onlineCount}/${totalCount}`}
          status={allOnline ? 'success' : onlineCount > 0 ? 'warning' : 'error'}
          isLight={isLight}
        />
        <StatusItem
          label="Ollama"
          value={ollamaRunning ? 'Online' : 'Offline'}
          status={ollamaRunning ? 'success' : 'warning'}
          isLight={isLight}
        />
      </div>

      {/* Launch Button */}
      <button
        onClick={handleLaunch}
        disabled={isLaunching || !canLaunch}
        className={`
          w-full py-4 rounded-2xl font-medium text-sm tracking-wider
          transition-all duration-500 flex items-center justify-center gap-3
          ${
            isLight
              ? canLaunch
                ? 'bg-emerald-500/90 hover:bg-emerald-500 text-white shadow-lg shadow-emerald-500/20 hover:shadow-emerald-500/30'
                : 'bg-slate-200/60 text-slate-400 cursor-not-allowed'
              : canLaunch
                ? 'bg-matrix-accent/15 hover:bg-matrix-accent/20 text-matrix-accent/90'
                : 'bg-slate-800/30 text-slate-600 cursor-not-allowed'
          }
          ${isLaunching ? 'opacity-70 cursor-wait' : ''}
        `}
      >
        {isLaunching ? (
          <>
            <Loader2 className="animate-spin" size={18} />
            LAUNCHING...
          </>
        ) : launchStatus === 'success' ? (
          <>
            <CheckCircle2 size={18} />
            LAUNCHED
          </>
        ) : (
          <>
            <Play size={18} />
            START HYDRA
          </>
        )}
      </button>

      {/* Error Message */}
      {launchStatus === 'error' && errorMessage && (
        <div className="mt-4 p-3 rounded-xl bg-red-500/10 flex items-start gap-2.5">
          <AlertCircle className="text-red-400/70 shrink-0 mt-0.5" size={14} />
          <p className="text-[10px] text-red-400/80 font-light">{errorMessage}</p>
        </div>
      )}

      {/* Help Text */}
      <p className={`text-[9px] text-center mt-4 font-light ${isLight ? 'text-slate-400' : 'text-slate-600'}`}>
        {canLaunch
          ? 'Launch Claude CLI with HYDRA configuration'
          : 'Start at least one MCP server first'}
      </p>
    </div>
  );
};

const StatusItem: React.FC<{
  label: string;
  value: string;
  status: 'success' | 'warning' | 'error';
  isLight: boolean;
}> = ({ label, value, status, isLight }) => {
  const statusColors = {
    success: isLight ? 'text-emerald-500' : 'text-emerald-400/80',
    warning: isLight ? 'text-amber-500' : 'text-amber-400/80',
    error: isLight ? 'text-red-500' : 'text-red-400/80',
  };

  return (
    <div
      className={`p-3.5 rounded-xl transition-all duration-300 ${
        isLight ? 'bg-slate-100/60' : 'bg-white/5'
      }`}
    >
      <div className={`text-[9px] tracking-wide font-light ${isLight ? 'text-slate-400' : 'text-slate-500'}`}>
        {label}
      </div>
      <div className={`text-sm font-medium mt-1 ${statusColors[status]}`}>
        {value}
      </div>
    </div>
  );
};

export default LaunchPanel;
