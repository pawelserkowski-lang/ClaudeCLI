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
    const witcherSigns = '◈◇✧⬡☆★✦✴⚝⬢';
    const runes = elderFuthark + youngerFuthark + angloSaxon + witcherSigns;

    interface Column {
      y: number;
      speed: number;
    }

    let columns: Column[] = [];
    // Bling particles disabled for cleaner UI

    const initColumns = () => {
      const columnsCount = Math.floor(canvas.width / fontSize);
      columns = [];
      for (let i = 0; i < columnsCount; i++) {
        columns.push({
          y: Math.random() * canvas.height,
          speed: 0.3 + Math.random() * 0.7,
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

        // Draw rune - simple, no bling
        const char = runes.charAt(Math.floor(Math.random() * runes.length));

        // Subtle gold runes only
        const alpha = isLight ? 0.15 + Math.random() * 0.2 : 0.2 + Math.random() * 0.25;
        ctx.fillStyle = isLight
          ? `rgba(180, 150, 80, ${alpha})`
          : `rgba(255, 245, 220, ${alpha})`;

        ctx.fillText(char, x, col.y);

        // Move column
        col.y += fontSize * col.speed;

        // Reset column
        if (col.y > canvas.height && Math.random() > 0.98) {
          col.y = 0;
          col.speed = 0.3 + Math.random() * 0.7;
        }
      }

      // Bling particles removed for cleaner UI
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
