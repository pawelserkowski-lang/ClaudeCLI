import React from 'react';
import { Cpu, HardDrive, Activity } from 'lucide-react';
import { useTheme } from '../contexts/ThemeContext';
import { useSystemMetrics } from '../hooks/useSystemMetrics';

const SystemMetricsPanel: React.FC = () => {
  const { resolvedTheme } = useTheme();
  const isLight = resolvedTheme === 'light';
  const { metrics, isLoading } = useSystemMetrics();

  return (
    <div className={`glass-card p-5 ${isLight ? 'bg-white/50' : ''}`}>
      {/* Header */}
      <div className="flex items-center gap-2.5 mb-5">
        <Activity className={isLight ? 'text-slate-500' : 'text-matrix-accent/70'} size={16} />
        <h2 className={`font-medium tracking-wider text-sm ${isLight ? 'text-slate-700' : 'text-white/90'}`}>
          SYSTEM
        </h2>
      </div>

      {isLoading || !metrics ? (
        <div className="animate-pulse space-y-3">
          <div className={`h-14 rounded-xl ${isLight ? 'bg-slate-100' : 'bg-white/3'}`} />
          <div className={`h-14 rounded-xl ${isLight ? 'bg-slate-100' : 'bg-white/3'}`} />
        </div>
      ) : (
        <div className="space-y-3">
          {/* CPU */}
          <MetricBar
            icon={Cpu}
            label="CPU"
            value={metrics.cpu_percent}
            suffix="%"
            isLight={isLight}
          />

          {/* Memory */}
          <MetricBar
            icon={HardDrive}
            label="RAM"
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
  value: number;
  suffix: string;
  isLight: boolean;
}> = ({ icon: Icon, label, value, suffix, isLight }) => {
  const getBarColor = () => {
    if (value > 90) return isLight ? 'bg-red-400' : 'bg-red-400/70';
    if (value > 70) return isLight ? 'bg-amber-400' : 'bg-amber-400/70';
    return isLight ? 'bg-emerald-400' : 'bg-emerald-400/50';
  };

  return (
    <div
      className={`p-3.5 rounded-xl transition-all duration-300 ${
        isLight ? 'bg-slate-100/60' : 'bg-white/5'
      }`}
    >
      <div className="flex items-center justify-between mb-2.5">
        <div className="flex items-center gap-2">
          <Icon
            size={12}
            strokeWidth={1.5}
            className={isLight ? 'text-slate-400' : 'text-slate-500'}
          />
          <span className={`text-[10px] font-medium tracking-wide ${isLight ? 'text-slate-600' : 'text-white/80'}`}>
            {label}
          </span>
        </div>
        <span className={`text-[10px] font-light ${isLight ? 'text-slate-400' : 'text-slate-500'}`}>
          {value.toFixed(0)}{suffix}
        </span>
      </div>

      {/* Progress Bar */}
      <div className={`h-1 rounded-full overflow-hidden ${isLight ? 'bg-slate-200/60' : 'bg-black/20'}`}>
        <div
          className={`h-full rounded-full transition-all duration-700 ${getBarColor()}`}
          style={{ width: `${Math.min(value, 100)}%` }}
        />
      </div>
    </div>
  );
};

export default SystemMetricsPanel;
