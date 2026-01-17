import React, { useEffect, useRef } from 'react';
import { useTheme } from '../contexts/ThemeContext';

interface MatrixRainProps {
  fontSize?: number;
  speed?: number;
}

const MatrixRain: React.FC<MatrixRainProps> = ({ fontSize = 14, speed = 33 }) => {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const containerRef = useRef<HTMLDivElement>(null);
  const { resolvedTheme } = useTheme();

  const isLight = resolvedTheme === 'light';
  const bgColor = isLight ? '#f5f8f5' : '#0a0a0a';
  const charColor = isLight ? '#2d6a4f' : '#00ff41';
  const fadeColor = isLight ? 'rgba(245, 248, 245, 0.05)' : 'rgba(0, 0, 0, 0.05)';

  useEffect(() => {
    const canvas = canvasRef.current;
    const container = containerRef.current;
    if (!canvas || !container) return;

    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    const handleResize = () => {
      canvas.width = container.offsetWidth;
      canvas.height = container.offsetHeight;
      initColumns();
    };

    // Matrix characters: Katakana + Latin + Numbers
    const katakana =
      'アァカサタナハマヤャラワガザダバパイィキシチニヒミリヰギジヂビピウゥクスツヌフムユュルグズブヅプエェケセテネヘメレヱゲゼデベペオォコソトノホモヨョロヲゴゾドボポヴッン';
    const latin = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    const nums = '0123456789';
    const hydra = 'HYDRA'; // Easter egg
    const alphabet = katakana + latin + nums + hydra;

    let columns: number[] = [];

    const initColumns = () => {
      const columnsCount = Math.floor(canvas.width / fontSize);
      columns = Array(columnsCount).fill(1);
    };

    handleResize();
    window.addEventListener('resize', handleResize);

    const draw = () => {
      ctx.fillStyle = fadeColor;
      ctx.fillRect(0, 0, canvas.width, canvas.height);

      ctx.fillStyle = charColor;
      ctx.font = `${fontSize}px monospace`;

      for (let i = 0; i < columns.length; i++) {
        const text = alphabet.charAt(Math.floor(Math.random() * alphabet.length));
        const x = i * fontSize;
        const y = columns[i] * fontSize;

        ctx.fillText(text, x, y);

        if (y > canvas.height && Math.random() > 0.975) {
          columns[i] = 0;
        }
        columns[i]++;
      }
    };

    const intervalId = setInterval(draw, speed);

    return () => {
      clearInterval(intervalId);
      window.removeEventListener('resize', handleResize);
    };
  }, [fontSize, speed, charColor, fadeColor]);

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

export default MatrixRain;
