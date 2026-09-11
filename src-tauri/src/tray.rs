use tauri::menu::{Menu, MenuItem, PredefinedMenuItem};
use tauri::tray::{MouseButton, TrayIconBuilder, TrayIconEvent};
use tauri::{AppHandle, Emitter, Manager};
use crate::db::{self, get_settings, get_watched_folders, is_folder_paused_mode};
use crate::i18n::TrayI18n;
use crate::rules::manual_scan_folder;

pub fn setup_tray(app: &AppHandle, lang: &str) -> Result<(), Box<dyn std::error::Error>> {
    let i18n = TrayI18n::new(lang);

    let quit_i = MenuItem::with_id(app, "quit", i18n.get("quit"), true, None::<&str>)?;
    let settings_i = MenuItem::with_id(app, "settings", i18n.get("settings"), true, None::<&str>)?;
    let clean_i = MenuItem::with_id(app, "clean", i18n.get("clean_now"), true, None::<&str>)?;
    let separator = PredefinedMenuItem::separator(app)?;

    let menu = Menu::with_items(app, &[&clean_i, &settings_i, &separator, &quit_i])?;

    let tooltip = if cfg!(debug_assertions) {
        format!("[DEV] {}", i18n.get("tooltip"))
    } else {
        i18n.get("tooltip").to_string()
    };
    let mut builder = TrayIconBuilder::with_id("tray")
        .tooltip(&tooltip)
        .menu(&menu)
        .on_menu_event(|app, event| match event.id.as_ref() {
            "quit" => {
                app.exit(0);
            }
            "settings" => {
                show_settings_window(app);
            }
            "clean" => {
                let _ = perform_clean(app);
            }
            _ => {}
        })
        .on_tray_icon_event(|tray, event| {
            if let TrayIconEvent::Click { button, .. } = event {
                if button == MouseButton::Left {
                    show_popup_window(tray.app_handle());
                }
            }
        });

    if let Some(icon) = app.default_window_icon() {
        builder = builder.icon(icon.clone());
    }

    let _tray = builder.build(app)?;

    Ok(())
}

fn tray_lang(_app: &AppHandle) -> String {
    get_settings()
        .map(|s| s.language)
        .unwrap_or_else(|_| "es".to_string())
}

pub fn show_popup_window(app: &AppHandle) {
    let i18n = TrayI18n::new(&tray_lang(app));
    if let Some(window) = app.get_webview_window("popup") {
        if let Ok(Some((x, y))) = db::get_window_position() {
            let _ = window.set_position(tauri::PhysicalPosition::new(x, y));
        }
        let _ = window.unminimize();
        let _ = window.show();
        let _ = window.set_focus();
    } else {
        let saved_pos = db::get_window_position().unwrap_or(None);

        #[cfg(target_os = "windows")]
        let (default_x, default_y) = if let Some((x, y)) = saved_pos {
            (x, y)
        } else if let Ok(Some(monitor)) = app.primary_monitor() {
            let size = monitor.size();
            let pos = monitor.position();
            let scale = monitor.scale_factor();
            let win_w = (420.0 * scale) as i32;
            let win_h = (620.0 * scale) as i32;
            let margin_x = (24.0 * scale) as i32;
            let margin_y = (64.0 * scale) as i32;
            (
                pos.x + size.width as i32 - win_w - margin_x,
                pos.y + size.height as i32 - win_h - margin_y,
            )
        } else {
            (600, 250)
        };

        #[cfg(not(target_os = "windows"))]
        let (default_x, default_y) = saved_pos.unwrap_or((100, 100));

        #[cfg(target_os = "macos")]
        let window = tauri::WebviewWindowBuilder::new(
            app,
            "popup",
            tauri::WebviewUrl::default(),
        )
        .title(i18n.get("popup_title"))
        .inner_size(420.0, 620.0)
        .min_inner_size(360.0, 500.0)
        .resizable(true)
        .decorations(false)
        .always_on_top(true)
        .shadow(false)
        .build();

        #[cfg(not(target_os = "macos"))]
        let window = tauri::WebviewWindowBuilder::new(
            app,
            "popup",
            tauri::WebviewUrl::default(),
        )
        .title(i18n.get("popup_title"))
        .inner_size(420.0, 620.0)
        .min_inner_size(360.0, 500.0)
        .position(default_x as f64, default_y as f64)
        .resizable(true)
        .decorations(false)
        .always_on_top(true)
        .skip_taskbar(false)
        .shadow(false)
        .build();

        if let Ok(win) = window {
            let win_clone = win.clone();
            win.on_window_event(move |event| {
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
            let _ = win.show();
            let _ = win.set_focus();
        }
    }
}

fn perform_clean(app: &AppHandle) -> Result<(), String> {
    let i18n = TrayI18n::new(&tray_lang(app));
    let folders = get_watched_folders().map_err(|e| e.to_string())?;
    let mut total = 0;
    for folder in folders {
        if !folder.enabled || is_folder_paused_mode(&folder.mode) { continue; }
        if let Ok(results) = manual_scan_folder(&folder.path) {
            total += results.len();
        }
    }
    if total > 0 {
        let msg = i18n.get("organized").replace("{}", &total.to_string());
        let _ = app.emit("show-notification", msg);
    }
    Ok(())
}

pub fn update_tray_tooltip(app: &AppHandle, count: usize) {
    let i18n = TrayI18n::new(&tray_lang(app));
    let base_tooltip = if count == 0 {
        i18n.get("tooltip").to_string()
    } else if count == 1 {
        i18n.get("tooltip_one_pending").replace("{}", "1")
    } else {
        i18n.get("tooltip_many_pending")
            .replace("{}", &count.to_string())
    };
    let tooltip = if cfg!(debug_assertions) {
        format!("[DEV] {}", base_tooltip)
    } else {
        base_tooltip
    };
    if let Some(tray) = app.tray_by_id("tray") {
        let _ = tray.set_tooltip(Some(&tooltip));
    }
}

pub fn show_settings_window(app: &AppHandle) {
    show_popup_window(app);
    if let Some(window) = app.get_webview_window("popup") {
        let _ = window.set_size(tauri::LogicalSize::new(820.0, 600.0));
        let _ = window.center();
        let _ = window.show();
        let _ = window.set_focus();
        let _ = app.emit("navigate-to-settings", ());
    }
}
