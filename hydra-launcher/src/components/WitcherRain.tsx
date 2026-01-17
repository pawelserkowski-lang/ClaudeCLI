import React, { useEffect, useRef } from 'react';
import { useTheme } from '../contexts/ThemeContext';

interface WitcherRainProps {
  fontSize?: number;
  speed?: number;
}

const WitcherRain: React.FC<WitcherRainProps> = ({ fontSize = 18, speed = 45 }) => {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const containerRef = useRef<HTMLDivElement>(null);
  const { resolvedTheme } = useTheme();

  const isLight = resolvedTheme === 'light';
  const bgColor = isLight ? '#fafafa' : '#0a0a0a';
  const fadeColor = isLight ? 'rgba(250, 250, 250, 0.04)' : 'rgba(10, 10, 10, 0.04)';

  useEffect(() => {
    const canvas = canvasRef.current;
    const container = containerRef.current;
    if (!canvas || !container) return;

    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    // Elder Futhark Runes + Witcher Signs
    const elderFuthark = 'ᚠᚢᚦᚨᚱᚲᚷᚹᚺᚾᛁᛃᛇᛈᛉᛊᛏᛒᛖᛗᛚᛜᛞᛟ';
    const youngerFuthark = 'ᚠᚢᚦᚬᚱᚴᚼᚾᛁᛅᛋᛏᛒᛘᛚᛦ';
    const angloSaxon = 'ᚪᚫᚣᛠᛡᛢᛣᛤᛥ';
    const witcherSigns = '◈◇✧⬡☆★✦✴⚝⬢'; // Aard, Igni, Yrden, Quen, Axii symbols
    const runes = elderFuthark + youngerFuthark + angloSaxon + witcherSigns;

    interface Column {
      y: number;
      speed: number;
      chars: { char: string; alpha: number; isBling: boolean; blingPhase: number }[];
    }

    let columns: Column[] = [];
    let blingParticles: { x: number; y: number; alpha: number; size: number; decay: number }[] = [];

    const initColumns = () => {
      const columnsCount = Math.floor(canvas.width / fontSize);
      columns = [];
      for (let i = 0; i < columnsCount; i++) {
        columns.push({
          y: Math.random() * canvas.height,
          speed: 0.3 + Math.random() * 0.7,
          chars: [],
        });
      }
    };

    const handleResize = () => {
      canvas.width = container.offsetWidth;
      canvas.height = container.offsetHeight;
      initColumns();
    };

    handleResize();
    window.addEventListener('resize', handleResize);

    const draw = () => {
      // Fade effect
      ctx.fillStyle = fadeColor;
      ctx.fillRect(0, 0, canvas.width, canvas.height);

      ctx.font = `${fontSize}px serif`;
      ctx.textAlign = 'center';

      for (let i = 0; i < columns.length; i++) {
        const col = columns[i];
        const x = i * fontSize + fontSize / 2;

        // Draw rune
        const char = runes.charAt(Math.floor(Math.random() * runes.length));
        const isBling = Math.random() > 0.97;

        // Gold-white gradient effect
        if (isBling) {
          // Bling effect - bright gold with glow
          ctx.shadowColor = isLight ? 'rgba(255, 200, 50, 0.8)' : 'rgba(255, 215, 100, 0.9)';
          ctx.shadowBlur = 15;
          ctx.fillStyle = isLight ? '#d4a000' : '#ffd700';

          // Add particle
          blingParticles.push({
            x: x,
            y: col.y,
            alpha: 1,
            size: 2 + Math.random() * 3,
            decay: 0.02 + Math.random() * 0.03,
          });
        } else {
          ctx.shadowBlur = 0;
          // Subtle white-gold gradient
          const alpha = isLight ? 0.15 + Math.random() * 0.2 : 0.2 + Math.random() * 0.25;
          ctx.fillStyle = isLight
            ? `rgba(180, 150, 80, ${alpha})`
            : `rgba(255, 245, 220, ${alpha})`;
        }

        ctx.fillText(char, x, col.y);
        ctx.shadowBlur = 0;

        // Move column
        col.y += fontSize * col.speed;

        // Reset column
        if (col.y > canvas.height && Math.random() > 0.98) {
          col.y = 0;
          col.speed = 0.3 + Math.random() * 0.7;
        }
      }

      // Draw bling particles
      for (let i = blingParticles.length - 1; i >= 0; i--) {
        const p = blingParticles[i];

        ctx.beginPath();
        ctx.arc(p.x, p.y, p.size, 0, Math.PI * 2);
        ctx.fillStyle = isLight
          ? `rgba(212, 160, 0, ${p.alpha * 0.6})`
          : `rgba(255, 215, 0, ${p.alpha * 0.8})`;
        ctx.fill();

        // Sparkle cross
        ctx.strokeStyle = isLight
          ? `rgba(255, 220, 100, ${p.alpha * 0.4})`
          : `rgba(255, 250, 200, ${p.alpha * 0.5})`;
        ctx.lineWidth = 1;
        ctx.beginPath();
        ctx.moveTo(p.x - p.size * 2, p.y);
        ctx.lineTo(p.x + p.size * 2, p.y);
        ctx.moveTo(p.x, p.y - p.size * 2);
        ctx.lineTo(p.x, p.y + p.size * 2);
        ctx.stroke();

        p.alpha -= p.decay;
        p.size *= 0.98;

        if (p.alpha <= 0) {
          blingParticles.splice(i, 1);
        }
      }
    };

    const intervalId = setInterval(draw, speed);

    return () => {
      clearInterval(intervalId);
      window.removeEventListener('resize', handleResize);
    };
  }, [fontSize, speed, isLight, fadeColor]);

  return (
    <div
      ref={containerRef}
      style={{
        position: 'fixed',
        top: 0,
        left: 0,
        width: '100%',
        height: '100%',
        zIndex: 0,
        backgroundColor: bgColor,
        overflow: 'hidden',
        pointerEvents: 'none',
      }}
    >
      <canvas ref={canvasRef} style={{ display: 'block' }} />
    </div>
  );
};

export default WitcherRain;
