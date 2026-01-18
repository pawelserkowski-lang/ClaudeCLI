use std::fs::{self, OpenOptions};
use std::io::Write;
use std::path::PathBuf;
use std::sync::Mutex;
use chrono::Local;

/// Global logger instance
static LOGGER: Mutex<Option<FileLogger>> = Mutex::new(None);

pub struct FileLogger {
    log_file: PathBuf,
}

impl FileLogger {
    /// Initialize the logger with a timestamped file
    pub fn init() -> Result<(), String> {
        let log_dir = get_log_directory()?;
        fs::create_dir_all(&log_dir).map_err(|e| format!("Failed to create log dir: {}", e))?;

        let timestamp = Local::now().format("%Y-%m-%d_%H-%M-%S");
        let log_file = log_dir.join(format!("hydra_{}.log", timestamp));

        let logger = FileLogger { log_file: log_file.clone() };

        // Write initial log entry
        logger.write_log("INFO", "HYDRA Launcher initialized")?;
        logger.write_log("INFO", &format!("Log file: {}", log_file.display()))?;

        *LOGGER.lock().unwrap() = Some(logger);
        Ok(())
    }

    fn write_log(&self, level: &str, message: &str) -> Result<(), String> {
        let timestamp = Local::now().format("%Y-%m-%d %H:%M:%S%.3f");
        let log_line = format!("[{}] [{}] {}\n", timestamp, level, message);

        let mut file = OpenOptions::new()
            .create(true)
            .append(true)
            .open(&self.log_file)
            .map_err(|e| format!("Failed to open log file: {}", e))?;

        file.write_all(log_line.as_bytes())
            .map_err(|e| format!("Failed to write log: {}", e))?;

        Ok(())
    }
}

/// Get the log directory path
fn get_log_directory() -> Result<PathBuf, String> {
    let home = std::env::var("USERPROFILE")
        .or_else(|_| std::env::var("HOME"))
        .map_err(|_| "Could not determine home directory")?;

    Ok(PathBuf::from(home).join("Desktop").join("ClaudeHYDRA").join("hydra-logs"))
}

/// Log an info message
pub fn log_info(message: &str) {
    if let Some(logger) = LOGGER.lock().unwrap().as_ref() {
        let _ = logger.write_log("INFO", message);
    }
}

/// Log a warning message
#[allow(dead_code)]
pub fn log_warn(message: &str) {
    if let Some(logger) = LOGGER.lock().unwrap().as_ref() {
        let _ = logger.write_log("WARN", message);
    }
}

/// Log an error message
pub fn log_error(message: &str) {
    if let Some(logger) = LOGGER.lock().unwrap().as_ref() {
        let _ = logger.write_log("ERROR", message);
    }
}

/// Log a debug message
pub fn log_debug(message: &str) {
    if let Some(logger) = LOGGER.lock().unwrap().as_ref() {
        let _ = logger.write_log("DEBUG", message);
    }
}

/// Log MCP health check result
pub fn log_mcp_health(server: &str, status: &str, response_time: Option<u64>) {
    let msg = match response_time {
        Some(ms) => format!("MCP {} - {} ({}ms)", server, status, ms),
        None => format!("MCP {} - {}", server, status),
    };
    log_info(&msg);
}

/// Log Claude CLI interaction
pub fn log_claude_interaction(action: &str, details: &str) {
    log_info(&format!("Claude CLI [{}]: {}", action, details));
}

/// Log system metrics
pub fn log_system_metrics(cpu: f32, memory: f32) {
    log_debug(&format!("System Metrics - CPU: {:.1}%, Memory: {:.1}%", cpu, memory));
}
