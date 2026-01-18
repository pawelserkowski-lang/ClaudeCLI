import React from 'react';
import { Cpu, HardDrive, Activity } from 'lucide-react';
import { useTheme } from '../contexts/ThemeContext';
import { useSystemMetrics } from '../hooks/useSystemMetrics';

const SystemMetricsPanel: React.FC = () => {
  const { resolvedTheme } = useTheme();
  const isLight = resolvedTheme === 'light';
  const { metrics, isLoading } = useSystemMetrics();

  return (
    <div className="glass-card p-5">
      {/* Codex Header */}
      <div className="flex items-center gap-3 mb-4">
        <span className={`text-lg ${isLight ? 'text-amber-600' : 'text-amber-500'}`}>ᛊ</span>
        <Activity className={isLight ? 'text-amber-700' : 'text-amber-500/80'} size={16} />
        <h2 className="codex-header !border-0 !pb-0 !mb-0">
          SYSTEM
        </h2>
      </div>

      {/* Decorative Divider */}
      <div className="h-px bg-gradient-to-r from-transparent via-amber-600/40 to-transparent mb-4" />

      {isLoading || !metrics ? (
        <div className="space-y-3">
          <div className={`h-16 rounded ${isLight ? 'bg-amber-100/40' : 'bg-amber-900/10'}`} />
          <div className={`h-16 rounded ${isLight ? 'bg-amber-100/40' : 'bg-amber-900/10'}`} />
        </div>
      ) : (
        <div className="space-y-3">
          {/* CPU */}
          <MetricBar
            icon={Cpu}
            label="MOC OBLICZENIOWA"
            rune="ᛏ"
            value={metrics.cpu_percent}
            suffix="%"
            isLight={isLight}
          />

          {/* Memory */}
          <MetricBar
            icon={HardDrive}
            label="PAMIĘĆ"
            rune="ᛗ"
            value={metrics.memory_percent}
            suffix={`% (${metrics.memory_used_gb.toFixed(1)}GB)`}
            isLight={isLight}
          />
        </div>
      )}
    </div>
  );
};

const MetricBar: React.FC<{
  icon: React.ComponentType<{ size?: number; className?: string; strokeWidth?: number }>;
  label: string;
  rune: string;
  value: number;
  suffix: string;
  isLight: boolean;
}> = ({ icon: Icon, label, rune, value, suffix, isLight }) => {
  const getBarColor = () => {
    if (value > 90) return 'bg-gradient-to-r from-red-600 to-red-400';
    if (value > 70) return 'bg-gradient-to-r from-amber-600 to-amber-400';
    return 'bg-gradient-to-r from-amber-700 to-amber-500';
  };

  
  return (
    <div
      className={`p-3.5 rounded transition-all duration-300 border ${
        isLight
          ? 'bg-amber-50/40 border-amber-300/30'
          : 'bg-amber-900/10 border-amber-500/20'
      }`}
    >
      <div className="flex items-center justify-between mb-2.5">
        <div className="flex items-center gap-2">
          <span
            className={`text-sm ${isLight ? 'text-amber-600' : 'text-amber-500'}`}
            style={{}}
          >
            {rune}
          </span>
          <Icon
            size={12}
            strokeWidth={1.5}
            className={isLight ? 'text-amber-600/70' : 'text-amber-500/60'}
          />
          <span className={`text-[9px] font-cinzel font-semibold tracking-wider ${
            isLight ? 'text-amber-700' : 'text-amber-400/80'
          }`}>
            {label}
          </span>
        </div>
        <span className={`text-[10px] font-cinzel font-semibold ${
          isLight ? 'text-amber-600' : 'text-amber-500/70'
        }`}>
          {value.toFixed(0)}{suffix}
        </span>
      </div>

      {/* Progress Bar - Medieval Style */}
      <div className={`h-2 rounded-sm overflow-hidden border ${
        isLight
          ? 'bg-amber-100/60 border-amber-300/30'
          : 'bg-black/30 border-amber-900/40'
      }`}>
        <div
          className={`h-full rounded-sm transition-all duration-700 relative ${getBarColor()}`}
          style={{
            width: `${Math.min(value, 100)}%`
          }}
        >
          {/* Shimmer removed */}
        </div>
      </div>
    </div>
  );
};

export default SystemMetricsPanel;
