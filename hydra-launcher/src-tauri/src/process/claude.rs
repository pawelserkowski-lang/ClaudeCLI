use std::process::Command;

/// Spawn Claude CLI with HYDRA configuration
pub async fn spawn_claude_cli(yolo_mode: bool) -> Result<String, String> {
    let hydra_path = get_hydra_path()?;

    let mut args = vec![];

    if yolo_mode {
        // YOLO mode: dangerously skip all permissions
        args.push("--dangerously-skip-permissions".to_string());
    }

    // Add working directory
    args.push("--cwd".to_string());
    args.push(hydra_path.clone());

    log::info!("Launching Claude CLI with args: {:?}", args);

    // Use start command on Windows to open in new terminal
    #[cfg(windows)]
    {
        let claude_cmd = format!(
            "cd /d \"{}\" && claude {}",
            hydra_path,
            args.join(" ")
        );

        Command::new("cmd")
            .args(["/c", "start", "cmd", "/k", &claude_cmd])
            .spawn()
            .map_err(|e| format!("Failed to launch Claude CLI: {}", e))?;
    }

    #[cfg(not(windows))]
    {
        Command::new("claude")
            .args(&args)
            .current_dir(&hydra_path)
            .spawn()
            .map_err(|e| format!("Failed to launch Claude CLI: {}", e))?;
    }

    Ok("Claude CLI launched successfully".to_string())
}

/// Get the HYDRA project path
fn get_hydra_path() -> Result<String, String> {
    // Check environment variable first
    if let Ok(path) = std::env::var("HYDRA_PATH") {
        return Ok(path);
    }

    // Default to Desktop/ClaudeHYDRA
    let home = std::env::var("USERPROFILE")
        .or_else(|_| std::env::var("HOME"))
        .map_err(|_| "Could not determine home directory")?;

    let default_path = format!("{}\\Desktop\\ClaudeHYDRA", home);

    if std::path::Path::new(&default_path).exists() {
        Ok(default_path)
    } else {
        Err("HYDRA path not found. Set HYDRA_PATH environment variable.".to_string())
    }
}

/// Check if Claude CLI is installed
pub async fn check_claude_installed() -> bool {
    #[cfg(windows)]
    {
        Command::new("where")
            .arg("claude")
            .output()
            .map(|o| o.status.success())
            .unwrap_or(false)
    }

    #[cfg(not(windows))]
    {
        Command::new("which")
            .arg("claude")
            .output()
            .map(|o| o.status.success())
            .unwrap_or(false)
    }
}
