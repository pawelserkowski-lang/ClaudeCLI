import { useEffect, useState, useCallback } from "react";
import { invoke } from "@tauri-apps/api/core";

export function useOllama(refreshInterval = 10000) {
  const [isRunning, setIsRunning] = useState(false);
  const [models, setModels] = useState<string[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const checkOllama = useCallback(async () => {
    try {
      const running = await invoke<boolean>("check_ollama");
      setIsRunning(running);

      if (running) {
        const modelList = await invoke<string[]>("get_ollama_models");
        setModels(modelList);
      } else {
        setModels([]);
      }

      setError(null);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Unknown error");
      setIsRunning(false);
      setModels([]);
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
