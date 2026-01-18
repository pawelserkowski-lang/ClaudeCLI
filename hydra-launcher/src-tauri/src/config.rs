use serde::{Deserialize, Serialize};
use std::fs;
use std::path::PathBuf;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct HydraConfig {
    pub version: String,
    pub mode: String,
    pub yolo_enabled: bool,
    pub mcp_servers: Vec<McpServerConfig>,
    pub ai_handler: AiHandlerConfig,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct McpServerConfig {
    pub name: String,
    pub port: u16,
    pub command: String,
    #[serde(default)]
    pub args: Vec<String>,
    pub enabled: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AiHandlerConfig {
    pub prefer_local: bool,
    pub ollama_port: u16,
    pub default_model: String,
}

impl Default for HydraConfig {
    fn default() -> Self {
        Self {
            version: "10.4.0".to_string(),
            mode: "MCP Orchestration".to_string(),
            yolo_enabled: true,
            mcp_servers: vec![
                McpServerConfig {
                    name: "Serena".to_string(),
                    port: 9000,
                    command: "npx".to_string(),
                    args: vec!["-y".to_string(), "serena-mcp".to_string()],
                    enabled: true,
                },
                McpServerConfig {
                    name: "Desktop Commander".to_string(),
                    port: 8100,
                    command: "npx".to_string(),
                    args: vec!["-y".to_string(), "@anthropics/desktop-commander-mcp".to_string()],
                    enabled: true,
                },
                McpServerConfig {
                    name: "Playwright".to_string(),
                    port: 5200,
                    command: "npx".to_string(),
                    args: vec!["-y".to_string(), "@anthropics/playwright-mcp".to_string()],
                    enabled: true,
                },
            ],
            ai_handler: AiHandlerConfig {
                prefer_local: true,
                ollama_port: 11434,
                default_model: "llama3.2:3b".to_string(),
            },
        }
    }
}

impl HydraConfig {
    pub fn load(path: Option<PathBuf>) -> Result<Self, String> {
        let config_path = path.unwrap_or_else(|| {
            // Default to ClaudeHYDRA directory
            let home = dirs::home_dir().unwrap_or_default();
            home.join("Desktop").join("ClaudeHYDRA").join("hydra-config.json")
        });

        if config_path.exists() {
            let content = fs::read_to_string(&config_path)
                .map_err(|e| format!("Failed to read config: {}", e))?;

            serde_json::from_str(&content)
                .map_err(|e| format!("Failed to parse config: {}", e))
        } else {
            Ok(Self::default())
        }
    }

    #[allow(dead_code)]
    pub fn save(&self, path: Option<PathBuf>) -> Result<(), String> {
        let config_path = path.unwrap_or_else(|| {
            let home = dirs::home_dir().unwrap_or_default();
            home.join("Desktop").join("ClaudeHYDRA").join("hydra-config.json")
        });

        let content = serde_json::to_string_pretty(self)
            .map_err(|e| format!("Failed to serialize config: {}", e))?;

        fs::write(&config_path, content)
            .map_err(|e| format!("Failed to write config: {}", e))
    }
}

// Helper to get dirs - we'll implement our own since dirs crate isn't in dependencies
mod dirs {
    use std::path::PathBuf;

    pub fn home_dir() -> Option<PathBuf> {
        std::env::var("USERPROFILE")
            .or_else(|_| std::env::var("HOME"))
            .ok()
            .map(PathBuf::from)
    }
}
