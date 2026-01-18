use reqwest::Client;
use serde::Deserialize;
use std::time::Duration;

const OLLAMA_URL: &str = "http://127.0.0.1:11434";

#[derive(Debug, Deserialize)]
struct OllamaTagsResponse {
    models: Vec<OllamaModel>,
}

#[derive(Debug, Deserialize)]
struct OllamaModel {
    name: String,
}

/// Check if Ollama is running on default port
pub async fn check_ollama_running() -> Result<bool, String> {
    let client = Client::builder()
        .timeout(Duration::from_secs(2))
        .build()
        .map_err(|e| e.to_string())?;

    match client.get(format!("{}/api/tags", OLLAMA_URL)).send().await {
        Ok(response) => Ok(response.status().is_success()),
        Err(_) => Ok(false),
    }
}

/// Get list of available Ollama models
pub async fn get_ollama_model_list() -> Result<Vec<String>, String> {
    let client = Client::builder()
        .timeout(Duration::from_secs(5))
        .build()
        .map_err(|e| e.to_string())?;

    let response = client
        .get(format!("{}/api/tags", OLLAMA_URL))
        .send()
        .await
        .map_err(|e| format!("Failed to connect to Ollama: {}", e))?;

    if !response.status().is_success() {
        return Err(format!("Ollama returned status: {}", response.status()));
    }

    let tags: OllamaTagsResponse = response
        .json()
        .await
        .map_err(|e| format!("Failed to parse response: {}", e))?;

    Ok(tags.models.into_iter().map(|m| m.name).collect())
}

/// Start Ollama service (Windows)
#[allow(dead_code)]
#[cfg(windows)]
pub async fn start_ollama() -> Result<(), String> {
    use std::process::Command;

    Command::new("cmd")
        .args(["/c", "start", "ollama", "serve"])
        .spawn()
        .map_err(|e| format!("Failed to start Ollama: {}", e))?;

    // Wait for Ollama to start
    tokio::time::sleep(Duration::from_secs(3)).await;

    if check_ollama_running().await? {
        Ok(())
    } else {
        Err("Ollama started but not responding".to_string())
    }
}

#[cfg(not(windows))]
pub async fn start_ollama() -> Result<(), String> {
    use std::process::Command;

    Command::new("ollama")
        .arg("serve")
        .spawn()
        .map_err(|e| format!("Failed to start Ollama: {}", e))?;

    tokio::time::sleep(Duration::from_secs(3)).await;

    if check_ollama_running().await? {
        Ok(())
    } else {
        Err("Ollama started but not responding".to_string())
    }
}
