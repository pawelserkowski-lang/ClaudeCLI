use std::process::Command;

/// Start an MCP server (placeholder - actual implementation depends on MCP server setup)
#[allow(dead_code)]
pub fn start_mcp_server(name: &str, command: &str, args: &[String]) -> Result<u32, String> {
    let mut cmd = Command::new(command);
    cmd.args(args);

    // On Windows, spawn without visible console
    #[cfg(windows)]
    {
        use std::os::windows::process::CommandExt;
        const CREATE_NO_WINDOW: u32 = 0x08000000;
        cmd.creation_flags(CREATE_NO_WINDOW);
    }

    match cmd.spawn() {
        Ok(child) => {
            log::info!("Started MCP server '{}' with PID: {}", name, child.id());
            Ok(child.id())
        }
        Err(e) => Err(format!("Failed to start '{}': {}", name, e)),
    }
}

/// Stop an MCP server by PID
#[allow(dead_code)]
#[cfg(windows)]
pub fn stop_mcp_server(pid: u32) -> Result<(), String> {
    let output = Command::new("taskkill")
        .args(["/PID", &pid.to_string(), "/F"])
        .output()
        .map_err(|e| format!("Failed to execute taskkill: {}", e))?;

    if output.status.success() {
        Ok(())
    } else {
        Err(String::from_utf8_lossy(&output.stderr).to_string())
    }
}

#[allow(dead_code)]
#[cfg(not(windows))]
pub fn stop_mcp_server(pid: u32) -> Result<(), String> {
    use std::os::unix::process::CommandExt;

    let output = Command::new("kill")
        .args(["-9", &pid.to_string()])
        .output()
        .map_err(|e| format!("Failed to execute kill: {}", e))?;

    if output.status.success() {
        Ok(())
    } else {
        Err(String::from_utf8_lossy(&output.stderr).to_string())
    }
}
