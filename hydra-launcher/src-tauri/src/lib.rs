mod config;
mod commands;
mod mcp;
mod process;

use tauri::Manager;

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
        ])
        .setup(|app| {
            #[cfg(debug_assertions)]
            {
                let window = app.get_webview_window("main").unwrap();
                window.open_devtools();
            }
            Ok(())
        })
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
