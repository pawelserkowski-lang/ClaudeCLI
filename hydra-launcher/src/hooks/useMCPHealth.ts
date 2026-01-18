import { useEffect, useState, useCallback } from "react";
import { safeInvoke, isTauri } from "./useTauri";

export interface McpHealthResult {
  name: string;
  port: number;
  status: "online" | "offline" | "error";
  response_time_ms: number | null;
  error: string | null;
}

// Mock data for browser development
const MOCK_MCP_HEALTH: McpHealthResult[] = [
  { name: "Serena", port: 9000, status: "online", response_time_ms: 12, error: null },
  { name: "Desktop Commander", port: 8100, status: "online", response_time_ms: 8, error: null },
  { name: "Playwright", port: 5200, status: "offline", response_time_ms: null, error: "Not running" },
];

export function useMCPHealth(refreshInterval = 5000) {
  const [health, setHealth] = useState<McpHealthResult[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const checkHealth = useCallback(async () => {
    try {
      if (!isTauri()) {
        // Browser mode - use mock data
        setHealth(MOCK_MCP_HEALTH);
        setError(null);
        setIsLoading(false);
        return;
      }

      const results = await safeInvoke<McpHealthResult[]>("check_mcp_health");
      setHealth(results);
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
