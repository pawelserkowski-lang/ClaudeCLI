import { Cpu, Database, type LucideIcon, Shield, Terminal, Wifi, Zap } from 'lucide-react';
import React, { useEffect, useRef, useState } from 'react';
import { useTheme } from '../contexts/ThemeContext';

const Launcher: React.FC = () => {
  const { resolvedTheme } = useTheme();
  const isLight = resolvedTheme === 'light';
  const [progress, setProgress] = useState(0);
  const [statusText, setStatusText] = useState('INICJALIZACJA SYSTEMU HYDRA...');
  const startTimeRef = useRef<number>(0);

  // Logo based on theme
  const logoSrc = isLight ? '/logolight.webp' : '/logodark.webp';

  // Loading simulation
  useEffect(() => {
    startTimeRef.current = Date.now();

    const updateProgress = () => {
      const elapsed = Date.now() - startTimeRef.current;
      const newProgress = Math.min((elapsed / 2800) * 100, 100);
      setProgress(newProgress);
    };

    const intervalId = setInterval(updateProgress, 50);

    return () => {
      clearInterval(intervalId);
    };
  }, []);

  // Update status text based on progress
  useEffect(() => {
    const statuses = [
      { text: 'INICJALIZACJA SYSTEMU HYDRA...', threshold: 0 },
      { text: 'SPRAWDZANIE SERWERÓW MCP...', threshold: 15 },
      { text: 'ŁADOWANIE SERENA (PORT 9000)...', threshold: 25 },
      { text: 'ŁADOWANIE DESKTOP COMMANDER (PORT 8100)...', threshold: 40 },
      { text: 'ŁADOWANIE PLAYWRIGHT (PORT 5200)...', threshold: 55 },
      { text: 'WERYFIKACJA OLLAMA (PORT 11434)...', threshold: 70 },
      { text: 'KONFIGURACJA AI HANDLER...', threshold: 85 },
      { text: 'CZTERY GŁOWY GOTOWE', threshold: 98 },
    ];

    for (let i = statuses.length - 1; i >= 0; i--) {
      if (progress >= statuses[i].threshold) {
        setStatusText(statuses[i].text);
        break;
      }
    }
  }, [progress]);

  return (
    <div className="flex flex-col items-center justify-center w-full h-full relative overflow-hidden">
      {/* Content */}
      <div className="relative z-10 flex flex-col items-center w-full max-w-lg px-6 animate-fade-in">
        {/* Logo Image */}
        <div className="mb-8">
          <img
            src={logoSrc}
            alt="HYDRA"
            className={`w-48 h-auto object-contain transition-all duration-700 hover:scale-105 ${
              isLight
                ? 'drop-shadow-[0_0_40px_rgba(16,185,129,0.2)]'
                : 'drop-shadow-[0_0_60px_rgba(0,255,65,0.3)]'
            }`}
          />
        </div>

        {/* Subtitle */}
        <h1
          className={`text-xl font-semibold tracking-[0.25em] mb-2 ${
            isLight ? 'text-slate-600' : 'text-matrix-accent/90'
          }`}
          style={{
            textShadow: isLight ? 'none' : '0 0 30px rgba(0,255,65,0.2)',
          }}
        >
          FOUR-HEADED BEAST
        </h1>
        <p
          className={`text-[10px] tracking-[0.2em] mb-10 font-medium ${
            isLight ? 'text-slate-400' : 'text-slate-500'
          }`}
        >
          SERENA + DESKTOP COMMANDER + PLAYWRIGHT + SWARM
        </p>

        {/* Progress Section */}
        <div
          className={`w-full max-w-md space-y-5 p-8 rounded-3xl transition-all duration-500 ${
            isLight
              ? 'bg-white/85 backdrop-blur-sm shadow-lg shadow-black/5'
              : 'bg-black/70 backdrop-blur-sm shadow-[0_4px_30px_rgba(0,0,0,0.2),0_0_50px_rgba(255,255,255,0.04)]'
          }`}
        >
          {/* Status Text */}
          <div
            className={`flex justify-between items-center text-xs font-mono ${
              isLight ? 'text-slate-700' : 'text-matrix-accent'
            }`}
          >
            <span className="animate-pulse truncate mr-4">{statusText}</span>
            <span className="font-bold tabular-nums">{Math.floor(progress)}%</span>
          </div>

          {/* Progress Bar */}
          <div
            className={`h-2 rounded-full overflow-hidden relative ${
              isLight
                ? 'bg-emerald-100/80'
                : 'bg-black/40'
            }`}
          >
            <div
              className={`h-full rounded-full transition-all duration-500 ease-out relative ${
                isLight
                  ? 'bg-gradient-to-r from-emerald-400 to-emerald-500'
                  : 'bg-gradient-to-r from-emerald-500/80 to-matrix-accent/80'
              }`}
              style={{ width: `${progress}%` }}
            >
              {/* Shine effect */}
              <div className="absolute inset-0 bg-gradient-to-r from-transparent via-white/30 to-transparent animate-shimmer" />
            </div>
          </div>

          {/* System Check Icons */}
          <div className="flex justify-between pt-4 px-2">
            <SystemIcon icon={Shield} active={progress > 15} label="SERENA" isLight={isLight} />
            <SystemIcon icon={Terminal} active={progress > 35} label="DC" isLight={isLight} />
            <SystemIcon icon={Wifi} active={progress > 50} label="BROWSER" isLight={isLight} />
            <SystemIcon icon={Database} active={progress > 65} label="OLLAMA" isLight={isLight} />
            <SystemIcon icon={Cpu} active={progress > 80} label="AI" isLight={isLight} />
            <SystemIcon icon={Zap} active={progress > 95} label="READY" isLight={isLight} />
          </div>
        </div>
      </div>

      {/* Version Footer */}
      <div
        className={`absolute bottom-6 text-[9px] tracking-[0.3em] font-light ${
          isLight ? 'text-slate-400/80' : 'text-slate-600/60'
        }`}
      >
        HYDRA 10.4 LAUNCHER
      </div>
    </div>
  );
};

const SystemIcon: React.FC<{
  icon: LucideIcon;
  active: boolean;
  label: string;
  isLight?: boolean;
}> = ({ icon: Icon, active, label, isLight = false }) => (
  <div
    className={`flex flex-col items-center gap-2.5 transition-all duration-700 ${
      active
        ? 'opacity-100 transform translate-y-0 scale-100'
        : 'opacity-20 transform translate-y-1 scale-90'
    }`}
  >
    <div
      className={`p-2.5 rounded-xl transition-all duration-500 ${
        active
          ? isLight
            ? 'text-emerald-500 bg-emerald-50/60'
            : 'text-matrix-accent/90 bg-matrix-accent/5'
          : isLight
            ? 'text-slate-300'
            : 'text-slate-700'
      }`}
      style={
        active
          ? {
              filter: isLight
                ? 'drop-shadow(0 0 8px rgba(16,185,129,0.2))'
                : 'drop-shadow(0 0 12px rgba(0,255,65,0.2))',
            }
          : {}
      }
    >
      <Icon size={16} strokeWidth={active ? 2 : 1.5} />
    </div>
    <span
      className={`text-[7px] font-medium tracking-widest transition-all duration-500 ${
        active
          ? isLight
            ? 'text-emerald-500'
            : 'text-matrix-accent/80'
          : isLight
            ? 'text-slate-300'
            : 'text-slate-700'
      }`}
    >
      {label}
    </span>
  </div>
);

export default Launcher;
