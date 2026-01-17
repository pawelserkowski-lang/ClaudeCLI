import React from 'react';
import { Database, CheckCircle2, XCircle, RefreshCw, Cpu } from 'lucide-react';
import { useTheme } from '../contexts/ThemeContext';
import { useOllama } from '../hooks/useOllama';

const OllamaStatus: React.FC = () => {
  const { resolvedTheme } = useTheme();
  const isLight = resolvedTheme === 'light';
  const { isRunning, models, isLoading, refresh } = useOllama();

  return (
    <div className={`glass-card p-5 ${isLight ? 'bg-white/50' : ''}`}>
      {/* Header */}
      <div className="flex items-center justify-between mb-5">
        <div className="flex items-center gap-2.5">
          <Database className={isLight ? 'text-slate-500' : 'text-matrix-accent/70'} size={16} />
          <h2 className={`font-medium tracking-wider text-sm ${isLight ? 'text-slate-700' : 'text-white/90'}`}>
            LOCAL AI
          </h2>
        </div>
        <div className="flex items-center gap-3">
          {isRunning ? (
            <CheckCircle2 className={isLight ? 'text-emerald-400' : 'text-emerald-400/70'} size={14} strokeWidth={1.5} />
          ) : (
            <XCircle className={isLight ? 'text-red-400' : 'text-red-400/70'} size={14} strokeWidth={1.5} />
          )}
          <span className={`text-[10px] font-medium tracking-wide ${
            isRunning
              ? isLight ? 'text-emerald-500' : 'text-emerald-400/80'
              : isLight ? 'text-red-500' : 'text-red-400/80'
          }`}>
            {isRunning ? 'ONLINE' : 'OFFLINE'}
          </span>
          <button
            onClick={refresh}
            className={`p-1.5 rounded-lg transition-all duration-300 ${
              isLight
                ? 'hover:bg-slate-100/60 text-slate-400 hover:text-slate-600'
                : 'hover:bg-white/5 text-slate-500 hover:text-matrix-accent/70'
            }`}
            title="Refresh"
          >
            <RefreshCw size={12} className={isLoading ? 'animate-spin' : ''} />
          </button>
        </div>
      </div>

      {/* Port Info */}
      <div
        className={`p-3.5 rounded-xl mb-4 ${
          isLight ? 'bg-slate-100/60' : 'bg-white/5'
        }`}
      >
        <div className="flex items-center justify-between">
          <span className={`text-[9px] tracking-wide font-light ${isLight ? 'text-slate-400' : 'text-slate-500'}`}>
            Port
          </span>
          <span className={`text-sm font-medium ${isLight ? 'text-slate-600' : 'text-white/80'}`}>
            11434
          </span>
        </div>
      </div>

      {/* Models List */}
      <div className="space-y-2.5">
        <div className={`text-[9px] font-medium tracking-wider ${isLight ? 'text-slate-500' : 'text-slate-500'}`}>
          MODELS ({models.length})
        </div>

        {models.length === 0 ? (
          <div
            className={`text-center py-5 text-[10px] font-light ${isLight ? 'text-slate-400' : 'text-slate-600'}`}
          >
            {isRunning ? 'No models installed' : 'Ollama not running'}
          </div>
        ) : (
          <div className="max-h-28 overflow-auto space-y-1.5">
            {models.map((model) => (
              <div
                key={model}
                className={`flex items-center gap-2.5 p-2.5 rounded-lg text-[10px] font-medium ${
                  isLight
                    ? 'bg-emerald-50/60 text-emerald-600'
                    : 'bg-matrix-accent/8 text-matrix-accent/70'
                }`}
              >
                <Cpu size={10} strokeWidth={1.5} />
                {model}
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Cost Banner */}
      <div
        className={`mt-4 p-2.5 rounded-xl text-center ${
          isLight ? 'bg-emerald-50/60' : 'bg-matrix-accent/8'
        }`}
      >
        <span className={`text-[9px] font-medium tracking-wider ${isLight ? 'text-emerald-500' : 'text-matrix-accent/60'}`}>
          COST: $0.00
        </span>
      </div>
    </div>
  );
};

export default OllamaStatus;
