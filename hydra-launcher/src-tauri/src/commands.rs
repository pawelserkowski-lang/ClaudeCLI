use crate::config::HydraConfig;
use crate::mcp::health::{check_all_mcp_servers, McpHealthResult};
use crate::process::claude::spawn_claude_cli;
use crate::process::ollama::{check_ollama_running, get_ollama_model_list};
use serde::{Deserialize, Serialize};
use sysinfo::System;
use std::sync::Mutex;
use tauri::State;

// Global state for YOLO mode
pub struct AppState {
    pub yolo_enabled: Mutex<bool>,
}

impl Default for AppState {
    fn default() -> Self {
        Self {
            yolo_enabled: Mutex::new(true), // YOLO ON by default
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SystemMetrics {
    pub cpu_percent: f32,
    pub memory_percent: f32,
    pub memory_used_gb: f64,
    pub memory_total_gb: f64,
}

#[tauri::command]
pub async fn check_mcp_health() -> Result<Vec<McpHealthResult>, String> {
    check_all_mcp_servers().await
}

#[tauri::command]
pub fn get_system_metrics() -> SystemMetrics {
    let mut sys = System::new_all();
    sys.refresh_all();

    let cpu_percent = sys.global_cpu_usage();
    let memory_used = sys.used_memory() as f64;
    let memory_total = sys.total_memory() as f64;
    let memory_percent = (memory_used / memory_total * 100.0) as f32;

    SystemMetrics {
        cpu_percent,
        memory_percent,
        memory_used_gb: memory_used / 1024.0 / 1024.0 / 1024.0,
        memory_total_gb: memory_total / 1024.0 / 1024.0 / 1024.0,
    }
}

#[tauri::command]
pub fn load_hydra_config() -> Result<HydraConfig, String> {
    HydraConfig::load(None)
}

#[tauri::command]
pub async fn launch_claude(yolo_mode: bool) -> Result<String, String> {
    spawn_claude_cli(yolo_mode).await
}

#[tauri::command]
pub async fn check_ollama() -> Result<bool, String> {
    check_ollama_running().await
}

#[tauri::command]
pub async fn get_ollama_models() -> Result<Vec<String>, String> {
    get_ollama_model_list().await
}

#[tauri::command]
pub fn set_yolo_mode(state: State<'_, AppState>, enabled: bool) -> bool {
    let mut yolo = state.yolo_enabled.lock().unwrap();
    *yolo = enabled;
    enabled
}
