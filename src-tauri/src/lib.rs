pub mod archive;
pub mod commands;
pub mod db;
pub mod i18n;
pub mod ignore;
pub mod rules;
pub mod scheduler;
pub mod tray;
pub mod watcher;

use commands::*;
use db::{init_db, FOLDER_MODE_SILENT};
use directories::ProjectDirs;
use std::collections::HashMap;
use std::sync::{Arc, Mutex};
use std::time::Instant;
use tauri::Manager;
use tauri_plugin_autostart::ManagerExt;
use watcher::FolderWatcher;
#[cfg(target_os = "macos")]
use tauri::ActivationPolicy;

pub struct AppState {
    pub watcher: Arc<Mutex<FolderWatcher>>,
    pub ignored_files: Arc<Mutex<HashMap<String, Instant>>>,
    /// Last destination folder waiting to be opened when app is activated by notification click
    pub pending_open_folder: Arc<Mutex<Option<String>>>,
    pub scheduler: scheduler::Scheduler,
}

static APP_HANDLE: once_cell::sync::OnceCell<tauri::AppHandle> = once_cell::sync::OnceCell::new();

pub fn request_show_popup() {
    if let Some(app) = APP_HANDLE.get() {
        crate::tray::show_popup_window(app);
    }
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
fn is_silent_or_autostart(arg: &str) -> bool {
    let s = arg.trim_matches('"').trim_matches('\'').trim().to_lowercase();
    s == "--autostart"
        || s == "-autostart"
        || s == "/autostart"
        || s == "--minimized"
        || s == "-minimized"
        || s == "/minimized"
        || s == "--hidden"
        || s == "-hidden"
        || s == "/hidden"
        || s == "--silent"
        || s == "-silent"
        || s == "/silent"
        || s == "--background"
        || s == "-background"
        || s == "/background"
}

pub fn run() {
    let ignored_files = Arc::new(Mutex::new(HashMap::new()));
    let pending_open_folder: Arc<Mutex<Option<String>>> = Arc::new(Mutex::new(None));
    tauri::Builder::default()
        // Register single-instance first to intercept secondary instances immediately
        .plugin(tauri_plugin_single_instance::init(|app, args, _cwd| {
            let is_silent = args.iter().any(|arg| is_silent_or_autostart(arg));
            if is_silent {
                return;
            }

            // When Windows activates the app (e.g. user clicked a notification),
            // open any pending folder first, then show the popup.
            if let Some(state) = app.try_state::<AppState>() {
                let folder = state.pending_open_folder.lock().unwrap().take();
                if let Some(path) = folder {
                    // Open the destination folder in Explorer robustly
                    #[cfg(target_os = "windows")]
                    {
                        let _ = std::process::Command::new("cmd")
                            .args(["/c", "start", "", &path])
                            .spawn();
                    }
                    #[cfg(target_os = "macos")]
                    {
                        let _ = std::process::Command::new("open")
                            .arg(&path)
                            .spawn();
                    }
                    #[cfg(target_os = "linux")]
                    {
                        let _ = std::process::Command::new("xdg-open")
                            .arg(&path)
                            .spawn();
                    }
                }
            }
            // Bring popup window to focus or create it
            crate::tray::show_popup_window(app);
        }))
        .plugin(tauri_plugin_opener::init())
        .plugin(tauri_plugin_notification::init())
        .plugin(tauri_plugin_dialog::init())
        .plugin(tauri_plugin_autostart::init(
            tauri_plugin_autostart::MacosLauncher::LaunchAgent,
            Some(vec!["--autostart"]),
        ))
        .manage(AppState {
            watcher: Arc::new(Mutex::new(FolderWatcher::new(
                ignored_files.clone(),
                pending_open_folder.clone(),
            ))),
            ignored_files,
            pending_open_folder,
            scheduler: scheduler::Scheduler::new(),
        })
        .setup(|app| {
            // Hid app from dock on macOS
            #[cfg(target_os = "macos")]
            app.set_activation_policy(ActivationPolicy::Accessory);

            let app_handle = app.handle().clone();
            let _ = APP_HANDLE.set(app_handle.clone());

            // Initialize database: isolate development database from production database
            let app_folder = if cfg!(debug_assertions) { "mouzi-dev" } else { "mouzi" };
            if let Some(proj_dirs) = ProjectDirs::from("cc", "mouzi", app_folder) {
                let data_dir = proj_dirs.data_dir().to_path_buf();
                std::fs::create_dir_all(&data_dir).ok();
                init_db(data_dir.clone()).expect("Failed to initialize database");
                let _ = db::migrate_rules_to_relative();
            }

            // Set close prevention handler and restore position on popup window
            if let Some(window) = app.get_webview_window("popup") {
                let saved_pos = db::get_window_position().unwrap_or(None);
                if let Some((x, y)) = saved_pos {
                    let _ = window.set_position(tauri::PhysicalPosition::new(x, y));
                } else {
                    #[cfg(target_os = "windows")]
                    if let Ok(Some(monitor)) = app.primary_monitor() {
                        let size = monitor.size();
                        let pos = monitor.position();
                        let scale = monitor.scale_factor();
                        let win_w = (420.0 * scale) as i32;
                        let win_h = (620.0 * scale) as i32;
                        let margin_x = (24.0 * scale) as i32;
                        let margin_y = (64.0 * scale) as i32;
                        let _ = window.set_position(tauri::PhysicalPosition::new(
                            pos.x + size.width as i32 - win_w - margin_x,
                            pos.y + size.height as i32 - win_h - margin_y,
                        ));
                    }
                }
                let win_clone = window.clone();
                window.on_window_event(move |event| {
                    match event {
                        tauri::WindowEvent::CloseRequested { api, .. } => {
                            api.prevent_close();
                            if let Ok(pos) = win_clone.outer_position() {
                                let _ = db::save_window_position(pos.x, pos.y);
                            }
                            let _ = win_clone.hide();
                        }
                        tauri::WindowEvent::Moved(pos) => {
                            let _ = db::save_window_position(pos.x, pos.y);
                        }
                        _ => {}
                    }
                });
            }

            // Initialize default rules on first run
            let _is_first_run = if let Ok(settings) = db::get_settings() {
                let first = settings.first_run;
                if first {
                    let downloads = commands::get_downloads_folder();
                    let _ = db::add_watched_folder(&downloads, FOLDER_MODE_SILENT);
                    let _ = db::insert_default_rules(&downloads);
                    let mut new_settings = settings;
                    new_settings.first_run = false;
                    let _ = db::update_settings(&new_settings);
                }
                first
            } else {
                false
            };

            // Clean up legacy "Mouzi" autostart entry if present in Windows Registry
            #[cfg(target_os = "windows")]
            {
                use std::os::windows::process::CommandExt;
                const CREATE_NO_WINDOW: u32 = 0x08000000;
                let _ = std::process::Command::new("reg")
                    .args(["delete", "HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Run", "/v", "Mouzi", "/f"])
                    .creation_flags(CREATE_NO_WINDOW)
                    .output();
            }

            // Setup system tray
            let tray_lang = db::get_settings()
                .map(|s| s.language)
                .unwrap_or_else(|_| "es".to_string());
            tray::setup_tray(&app_handle, &tray_lang)?;

            // Show the popup on manual launch so the user sees the interface immediately.
            // On system startup or background launch, keep the application hidden in the tray.
            let is_autostart = std::env::args().any(|arg| is_silent_or_autostart(&arg));
            if !is_autostart {
                tray::show_popup_window(&app_handle);
            }

            // Sync autostart with user settings
            if let Ok(settings) = db::get_settings() {
                let auto_manager = app.autolaunch();
                if settings.autostart {
                    let _ = auto_manager.enable();
                } else {
                    let _ = auto_manager.disable();
                }
            }

            // Start folder watcher
            let state = app.state::<AppState>();
            {
                let mut watcher = state.watcher.lock().unwrap();
                let _ = watcher.watch_folders(app_handle.clone());
            }

            // Start scheduled-clean background thread
            state.scheduler.start(app_handle.clone());

            Ok(())
        })
        .invoke_handler(tauri::generate_handler![
            greet,
            get_system_language,
            get_rules_cmd,
            add_rule_cmd,
            update_rule_cmd,
            delete_rule_cmd,
            get_folders_cmd,
            add_folder_cmd,
            remove_folder_cmd,
            update_folder_mode_cmd,
            get_logs_cmd,
            get_stats_cmd,
            undo_action_cmd,
            undo_all_cmd,
            get_settings_cmd,
            update_settings_cmd,
            enable_autostart_cmd,
            disable_autostart_cmd,
            is_autostart_enabled_cmd,
            clear_logs_cmd,
            scan_folder_cmd,
            import_archive_cmd,
            open_folder_cmd,
            get_downloads_folder,
            initialize_defaults_cmd,
            close_popup,
            close_settings,
            show_notification,
            load_mouziignore_cmd,
            save_mouziignore_cmd,
            get_pending_open_folder_cmd,
            show_popup_cmd,
            show_settings_cmd,
            get_pending_files_cmd,
            refresh_watcher_cmd,
            get_schedule_cmd,
            update_schedule_cmd,
            get_version_cmd,
            export_rules_cmd,
            import_rules_cmd,
            get_preset_folders_cmd,
            set_view_mode_cmd,
            start_dragging_cmd,
            get_window_position_cmd,
            set_window_position_cmd,
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
