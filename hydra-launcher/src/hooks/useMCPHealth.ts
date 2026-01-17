import { useEffect, useState, useCallback } from "react";
import { invoke } from "@tauri-apps/api/core";

export interface McpHealthResult {
  name: string;
  port: number;
  status: "online" | "offline" | "error";
  response_time_ms: number | null;
  error: string | null;
}

export function useMCPHealth(refreshInterval = 5000) {
  const [health, setHealth] = useState<McpHealthResult[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const checkHealth = useCallback(async () => {
    try {
      const results = await invoke<McpHealthResult[]>("check_mcp_health");
      setHealth(results);
      setError(null);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Unknown error");
    } finally {
      setIsLoading(false);
    }
  }, []);

  useEffect(() => {
    checkHealth();

    const interval = setInterval(checkHealth, refreshInterval);
    return () => clearInterval(interval);
  }, [checkHealth, refreshInterval]);

  const allOnline = health.every((h) => h.status === "online");
  const onlineCount = health.filter((h) => h.status === "online").length;

  return {
    health,
    isLoading,
    error,
    refresh: checkHealth,
    allOnline,
    onlineCount,
    totalCount: health.length,
  };
}
