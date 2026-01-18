mod config;
mod commands;
mod mcp;
mod process;
mod logger;

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_shell::init())
        .invoke_handler(tauri::generate_handler![
            commands::check_mcp_health,
            commands::get_system_metrics,
            commands::load_hydra_config,
            commands::launch_claude,
            commands::check_ollama,
            commands::get_ollama_models,
            commands::set_yolo_mode,
            commands::start_claude_session,
            commands::send_to_claude,
        ])
        .manage(commands::AppState::default())
        .setup(|_app| {
            // Initialize file logger
            if let Err(e) = logger::FileLogger::init() {
                eprintln!("Failed to init logger: {}", e);
            } else {
                logger::log_info("HYDRA 10.4 Launcher started");
                logger::log_info("Tauri application setup complete");
            }
            Ok(())
        })
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
