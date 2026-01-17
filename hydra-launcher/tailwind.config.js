/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  darkMode: 'class',
  theme: {
    extend: {
      colors: {
        matrix: {
          bg: {
            primary: '#0a1f0a',
            secondary: '#001a00',
          },
          accent: '#00ff41',
          glass: 'rgba(0, 31, 0, 0.7)',
        },
        hydra: {
          cyan: '#00d4ff',
          purple: '#bd00ff',
          gold: '#ffd700',
        }
      },
      fontFamily: {
        mono: ['"JetBrains Mono"', 'Consolas', 'monospace'],
        sans: ['Inter', 'system-ui', 'sans-serif'],
      },
      animation: {
        'pulse-slow': 'pulse 4s cubic-bezier(0.4, 0, 0.6, 1) infinite',
        'matrix-rain': 'matrixRain 20s linear infinite',
        'glow': 'glow 2s ease-in-out infinite alternate',
      },
      keyframes: {
        matrixRain: {
          '0%': { transform: 'translateY(-100%)' },
          '100%': { transform: 'translateY(100%)' },
        },
        glow: {
          '0%': { boxShadow: '0 0 5px #00ff41, 0 0 10px #00ff41' },
          '100%': { boxShadow: '0 0 20px #00ff41, 0 0 30px #00ff41' },
        }
      },
      transitionDuration: {
        '2000': '2000ms',
      }
    },
  },
  plugins: [require('tailwindcss-animate')],
}
