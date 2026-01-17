import { useEffect, useState } from "react";
import Launcher from "./components/Launcher";
import Dashboard from "./components/Dashboard";
import WitcherRain from "./components/WitcherRain";
import { useTheme } from "./contexts/ThemeContext";

function App() {
  const [isLoading, setIsLoading] = useState(true);
  const { resolvedTheme } = useTheme();
  const isLight = resolvedTheme === 'light';

  useEffect(() => {
    // Loading sequence - 3 seconds
    const timer = setTimeout(() => {
      setIsLoading(false);
    }, 3000);

    return () => clearTimeout(timer);
  }, []);

  // Background images based on theme
  const backgroundImage = isLight ? '/backgroundlight.webp' : '/background.webp';

  return (
    <div className="w-full h-full relative overflow-hidden">
      {/* Background Image */}
      <div
        className="absolute inset-0 bg-cover bg-center bg-no-repeat transition-opacity duration-500"
        style={{
          backgroundImage: `url(${backgroundImage})`,
          zIndex: 0,
        }}
      />

      {/* Witcher Runes Rain Overlay */}
      <div className="absolute inset-0" style={{ zIndex: 1, opacity: isLight ? 0.5 : 0.6 }}>
        <WitcherRain />
      </div>

      {/* Gradient Overlay for better readability */}
      <div
        className={`absolute inset-0 transition-colors duration-500 ${
          isLight
            ? 'bg-gradient-to-br from-white/30 via-transparent to-white/30'
            : 'bg-gradient-to-br from-black/40 via-transparent to-black/40'
        }`}
        style={{ zIndex: 2 }}
      />

      {/* Main Content */}
      <div className="relative z-10 w-full h-full">
        {isLoading ? <Launcher /> : <Dashboard />}
      </div>
    </div>
  );
}

export default App;
