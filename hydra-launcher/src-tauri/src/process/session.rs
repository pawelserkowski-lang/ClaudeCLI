use std::io::{BufRead, BufReader, Write};
use std::process::{Child, Command, Stdio};
use std::sync::{Arc, Mutex};
use std::thread;

/// Claude CLI Session Manager
#[allow(dead_code)]
pub struct ClaudeSession {
    process: Option<Child>,
    output_buffer: Arc<Mutex<Vec<String>>>,
    is_running: bool,
}

#[allow(dead_code)]
impl ClaudeSession {
    pub fn new() -> Self {
        Self {
            process: None,
            output_buffer: Arc::new(Mutex::new(Vec::new())),
            is_running: false,
        }
    }

    /// Start a new Claude CLI session
    pub fn start(&mut self, yolo_mode: bool, hydra_path: &str) -> Result<(), String> {
        if self.is_running {
            return Err("Session already running".to_string());
        }

        let mut args = vec![];

        if yolo_mode {
            args.push("--dangerously-skip-permissions".to_string());
        }

        // Start Claude CLI with piped stdin/stdout
        // Note: Claude CLI doesn't have --cwd option, we use current_dir() instead
        let mut child = Command::new("claude")
            .current_dir(hydra_path)
            .args(&args)
            .stdin(Stdio::piped())
            .stdout(Stdio::piped())
            .stderr(Stdio::piped())
            .spawn()
            .map_err(|e| format!("Failed to start Claude CLI: {}", e))?;

        // Capture stdout in background thread
        let stdout = child.stdout.take();
        let buffer = Arc::clone(&self.output_buffer);

        if let Some(stdout) = stdout {
            thread::spawn(move || {
                let reader = BufReader::new(stdout);
                for line in reader.lines() {
                    if let Ok(line) = line {
                        let mut buf = buffer.lock().unwrap();
                        buf.push(line);
                    }
                }
            });
        }

        self.process = Some(child);
        self.is_running = true;

        Ok(())
    }

    /// Send a message to Claude CLI
    pub fn send(&mut self, message: &str) -> Result<(), String> {
        if let Some(ref mut child) = self.process {
            if let Some(ref mut stdin) = child.stdin {
                writeln!(stdin, "{}", message)
                    .map_err(|e| format!("Failed to send message: {}", e))?;
                stdin.flush()
                    .map_err(|e| format!("Failed to flush: {}", e))?;
                Ok(())
            } else {
                Err("No stdin available".to_string())
            }
        } else {
            Err("No active session".to_string())
        }
    }

    /// Read accumulated output
    pub fn read_output(&self) -> Vec<String> {
        let mut buffer = self.output_buffer.lock().unwrap();
        let output = buffer.clone();
        buffer.clear();
        output
    }

    /// Stop the session
    pub fn stop(&mut self) -> Result<(), String> {
        if let Some(ref mut child) = self.process {
            child.kill().map_err(|e| format!("Failed to kill process: {}", e))?;
        }
        self.process = None;
        self.is_running = false;
        Ok(())
    }

    pub fn is_running(&self) -> bool {
        self.is_running
    }
}

impl Drop for ClaudeSession {
    fn drop(&mut self) {
        let _ = self.stop();
    }
}
