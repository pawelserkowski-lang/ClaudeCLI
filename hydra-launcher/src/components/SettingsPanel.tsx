import React, { useState, useEffect } from 'react';
import { Settings, Zap, Shield, Volume2, VolumeX, Bell, BellOff, Eye, EyeOff, Sparkles, X } from 'lucide-react';
import { useTheme } from '../contexts/ThemeContext';

interface SettingItem {
  id: string;
  label: string;
  description: string;
  iconOn: React.ElementType;
  iconOff: React.ElementType;
  defaultValue: boolean;
  rune: string;
}

const SETTINGS: SettingItem[] = [
  {
    id: 'yolo_mode',
    label: 'YOLO Mode',
    description: 'Pełna autonomia bez potwierdzeń',
    iconOn: Zap,
    iconOff: Shield,
    defaultValue: true,
    rune: 'ᛉ',
  },
  {
    id: 'sound_effects',
    label: 'Dźwięki',
    description: 'Efekty dźwiękowe interfejsu',
    iconOn: Volume2,
    iconOff: VolumeX,
    defaultValue: true,
    rune: 'ᚹ',
  },
  {
    id: 'notifications',
    label: 'Powiadomienia',
    description: 'Powiadomienia systemowe',
    iconOn: Bell,
    iconOff: BellOff,
    defaultValue: true,
    rune: 'ᚾ',
  },
  {
    id: 'animations',
    label: 'Animacje',
    description: 'Efekty wizualne i animacje',
    iconOn: Sparkles,
    iconOff: Eye,
    defaultValue: true,
    rune: 'ᛊ',
  },
  {
    id: 'auto_scroll',
    label: 'Auto-scroll',
    description: 'Automatyczne przewijanie chatu',
    iconOn: Eye,
    iconOff: EyeOff,
    defaultValue: true,
    rune: 'ᛏ',
  },
];

interface SettingsPanelProps {
  isOpen: boolean;
  onClose: () => void;
}

