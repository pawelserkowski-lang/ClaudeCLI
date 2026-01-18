import React, { useState, useEffect } from 'react';
import { Zap, Shield } from 'lucide-react';
import { useTheme } from '../contexts/ThemeContext';

const STORAGE_KEY = 'hydra_yolo';

const YoloToggle: React.FC = () => {
  const { resolvedTheme } = useTheme();
  const isLight = resolvedTheme === 'light';

  const [yoloEnabled, setYoloEnabled] = useState(() => {
    try {
      const stored = localStorage.getItem(STORAGE_KEY);
      return stored !== 'false'; // Default to true (YOLO ON)
    } catch {
      return true;
    }
  });

  useEffect(() => {
    try {
      localStorage.setItem(STORAGE_KEY, String(yoloEnabled));
    } catch {
      /* ignore */
    }
  }, [yoloEnabled]);

  const toggle = () => setYoloEnabled(!yoloEnabled);

  return (
    <button
      onClick={toggle}
      className={`
        flex items-center gap-2 px-3 py-2 rounded text-[10px] font-cinzel font-semibold tracking-wider uppercase
        transition-all duration-300 border-2 relative overflow-hidden
        ${
          yoloEnabled
            ? isLight
              ? 'bg-gradient-to-b from-amber-100 to-amber-200 text-amber-700 border-amber-500'
              : 'bg-gradient-to-b from-amber-900/30 to-amber-900/50 text-amber-400 border-amber-500'
            : isLight
              ? 'bg-gradient-to-b from-slate-100 to-slate-200 text-slate-500 border-slate-400'
              : 'bg-gradient-to-b from-slate-800/30 to-slate-800/50 text-slate-400 border-slate-600'
        }
      `}
      style={{}}
      title={yoloEnabled ? 'YOLO: Pełna autonomia bez potwierdzeń' : 'Tryb bezpieczny: Pytaj o uprawnienia'}
    >
      {/* Glow effect removed */}

      {yoloEnabled ? (
        <>
          <span className="text-sm">ᛉ</span>
          <Zap size={12} strokeWidth={2} />
          <span>YOLO</span>
        </>
      ) : (
        <>
          <span className="text-sm">ᛊ</span>
          <Shield size={12} strokeWidth={1.5} />
          <span>SAFE</span>
        </>
      )}

      {/* Toggle Indicator - Medieval Style */}
      <div
        className={`
          w-8 h-4 rounded-sm relative ml-2 transition-all duration-300 border
          ${
            yoloEnabled
              ? isLight
                ? 'bg-amber-200/60 border-amber-400/60'
                : 'bg-amber-800/40 border-amber-500/40'
              : isLight
                ? 'bg-slate-200/60 border-slate-400/60'
                : 'bg-slate-700/40 border-slate-600/40'
          }
        `}
      >
        <div
          className={`
            absolute top-0.5 w-3 h-3 rounded-sm transition-all duration-300
            ${yoloEnabled
              ? isLight
                ? 'left-4 bg-gradient-to-b from-amber-400 to-amber-500'
                : 'left-4 bg-gradient-to-b from-amber-400 to-amber-600'
              : isLight
                ? 'left-0.5 bg-gradient-to-b from-slate-300 to-slate-400'
                : 'left-0.5 bg-gradient-to-b from-slate-500 to-slate-600'
            }
          `}
          style={{}}
        />
      </div>
    </button>
  );
};

export default YoloToggle;
