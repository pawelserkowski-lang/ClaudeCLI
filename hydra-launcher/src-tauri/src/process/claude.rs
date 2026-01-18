use std::process::Command;

/// Initial HYDRA prompt with instructions
const HYDRA_INIT_PROMPT: &str = r#"HYDRA 10.4 ACTIVATED - Four-Headed Beast Mode

KONTEKST SESJI:
- Dzialamy LOKALNIE na maszynie uzytkownika (Windows)
- Masz PELNE UPRAWNIENIA do odczytu i zapisu WSZYSTKICH plikow
- Mozesz uruchamiac WSZYSTKIE aplikacje i komendy systemowe
- Masz dostep do internetu - ZAWSZE szukaj rozwiazania online

ZASADA PRZY PROBLEMACH:
Gdy napotkasz blad lub problem, ZAWSZE:
1. Uzyj WebSearch do wyszukania rozwiazania w Google
2. Sprawdz StackOverflow dla bledow programistycznych
3. Przeszukaj dokumentacje oficjalna

AKTYWNE NARZEDZIA MCP:
- Serena (port 9000) - analiza kodu
- Desktop Commander (port 8100) - operacje systemowe
- Playwright (port 5200) - automatyzacja przegladarki

Uruchom /hydra aby zobaczyc pelne instrukcje."#;

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

    // Add initial prompt
    args.push("-p".to_string());
    args.push(HYDRA_INIT_PROMPT.to_string());

    log::info!("Launching Claude CLI with args: {:?}", args);

    // Use start command on Windows to open in new terminal
    #[cfg(windows)]
    {
        // Build base args without prompt
        let base_args: Vec<&str> = if yolo_mode {
            vec!["--dangerously-skip-permissions", "--cwd", &hydra_path]
        } else {
            vec!["--cwd", &hydra_path]
        };

        // Escape prompt for command line - replace newlines with spaces
        let escaped_prompt = HYDRA_INIT_PROMPT.replace('\n', " ").replace('\r', "");

        let claude_cmd = format!(
            "cd /d \"{}\" && claude {} -p \"{}\"",
            hydra_path,
            base_args.join(" "),
            escaped_prompt
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
#[allow(dead_code)]
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
