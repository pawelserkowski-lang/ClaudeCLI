import React, { useState, useEffect, useRef } from 'react';
import { Loader2, Clock, CheckCircle2 } from 'lucide-react';
import { useTheme } from '../contexts/ThemeContext';

interface ProgressBarProps {
  isActive: boolean;
  onComplete?: () => void;
  estimatedDurationMs?: number;
}

const ProgressBar: React.FC<ProgressBarProps> = ({
  isActive,
  onComplete,
  estimatedDurationMs = 15000,
}) => {
  const { resolvedTheme } = useTheme();
  const isLight = resolvedTheme === 'light';
  const [progress, setProgress] = useState(0);
  const [eta, setEta] = useState('');
  const [phase, setPhase] = useState<'idle' | 'processing' | 'complete'>('idle');
  const startTimeRef = useRef<number>(0);
  const intervalRef = useRef<ReturnType<typeof setInterval> | null>(null);

  useEffect(() => {
    if (isActive && phase === 'idle') {
      setPhase('processing');
      setProgress(0);
      startTimeRef.current = Date.now();

      intervalRef.current = setInterval(() => {
        const elapsed = Date.now() - startTimeRef.current;
        const newProgress = Math.min((elapsed / estimatedDurationMs) * 100, 99);
        setProgress(newProgress);

        // Calculate ETA
        const remaining = Math.max(0, estimatedDurationMs - elapsed);
        if (remaining > 60000) {
          setEta(`~${Math.ceil(remaining / 60000)}m`);
        } else if (remaining > 1000) {
          setEta(`~${Math.ceil(remaining / 1000)}s`);
        } else {
          setEta('<1s');
        }
      }, 100);
    } else if (!isActive && phase === 'processing') {
      // Complete animation
      if (intervalRef.current) {
        clearInterval(intervalRef.current);
      }
      setProgress(100);
      setPhase('complete');
      setEta('');

      setTimeout(() => {
        onComplete?.();
        setPhase('idle');
        setProgress(0);
      }, 500);
    }

    return () => {
      if (intervalRef.current) {
        clearInterval(intervalRef.current);
      }
    };
  }, [isActive, phase, estimatedDurationMs, onComplete]);

  if (phase === 'idle') return null;

  const progressColor = isLight
    ? 'from-amber-400 via-amber-500 to-amber-600'
    : 'from-amber-500 via-amber-400 to-amber-300';

  const glowColor = isLight
    ? 'rgba(245, 158, 11, 0.5)'
    : 'rgba(251, 191, 36, 0.6)';

  return (
    <div className={`w-full p-4 rounded-lg border-2 backdrop-blur-sm transition-all duration-500 ${
      isLight
        ? 'bg-amber-50/80 border-amber-400/50'
        : 'bg-black/60 border-amber-500/40'
    }`}>
      {/* Header with status */}
      <div className="flex items-center justify-between mb-3">
        <div className="flex items-center gap-2">
          {phase === 'complete' ? (
            <CheckCircle2 className="text-emerald-500" size={16} />
          ) : (
            <Loader2 className={`animate-spin ${isLight ? 'text-amber-600' : 'text-amber-400'}`} size={16} />
          )}
          <span className={`text-xs font-cinzel font-semibold tracking-wider ${
            isLight ? 'text-amber-700' : 'text-amber-400'
          }`}>
            {phase === 'complete' ? 'UKOŃCZONO' : 'PRZETWARZANIE...'}
          </span>
        </div>

        {/* ETA and percentage */}
        <div className="flex items-center gap-3">
          {eta && (
            <div className="flex items-center gap-1">
              <Clock size={12} className={isLight ? 'text-amber-600/60' : 'text-amber-500/50'} />
              <span className={`text-[10px] font-cinzel ${isLight ? 'text-amber-600/80' : 'text-amber-500/70'}`}>
                ETA: {eta}
              </span>
            </div>
          )}
          <span className={`text-sm font-cinzel font-bold ${
            phase === 'complete'
              ? 'text-emerald-500'
              : isLight ? 'text-amber-700' : 'text-amber-400'
          }`}>
            {Math.round(progress)}%
          </span>
        </div>
      </div>

      {/* Progress bar track */}
      <div className={`relative h-6 rounded overflow-hidden ${
        isLight ? 'bg-amber-200/50' : 'bg-amber-900/30'
      }`}>
        {/* Animated background pattern */}
        <div
          className="absolute inset-0 opacity-20"
          style={{
            backgroundImage: `repeating-linear-gradient(
              45deg,
              transparent,
              transparent 10px,
              rgba(251, 191, 36, 0.1) 10px,
              rgba(251, 191, 36, 0.1) 20px
            )`,
            animation: 'slide 1s linear infinite',
          }}
        />

        {/* Progress fill */}
        <div
          className={`absolute h-full bg-gradient-to-r ${progressColor} transition-all duration-200 ease-out`}
          style={{
            width: `${progress}%`,
            boxShadow: `0 0 20px ${glowColor}, inset 0 1px 0 rgba(255,255,255,0.3)`,
          }}
        >
          {/* Shimmer effect */}
          <div
            className="absolute inset-0 opacity-30"
            style={{
              background: 'linear-gradient(90deg, transparent, rgba(255,255,255,0.4), transparent)',
              animation: 'shimmer 1.5s ease-in-out infinite',
            }}
          />

          {/* Leading edge glow */}
          <div
            className="absolute right-0 top-0 bottom-0 w-4"
            style={{
              background: `linear-gradient(90deg, transparent, ${glowColor})`,
            }}
          />
        </div>

        {/* Witcher runes overlay */}
        <div className="absolute inset-0 flex items-center justify-center">
          <span className={`text-[10px] tracking-[1em] font-cinzel ${
            isLight ? 'text-amber-800/30' : 'text-amber-300/20'
          }`}>
            ᚠ ᚢ ᚦ ᚨ ᚱ ᚲ ᚷ ᚹ ᚺ ᚾ
          </span>
        </div>

        {/* Percentage text inside bar */}
        <div className="absolute inset-0 flex items-center justify-center">
          <span className={`text-xs font-cinzel font-bold drop-shadow-lg ${
            progress > 50 ? 'text-white' : isLight ? 'text-amber-800' : 'text-amber-300'
          }`}>
            {Math.round(progress)}%
          </span>
        </div>
      </div>

      {/* Phase indicator dots */}
      <div className="flex items-center justify-center gap-2 mt-3">
        {['Inicjalizacja', 'Analiza', 'Generowanie', 'Weryfikacja'].map((step, i) => {
          const stepProgress = (i + 1) * 25;
          const isCompleted = progress >= stepProgress;
          const isActive = progress >= stepProgress - 25 && progress < stepProgress;

          return (
            <div key={step} className="flex items-center gap-1">
              <div
                className={`w-2 h-2 rounded-full transition-all duration-300 ${
                  isCompleted
                    ? 'bg-emerald-500'
                    : isActive
                      ? 'bg-amber-400 animate-pulse'
                      : isLight ? 'bg-amber-300/40' : 'bg-amber-700/40'
                }`}
                style={{
                  boxShadow: isCompleted
                    ? '0 0 6px rgba(16, 185, 129, 0.6)'
                    : isActive
                      ? `0 0 6px ${glowColor}`
                      : 'none'
                }}
              />
              <span className={`text-[8px] font-cinzel ${
                isCompleted || isActive
                  ? isLight ? 'text-amber-700' : 'text-amber-400'
                  : isLight ? 'text-amber-500/50' : 'text-amber-600/50'
              }`}>
                {step}
              </span>
            </div>
          );
        })}
      </div>
    </div>
  );
};

export default ProgressBar;
