import React from 'react';
import { Database, CheckCircle2, XCircle, RefreshCw, Cpu } from 'lucide-react';
import { useTheme } from '../contexts/ThemeContext';
import { useOllama } from '../hooks/useOllama';

const OllamaStatus: React.FC = () => {
  const { resolvedTheme } = useTheme();
  const isLight = resolvedTheme === 'light';
  const { isRunning, models, isLoading, refresh } = useOllama();

  return (
    <div className="glass-card p-5">
      {/* Codex Header */}
      <div className="flex items-center justify-between mb-4">
        <div className="flex items-center gap-3">
          <span className={`text-lg ${isLight ? 'text-amber-600' : 'text-amber-500'}`}>ᚷ</span>
          <Database className={isLight ? 'text-amber-700' : 'text-amber-500/80'} size={16} />
          <h2 className="codex-header !border-0 !pb-0 !mb-0">
            LOKALNA AI
          </h2>
        </div>
        <div className="flex items-center gap-3">
          {isRunning ? (
            <CheckCircle2 className="status-online" size={14} strokeWidth={1.5} />
          ) : (
            <XCircle className="status-offline" size={14} strokeWidth={1.5} />
          )}
          <span className={`text-[10px] font-cinzel font-semibold tracking-wider ${
            isRunning ? 'status-online' : 'status-offline'
          }`}>
            {isRunning ? 'AKTYWNA' : 'NIEAKTYWNA'}
          </span>
          <button
            onClick={refresh}
            className="glass-button p-1.5"
            title="Odśwież"
          >
            <RefreshCw size={12} className={isLoading ? 'animate-spin' : ''} />
          </button>
        </div>
      </div>

      {/* Decorative Divider */}
      <div className="h-px bg-gradient-to-r from-transparent via-amber-600/40 to-transparent mb-4" />

      {/* Port Info */}
      <div
        className={`p-3.5 rounded mb-4 border ${
          isLight
            ? 'bg-amber-50/40 border-amber-300/30'
            : 'bg-amber-900/10 border-amber-500/20'
        }`}
      >
        <div className="flex items-center justify-between">
          <span className={`text-[9px] font-cinzel tracking-wider ${isLight ? 'text-amber-600/60' : 'text-amber-500/50'}`}>
            PORT POŁĄCZENIA
          </span>
          <span className={`text-sm font-cinzel font-semibold ${isLight ? 'text-amber-700' : 'text-amber-400'}`}>
            11434
          </span>
        </div>
      </div>

      {/* Models List */}
      <div className="space-y-2.5">
        <div className={`flex items-center gap-2 text-[9px] font-cinzel font-semibold tracking-wider ${
          isLight ? 'text-amber-700/70' : 'text-amber-500/60'
        }`}>
          <span className="text-xs">ᚹ</span>
          MODELE ({models.length})
        </div>

        {models.length === 0 ? (
          <div
            className={`text-center py-5 text-[10px] font-cinzel italic ${
              isLight ? 'text-amber-600/50' : 'text-amber-500/40'
            }`}
          >
            {isRunning ? '◇ Brak zainstalowanych modeli ◇' : '◇ Ollama nie działa ◇'}
          </div>
        ) : (
          <div className="max-h-28 overflow-auto space-y-1.5">
            {models.map((model) => (
              <div
                key={model}
                className={`flex items-center gap-2.5 p-2.5 rounded text-[10px] font-cinzel font-medium border ${
                  isLight
                    ? 'bg-amber-50/60 text-amber-700 border-amber-300/30'
                    : 'bg-amber-900/15 text-amber-400/80 border-amber-500/20'
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
        className={`mt-4 p-3 rounded text-center border ${
          isLight
            ? 'bg-emerald-50/60 border-emerald-300/30'
            : 'bg-emerald-900/15 border-emerald-500/20'
        }`}
      >
        <span className={`text-[9px] font-cinzel font-semibold tracking-wider ${
          isLight ? 'text-emerald-600' : 'text-emerald-400/80'
        }`}>
          ✧ KOSZT: $0.00 ✧
        </span>
      </div>
    </div>
  );
};

export default OllamaStatus;
