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
        flex items-center gap-2 px-3 py-2 rounded-xl text-[10px] font-medium tracking-wider
        transition-all duration-300
        ${
          yoloEnabled
            ? isLight
              ? 'bg-amber-100/70 text-amber-600'
              : 'bg-amber-500/15 text-amber-400/80'
            : isLight
              ? 'bg-slate-100/70 text-slate-500'
              : 'bg-white/5 text-slate-500'
        }
      `}
      title={yoloEnabled ? 'YOLO: Skip all permission prompts' : 'Safe mode: Ask for permissions'}
    >
      {yoloEnabled ? (
        <>
          <Zap size={12} strokeWidth={1.5} />
          <span>YOLO</span>
        </>
      ) : (
        <>
          <Shield size={12} strokeWidth={1.5} />
          <span>SAFE</span>
        </>
      )}

      {/* Toggle Indicator */}
      <div
        className={`
          w-7 h-3.5 rounded-full relative ml-1.5 transition-all duration-300
          ${
            yoloEnabled
              ? isLight
                ? 'bg-amber-400/60'
                : 'bg-amber-500/40'
              : isLight
                ? 'bg-slate-300/60'
                : 'bg-slate-600/40'
          }
        `}
      >
        <div
          className={`
            absolute top-0.5 w-2.5 h-2.5 rounded-full transition-all duration-300 shadow-sm
            ${yoloEnabled
              ? isLight ? 'left-3.5 bg-amber-500' : 'left-3.5 bg-amber-400'
              : isLight ? 'left-0.5 bg-slate-400' : 'left-0.5 bg-slate-500'
            }
          `}
        />
      </div>
    </button>
  );
};

export default YoloToggle;
