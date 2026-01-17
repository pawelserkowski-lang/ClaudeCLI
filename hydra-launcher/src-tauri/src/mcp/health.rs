use serde::{Deserialize, Serialize};
use std::time::Duration;
use tokio::net::TcpStream;
use tokio::time::timeout;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct McpHealthResult {
    pub name: String,
    pub port: u16,
    pub status: McpStatus,
    pub response_time_ms: Option<u64>,
    pub error: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "lowercase")]
pub enum McpStatus {
    Online,
    Offline,
    Error,
}

/// Check if a TCP port is open (basic health check)
async fn check_port(port: u16) -> Result<u64, String> {
    let addr = format!("127.0.0.1:{}", port);
    let start = std::time::Instant::now();

    match timeout(Duration::from_secs(2), TcpStream::connect(&addr)).await {
        Ok(Ok(_)) => Ok(start.elapsed().as_millis() as u64),
        Ok(Err(e)) => Err(format!("Connection failed: {}", e)),
        Err(_) => Err("Connection timeout".to_string()),
    }
}

/// Check a single MCP server
pub async fn check_mcp_server(name: &str, port: u16) -> McpHealthResult {
    match check_port(port).await {
        Ok(response_time) => McpHealthResult {
            name: name.to_string(),
            port,
            status: McpStatus::Online,
            response_time_ms: Some(response_time),
            error: None,
        },
        Err(e) => McpHealthResult {
            name: name.to_string(),
            port,
            status: McpStatus::Offline,
            response_time_ms: None,
            error: Some(e),
        },
    }
}

/// Check all configured MCP servers in parallel
pub async fn check_all_mcp_servers() -> Result<Vec<McpHealthResult>, String> {
    let servers = vec![
        ("Serena", 9000u16),
        ("Desktop Commander", 8100u16),
        ("Playwright", 5200u16),
    ];

    let handles: Vec<_> = servers
        .into_iter()
        .map(|(name, port)| {
            let name = name.to_string();
            tokio::spawn(async move { check_mcp_server(&name, port).await })
        })
        .collect();

    let mut results = Vec::new();
    for handle in handles {
        match handle.await {
            Ok(result) => results.push(result),
            Err(e) => {
                results.push(McpHealthResult {
                    name: "Unknown".to_string(),
                    port: 0,
                    status: McpStatus::Error,
                    response_time_ms: None,
                    error: Some(format!("Task failed: {}", e)),
                });
            }
        }
    }

    Ok(results)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_check_port_timeout() {
        // Port that's unlikely to be open
        let result = check_port(59999).await;
        assert!(result.is_err());
    }
}
