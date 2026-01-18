import { useEffect, useState, useCallback } from "react";
import { safeInvoke, isTauri } from "./useTauri";

// Mock data for browser development
const MOCK_MODELS = ["llama3.2:3b", "qwen2.5-coder:1.5b", "phi3:mini"];

export function useOllama(refreshInterval = 10000) {
  const [isRunning, setIsRunning] = useState(false);
  const [models, setModels] = useState<string[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const checkOllama = useCallback(async () => {
    try {
      if (!isTauri()) {
        // Browser mode - use mock data
        setIsRunning(true);
        setModels(MOCK_MODELS);
        setError(null);
        setIsLoading(false);
        return;
      }

      const running = await safeInvoke<boolean>("check_ollama");
      setIsRunning(running);

      if (running) {
        const modelList = await safeInvoke<string[]>("get_ollama_models");
        setModels(modelList);
      } else {
        setModels([]);
      }

      setError(null);
    } catch (e) {
      const errorMsg = e instanceof Error ? e.message : String(e);
      // Don't show error for browser mode
      if (!errorMsg.includes('browser mode')) {
        setError(errorMsg);
        setIsRunning(false);
        setModels([]);
      }
    } finally {
      setIsLoading(false);
    }
  }, []);

  useEffect(() => {
    checkOllama();

    const interval = setInterval(checkOllama, refreshInterval);
    return () => clearInterval(interval);
  }, [checkOllama, refreshInterval]);

  return {
    isRunning,
    models,
    isLoading,
    error,
    refresh: checkOllama,
  };
}
