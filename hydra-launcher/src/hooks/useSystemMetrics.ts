import { useEffect, useState, useCallback } from "react";
import { invoke } from "@tauri-apps/api/core";

export interface SystemMetrics {
  cpu_percent: number;
  memory_percent: number;
  memory_used_gb: number;
  memory_total_gb: number;
}

export function useSystemMetrics(refreshInterval = 2000) {
  const [metrics, setMetrics] = useState<SystemMetrics | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const fetchMetrics = useCallback(async () => {
    try {
      const result = await invoke<SystemMetrics>("get_system_metrics");
      setMetrics(result);
      setError(null);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Unknown error");
    } finally {
      setIsLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchMetrics();

    const interval = setInterval(fetchMetrics, refreshInterval);
    return () => clearInterval(interval);
  }, [fetchMetrics, refreshInterval]);

  return {
    metrics,
    isLoading,
    error,
    refresh: fetchMetrics,
  };
}