const SettingsPanel: React.FC<SettingsPanelProps> = ({ isOpen, onClose }) => {
  const { resolvedTheme } = useTheme();
  const isLight = resolvedTheme === 'light';
  const [settings, setSettings] = useState<Record<string, boolean>>({});

  // Load settings from localStorage
  useEffect(() => {
    const loaded: Record<string, boolean> = {};
    SETTINGS.forEach(setting => {
      const stored = localStorage.getItem(`hydra_${setting.id}`);
      loaded[setting.id] = stored !== null ? stored === 'true' : setting.defaultValue;
    });
    setSettings(loaded);
  }, []);

  const toggleSetting = (id: string) => {
    const newValue = !settings[id];
    setSettings(prev => ({ ...prev, [id]: newValue }));
    localStorage.setItem(`hydra_${id}`, String(newValue));

    // Special handling for yolo_mode (legacy key)
    if (id === 'yolo_mode') {
      localStorage.setItem('hydra_yolo', String(newValue));
    }
  };

  if (!isOpen) return null;

  return (
    <div
      className="fixed inset-0 z-40 flex items-center justify-center"
      onClick={onClose}
    >
      {/* Backdrop */}
      <div className={`absolute inset-0 ${
        isLight ? 'bg-white/60' : 'bg-black/70'
      } backdrop-blur-sm`} />

      {/* Panel */}
      <div
        className={`relative w-full max-w-md mx-4 rounded-lg border-2 overflow-hidden ${
          isLight
            ? 'bg-gradient-to-b from-amber-50 to-white border-amber-400/50'
            : 'bg-gradient-to-b from-amber-950/90 to-black/95 border-amber-500/40'
        }`}
        onClick={e => e.stopPropagation()}
        style={{
          boxShadow: isLight
            ? '0 20px 60px rgba(245, 158, 11, 0.2)'
            : '0 20px 60px rgba(0, 0, 0, 0.5), 0 0 40px rgba(251, 191, 36, 0.1)',
        }}
      >
        {/* Header */}
        <div className={`flex items-center justify-between p-4 border-b ${
          isLight ? 'border-amber-300/30' : 'border-amber-500/20'
        }`}>
          <div className="flex items-center gap-3">
            <Settings className={isLight ? 'text-amber-600' : 'text-amber-500'} size={20} />
            <h2 className="font-cinzel-decorative text-lg tracking-wider text-amber-500">
              USTAWIENIA
            </h2>
          </div>
          <button
            onClick={onClose}
            className={`p-2 rounded transition-colors ${
              isLight
                ? 'hover:bg-amber-100 text-amber-600'
                : 'hover:bg-amber-900/30 text-amber-500'
            }`}
          >
            <X size={18} />
          </button>
        </div>

        {/* Decorative runes */}
        <div className={`text-center py-2 text-[10px] tracking-[0.5em] ${
          isLight ? 'text-amber-600/30' : 'text-amber-500/20'
        }`}>
          ᚠ ᚢ ᚦ ᚨ ᚱ ᚲ
        </div>

        {/* Settings list */}
        <div className="p-4 space-y-3">
          {SETTINGS.map(setting => {
            const isEnabled = settings[setting.id] ?? setting.defaultValue;
            const Icon = isEnabled ? setting.iconOn : setting.iconOff;

            return (
              <div
                key={setting.id}
                className={`flex items-center justify-between p-3 rounded-lg border transition-all duration-300 cursor-pointer ${
                  isEnabled
                    ? isLight
                      ? 'bg-amber-100/60 border-amber-400/40 hover:border-amber-500/60'
                      : 'bg-amber-900/20 border-amber-500/30 hover:border-amber-400/50'
                    : isLight
                      ? 'bg-slate-100/60 border-slate-300/40 hover:border-slate-400/60'
                      : 'bg-slate-800/20 border-slate-600/30 hover:border-slate-500/50'
                }`}
                onClick={() => toggleSetting(setting.id)}
              >
                <div className="flex items-center gap-3">
                  {/* Rune */}
                  <span className={`text-lg ${
                    isEnabled
                      ? isLight ? 'text-amber-600' : 'text-amber-500'
                      : isLight ? 'text-slate-400' : 'text-slate-600'
                  }`}>
                    {setting.rune}
                  </span>

                  {/* Icon */}
                  <Icon
                    size={18}
                    className={
                      isEnabled
                        ? isLight ? 'text-amber-600' : 'text-amber-500'
                        : isLight ? 'text-slate-400' : 'text-slate-500'
                    }
                  />

                  {/* Labels */}
                  <div>
                    <div className={`text-sm font-cinzel font-semibold tracking-wider ${
                      isEnabled
                        ? isLight ? 'text-amber-700' : 'text-amber-400'
                        : isLight ? 'text-slate-500' : 'text-slate-400'
                    }`}>
                      {setting.label}
                    </div>
                    <div className={`text-[9px] font-cinzel ${
                      isLight ? 'text-amber-600/60' : 'text-amber-500/50'
                    }`}>
                      {setting.description}
                    </div>
                  </div>
                </div>

                {/* Toggle switch */}
                <div className={`w-12 h-6 rounded-md relative transition-all duration-300 border ${
                  isEnabled
                    ? isLight
                      ? 'bg-amber-200/60 border-amber-400/60'
                      : 'bg-amber-800/40 border-amber-500/40'
                    : isLight
                      ? 'bg-slate-200/60 border-slate-400/60'
                      : 'bg-slate-700/40 border-slate-600/40'
                }`}>
                  <div className={`absolute top-1 w-4 h-4 rounded transition-all duration-300 ${
                    isEnabled
                      ? isLight
                        ? 'left-7 bg-gradient-to-b from-amber-400 to-amber-500'
                        : 'left-7 bg-gradient-to-b from-amber-400 to-amber-600'
                      : isLight
                        ? 'left-1 bg-gradient-to-b from-slate-300 to-slate-400'
                        : 'left-1 bg-gradient-to-b from-slate-500 to-slate-600'
                  }`} />
                </div>
              </div>
            );
          })}
        </div>

        {/* Footer */}
        <div className={`p-4 border-t text-center ${
          isLight ? 'border-amber-300/30' : 'border-amber-500/20'
        }`}>
          <span className={`text-[9px] font-cinzel tracking-wider ${
            isLight ? 'text-amber-600/50' : 'text-amber-500/40'
          }`}>
            ◇ HYDRA 10.5 ◇ WITCHER CODEX ◇
          </span>
        </div>
      </div>
    </div>
  );
};

export default SettingsPanel;
