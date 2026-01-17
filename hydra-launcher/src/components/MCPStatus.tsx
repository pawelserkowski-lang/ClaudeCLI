import React from 'react';
import { Server, CheckCircle2, XCircle, Loader2, RefreshCw } from 'lucide-react';
import { useTheme } from '../contexts/ThemeContext';
import { useMCPHealth, type McpHealthResult } from '../hooks/useMCPHealth';

const MCPStatus: React.FC = () => {
  const { resolvedTheme } = useTheme();
  const isLight = resolvedTheme === 'light';
  const { health, isLoading, error, refresh, onlineCount, totalCount } = useMCPHealth();

  const getServerRune = (name: string) => {
    switch (name.toLowerCase()) {
      case 'serena':
        return 'ᚨ';
      case 'desktop commander':
        return 'ᚱ';
      case 'playwright':
        return 'ᚲ';
      default:
        return 'ᚷ';
    }
  };

  return (
    <div className="glass-card p-5">
      {/* Codex Header */}
      <div className="flex items-center justify-between mb-4">
        <div className="flex items-center gap-3">
          <span className={`text-lg ${isLight ? 'text-amber-600' : 'text-amber-500'}`}>ᚠ</span>
          <Server className={isLight ? 'text-amber-700' : 'text-amber-500/80'} size={16} />
          <h2 className="codex-header !border-0 !pb-0 !mb-0">
            SERWERY MCP
          </h2>
        </div>
        <div className="flex items-center gap-3">
          <span
            className={`text-[10px] font-cinzel font-semibold tracking-wider ${
              onlineCount === totalCount
                ? 'status-online'
                : 'status-warning'
            }`}
          >
            {onlineCount}/{totalCount}
          </span>
          <button
            onClick={refresh}
            className="glass-button p-1.5"
            title="Odśwież status"
          >
            <RefreshCw size={12} className={isLoading ? 'animate-spin' : ''} />
          </button>
        </div>
      </div>

      {/* Decorative Divider */}
      <div className="h-px bg-gradient-to-r from-transparent via-amber-600/40 to-transparent mb-4" />

      {/* Error State */}
      {error && (
        <div className={`text-[10px] mb-4 p-3 rounded border font-cinzel ${
          isLight
            ? 'bg-red-100/60 text-red-700 border-red-300/50'
            : 'bg-red-900/20 text-red-400 border-red-500/30'
        }`}>
          ⚠ {error}
        </div>
      )}

      {/* Server List */}
      <div className="space-y-2.5">
        {isLoading && health.length === 0 ? (
          <div className="flex items-center justify-center py-6">
            <Loader2 className="animate-spin text-amber-500/50" size={20} />
          </div>
        ) : (
          health.map((server) => (
            <ServerRow key={server.name} server={server} rune={getServerRune(server.name)} isLight={isLight} />
          ))
        )}
      </div>
    </div>
  );
};

const ServerRow: React.FC<{
  server: McpHealthResult;
  rune: string;
  isLight: boolean;
}> = ({ server, rune, isLight }) => {
  const isOnline = server.status === 'online';

  return (
    <div
      className={`flex items-center justify-between p-3.5 rounded transition-all duration-300 border ${
        isLight
          ? isOnline
            ? 'bg-amber-50/60 border-amber-300/30'
            : 'bg-red-50/60 border-red-300/30'
          : isOnline
            ? 'bg-amber-900/15 border-amber-500/20'
            : 'bg-red-900/15 border-red-500/20'
      }`}
    >
      <div className="flex items-center gap-3">
        {/* Rune */}
        <span
          className={`text-xl transition-all duration-500 ${
            isOnline
              ? isLight ? 'text-amber-600' : 'text-amber-400'
              : 'text-slate-500'
          }`}
          style={isOnline ? { textShadow: '0 0 10px rgba(212,165,10,0.6)' } : {}}
        >
          {rune}
        </span>
        <div>
          <div className={`font-cinzel font-semibold text-sm tracking-wide ${
            isLight ? 'text-amber-800' : 'text-amber-100/90'
          }`}>
            {server.name}
          </div>
          <div className={`text-[10px] font-cinzel ${isLight ? 'text-amber-600/60' : 'text-amber-500/50'}`}>
            Port {server.port}
          </div>
        </div>
      </div>

      <div className="flex items-center gap-3">
        {server.response_time_ms && (
          <span className={`text-[10px] font-cinzel ${isLight ? 'text-amber-600/50' : 'text-amber-500/40'}`}>
            {server.response_time_ms}ms
          </span>
        )}
        {isOnline ? (
          <CheckCircle2
            className="status-online"
            size={16}
            strokeWidth={1.5}
          />
        ) : (
          <XCircle
            className="status-offline"
            size={16}
            strokeWidth={1.5}
          />
        )}
      </div>
    </div>
  );
};

export default MCPStatus;
