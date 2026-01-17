import React from 'react';
import { Server, CheckCircle2, XCircle, Loader2, RefreshCw } from 'lucide-react';
import { useTheme } from '../contexts/ThemeContext';
import { useMCPHealth, type McpHealthResult } from '../hooks/useMCPHealth';

const MCPStatus: React.FC = () => {
  const { resolvedTheme } = useTheme();
  const isLight = resolvedTheme === 'light';
  const { health, isLoading, error, refresh, onlineCount, totalCount } = useMCPHealth();

  const getServerIcon = (name: string) => {
    switch (name.toLowerCase()) {
      case 'serena':
        return '🧠';
      case 'desktop commander':
        return '⚡';
      case 'playwright':
        return '🌐';
      default:
        return '📡';
    }
  };

  return (
    <div className={`glass-card p-5 ${isLight ? 'bg-white/50' : ''}`}>
      {/* Header */}
      <div className="flex items-center justify-between mb-5">
        <div className="flex items-center gap-2.5">
          <Server className={isLight ? 'text-slate-500' : 'text-matrix-accent/70'} size={16} />
          <h2 className={`font-medium tracking-wider text-sm ${isLight ? 'text-slate-700' : 'text-white/90'}`}>
            MCP SERVERS
          </h2>
        </div>
        <div className="flex items-center gap-3">
          <span
            className={`text-[10px] font-medium tracking-wide ${
              onlineCount === totalCount
                ? isLight ? 'text-emerald-500' : 'text-emerald-400/80'
                : isLight ? 'text-amber-500' : 'text-amber-400/80'
            }`}
          >
            {onlineCount}/{totalCount}
          </span>
          <button
            onClick={refresh}
            className={`p-1.5 rounded-lg transition-all duration-300 ${
              isLight
                ? 'hover:bg-slate-100/60 text-slate-400 hover:text-slate-600'
                : 'hover:bg-white/5 text-slate-500 hover:text-matrix-accent/70'
            }`}
            title="Odśwież status"
          >
            <RefreshCw size={12} className={isLoading ? 'animate-spin' : ''} />
          </button>
        </div>
      </div>

      {/* Error State */}
      {error && (
        <div className="text-red-400/80 text-[10px] mb-4 p-2.5 bg-red-500/5 rounded-xl border border-red-500/10">
          {error}
        </div>
      )}

      {/* Server List */}
      <div className="space-y-2.5">
        {isLoading && health.length === 0 ? (
          <div className="flex items-center justify-center py-6">
            <Loader2 className={`animate-spin ${isLight ? 'text-emerald-400' : 'text-matrix-accent/50'}`} size={20} />
          </div>
        ) : (
          health.map((server) => (
            <ServerRow key={server.name} server={server} icon={getServerIcon(server.name)} isLight={isLight} />
          ))
        )}
      </div>
    </div>
  );
};

const ServerRow: React.FC<{
  server: McpHealthResult;
  icon: string;
  isLight: boolean;
}> = ({ server, icon, isLight }) => {
  const isOnline = server.status === 'online';

  return (
    <div
      className={`flex items-center justify-between p-3.5 rounded-xl transition-all duration-300 ${
        isLight
          ? isOnline
            ? 'bg-emerald-50/60'
            : 'bg-red-50/60'
          : isOnline
            ? 'bg-matrix-accent/8'
            : 'bg-red-500/8'
      }`}
    >
      <div className="flex items-center gap-3">
        <span className="text-lg opacity-80">{icon}</span>
        <div>
          <div className={`font-medium text-sm ${isLight ? 'text-slate-700' : 'text-white/85'}`}>
            {server.name}
          </div>
          <div className={`text-[10px] font-light ${isLight ? 'text-slate-400' : 'text-slate-500'}`}>
            :{server.port}
          </div>
        </div>
      </div>

      <div className="flex items-center gap-3">
        {server.response_time_ms && (
          <span className={`text-[10px] font-light ${isLight ? 'text-slate-400' : 'text-slate-500'}`}>
            {server.response_time_ms}ms
          </span>
        )}
        {isOnline ? (
          <CheckCircle2
            className={isLight ? 'text-emerald-400' : 'text-emerald-400/70'}
            size={16}
            strokeWidth={1.5}
          />
        ) : (
          <XCircle
            className={isLight ? 'text-red-400' : 'text-red-400/70'}
            size={16}
            strokeWidth={1.5}
          />
        )}
      </div>
    </div>
  );
};

export default MCPStatus;
