import { useEffect, useState, useCallback } from "react";
import { safeInvoke, isTauri } from "./useTauri";

export interface SystemMetrics {
  cpu_percent: number;
  memory_percent: number;
  memory_used_gb: number;
  memory_total_gb: number;
}

// Mock data for browser development
const getMockMetrics = (): SystemMetrics => ({
  cpu_percent: Math.random() * 30 + 15, // 15-45%
  memory_percent: Math.random() * 20 + 40, // 40-60%
  memory_used_gb: 8.5 + Math.random() * 2,
  memory_total_gb: 16,
});

export function useSystemMetrics(refreshInterval = 2000) {
  const [metrics, setMetrics] = useState<SystemMetrics | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const fetchMetrics = useCallback(async () => {
    try {
      if (!isTauri()) {
        // Browser mode - use mock data
        setMetrics(getMockMetrics());
        setError(null);
        setIsLoading(false);
        return;
      }

      const result = await safeInvoke<SystemMetrics>("get_system_metrics");
      setMetrics(result);
      setError(null);
    } catch (e) {
      const errorMsg = e instanceof Error ? e.message : String(e);
      // Don't show error for browser mode
      if (!errorMsg.includes('browser mode')) {
        setError(errorMsg);
      }
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
