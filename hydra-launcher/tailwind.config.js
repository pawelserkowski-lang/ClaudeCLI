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
        witcher: {
          bg: {
            primary: '#0a0a08',
            secondary: '#0d0d0a',
          },
          gold: '#d4a50a',
          'gold-light': '#ffd700',
          amber: '#c9a227',
          bronze: '#b8860b',
          glass: 'rgba(15, 12, 8, 0.88)',
        },
        // Legacy matrix colors (mapped to witcher)
        matrix: {
          bg: {
            primary: '#0a0a08',
            secondary: '#0d0d0a',
          },
          accent: '#d4a50a',
          glass: 'rgba(15, 12, 8, 0.88)',
        },
        hydra: {
          gold: '#ffd700',
          amber: '#c9a227',
          bronze: '#b8860b',
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
        witcherRain: {
          '0%': { transform: 'translateY(-100%)' },
          '100%': { transform: 'translateY(100%)' },
        },
        glow: {
          '0%': { boxShadow: '0 0 5px #d4a50a, 0 0 10px #d4a50a' },
          '100%': { boxShadow: '0 0 20px #ffd700, 0 0 30px #ffd700' },
        },
        bling: {
          '0%, 100%': { opacity: '0.3' },
          '50%': { opacity: '1' },
        }
      },
      transitionDuration: {
        '2000': '2000ms',
      }
    },
  },
  plugins: [require('tailwindcss-animate')],
}
