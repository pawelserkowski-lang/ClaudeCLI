import { Cpu, Database, type LucideIcon, Shield, Terminal, Wifi, Zap } from 'lucide-react';
import React, { useEffect, useRef, useState } from 'react';
import { useTheme } from '../contexts/ThemeContext';

const Launcher: React.FC = () => {
  const { resolvedTheme } = useTheme();
  const isLight = resolvedTheme === 'light';
  const [progress, setProgress] = useState(0);
  const [statusText, setStatusText] = useState('OTWIERANIE KODEKSU...');
  const startTimeRef = useRef<number>(0);

  // Logo based on theme
  const logoSrc = isLight ? '/logolight.webp' : '/logodark.webp';

  // Loading simulation
  useEffect(() => {
    startTimeRef.current = Date.now();

    const updateProgress = () => {
      const elapsed = Date.now() - startTimeRef.current;
      const newProgress = Math.min((elapsed / 3200) * 100, 100);
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
      { text: 'OTWIERANIE KODEKSU...', threshold: 0 },
      { text: 'PRZYWOŁYWANIE SERENY...', threshold: 15 },
      { text: 'BUDZENIE DESKTOP COMMANDERA...', threshold: 30 },
      { text: 'AKTYWACJA PLAYWRIGHT...', threshold: 45 },
      { text: 'SPRAWDZANIE OLLAMA...', threshold: 60 },
      { text: 'ŁADOWANIE AGENT SWARM...', threshold: 75 },
      { text: 'KONFIGURACJA AI HANDLER...', threshold: 88 },
      { text: '⚔ KODEKS GOTOWY ⚔', threshold: 98 },
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

        {/* Decorative Runes Top */}
        <div className="mb-6 text-center animate-glow-pulse">
          <span className="text-xs tracking-[0.5em] text-amber-500/60">
            ᚠ ᚢ ᚦ ᚨ ᚱ ᚲ ᚷ
          </span>
        </div>

        {/* Logo Image */}
        <div className="mb-6 relative">
          <img
            src={logoSrc}
            alt="HYDRA"
            className={`w-72 h-auto object-contain transition-all duration-700 hydra-logo ${
              progress > 95 ? 'animate-pulse-gold' : ''
            }`}
          />
          {/* Glow ring */}
          <div
            className="absolute inset-0 rounded-full opacity-30 animate-pulse-gold"
            style={{
              background: 'radial-gradient(circle, rgba(212,165,10,0.3) 0%, transparent 70%)',
              transform: 'scale(1.5)',
            }}
          />
        </div>

        {/* Title */}
        <h1 className="codex-title text-2xl mb-2 animate-glow-pulse">
          KODEKS HYDRY
        </h1>

        {/* Subtitle */}
        <p className={`text-[10px] tracking-[0.3em] mb-8 ${isLight ? 'text-amber-700/60' : 'text-amber-500/50'}`}>
          ⚔ CZTEROGŁOWA BESTIA ⚔
        </p>

        {/* Progress Section - Codex Style */}
        <div
          className={`w-full max-w-md glass-card p-6 animate-border-glow`}
        >
          {/* Status Text */}
          <div className="flex justify-between items-center mb-4">
            <span className={`text-xs font-cinzel tracking-wider ${isLight ? 'text-amber-800' : 'text-amber-400'}`}>
              {statusText}
            </span>
            <span className={`text-sm font-bold font-cinzel ${isLight ? 'text-amber-700' : 'text-amber-500'}`}>
              {Math.floor(progress)}%
            </span>
          </div>

          {/* Progress Bar - Medieval Style */}
          <div className="relative h-3 rounded-sm overflow-hidden bg-black/40 border border-amber-900/50">
            {/* Track texture */}
            <div className="absolute inset-0 opacity-20"
              style={{
                backgroundImage: 'repeating-linear-gradient(90deg, transparent, transparent 2px, rgba(212,165,10,0.1) 2px, rgba(212,165,10,0.1) 4px)'
              }}
            />

            {/* Progress fill */}
            <div
              className="h-full rounded-sm transition-all duration-300 relative overflow-hidden"
              style={{
                width: `${progress}%`,
                background: 'linear-gradient(90deg, #8b6914 0%, #d4a50a 50%, #ffd700 100%)',
              }}
            >
              {/* Shimmer effect */}
              <div
                className="absolute inset-0 animate-shimmer"
                style={{
                  background: 'linear-gradient(90deg, transparent, rgba(255,255,255,0.4), transparent)',
                }}
              />
            </div>
          </div>

          {/* Decorative line */}
          <div className="codex-divider mt-4 mb-4" />

          {/* System Check Icons - Witcher Signs Style */}
          <div className="flex justify-between px-2">
            <WitcherSign icon={Shield} active={progress > 15} label="SERENA" isLight={isLight} sign="ᚨ" />
            <WitcherSign icon={Terminal} active={progress > 30} label="DC" isLight={isLight} sign="ᚱ" />
            <WitcherSign icon={Wifi} active={progress > 45} label="PLAY" isLight={isLight} sign="ᚲ" />
            <WitcherSign icon={Database} active={progress > 60} label="OLLAMA" isLight={isLight} sign="ᚷ" />
            <WitcherSign icon={Cpu} active={progress > 75} label="SWARM" isLight={isLight} sign="ᚹ" />
            <WitcherSign icon={Zap} active={progress > 95} label="GOTOWY" isLight={isLight} sign="ᛉ" />
          </div>
        </div>

        {/* Bottom Runes */}
        <div className="mt-8 text-center animate-glow-pulse">
          <span className="text-xs tracking-[0.5em] text-amber-500/40">
            ᛟ ᛞ ᛜ ᛗ ᛚ ᛖ ᛒ
          </span>
        </div>
      </div>

      {/* Version Footer */}
      <div
        className={`absolute bottom-4 text-[9px] tracking-[0.4em] font-cinzel ${
          isLight ? 'text-amber-700/50' : 'text-amber-500/40'
        }`}
      >
        ◆ HYDRA 10.4 ◆
      </div>
    </div>
  );
};

const WitcherSign: React.FC<{
  icon: LucideIcon;
  active: boolean;
  label: string;
  isLight?: boolean;
  sign: string;
}> = ({ icon: Icon, active, label, isLight = false, sign }) => (
  <div
    className={`flex flex-col items-center gap-2 transition-all duration-500 ${
      active
        ? 'opacity-100 transform translate-y-0 scale-100'
        : 'opacity-25 transform translate-y-1 scale-90'
    }`}
  >
    {/* Rune */}
    <span
      className={`text-lg transition-all duration-500 ${
        active
          ? isLight ? 'text-amber-600' : 'text-amber-400'
          : 'text-slate-600'
      }`}
      style={active ? { textShadow: '0 0 10px rgba(212,165,10,0.8)' } : {}}
    >
      {sign}
    </span>

    {/* Icon */}
    <div
      className={`p-2 rounded transition-all duration-500 ${
        active
          ? isLight
            ? 'text-amber-600 bg-amber-100/50'
            : 'text-amber-400 bg-amber-500/10'
          : isLight
            ? 'text-slate-400'
            : 'text-slate-600'
      }`}
      style={
        active
          ? {
              boxShadow: isLight
                ? '0 0 15px rgba(180,130,10,0.3)'
                : '0 0 15px rgba(212,165,10,0.4)',
            }
          : {}
      }
    >
      <Icon size={14} strokeWidth={active ? 2 : 1.5} />
    </div>

    {/* Label */}
    <span
      className={`text-[7px] font-cinzel font-semibold tracking-wider transition-all duration-500 ${
        active
          ? isLight
            ? 'text-amber-600'
            : 'text-amber-400/80'
          : isLight
            ? 'text-slate-400'
            : 'text-slate-600'
      }`}
    >
      {label}
    </span>
  </div>
);

export default Launcher;
