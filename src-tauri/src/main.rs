// Prevents console window on Windows in all profiles, DO NOT REMOVE!!
#![windows_subsystem = "windows"]

fn main() {
    // Work around WebKitGTK DMABuf renderer bug on Wayland.
    // Without this, GTK window creation fails with:
    //   "Error 71 (Protocol error) dispatching to Wayland display."
    // Upstream: https://bugs.webkit.org/show_bug.cgi?id=280210
    //           https://github.com/tauri-apps/tauri/issues/10702
    #[cfg(target_os = "linux")]
    if std::env::var("WEBKIT_DISABLE_DMABUF_RENDERER").is_err() {
        std::env::set_var("WEBKIT_DISABLE_DMABUF_RENDERER", "1");
    }

    #[cfg(target_os = "windows")]
    {
        use windows_sys::Win32::Foundation::{GetLastError, ERROR_ALREADY_EXISTS};
        use windows_sys::Win32::System::Threading::{
            CreateEventW, CreateMutexW, OpenEventW, SetEvent, EVENT_MODIFY_STATE, INFINITE,
        };

        let is_dev = cfg!(debug_assertions);
        let mutex_name: Vec<u16> = if is_dev {
            "Local\\MouziFlow_SingleInstance_Dev_Mutex\0".encode_utf16().collect()
        } else {
            "Local\\MouziFlow_SingleInstance_Release_Mutex\0".encode_utf16().collect()
        };
        let event_name: Vec<u16> = if is_dev {
            "Local\\MouziFlow_SingleInstance_Dev_Activate\0".encode_utf16().collect()
        } else {
            "Local\\MouziFlow_SingleInstance_Release_Activate\0".encode_utf16().collect()
        };

        unsafe {
            let _hmutex = CreateMutexW(std::ptr::null(), 0, mutex_name.as_ptr());
            if GetLastError() == ERROR_ALREADY_EXISTS {
                // Another instance is already running!
                // Signal the primary instance's event to wake it up and show the UI
                let hevent = OpenEventW(EVENT_MODIFY_STATE, 0, event_name.as_ptr());
                if hevent != std::ptr::null_mut() {
                    SetEvent(hevent);
                    windows_sys::Win32::Foundation::CloseHandle(hevent);
                }
                // Terminate this secondary process immediately with 0 delay and no duplicate process
                std::process::exit(0);
            }

            // Primary instance: create the event and listen in a background thread
            let hevent = CreateEventW(std::ptr::null(), 0, 0, event_name.as_ptr());
            if hevent != std::ptr::null_mut() {
                let event_addr = hevent as usize;
                std::thread::spawn(move || {
                    let hevent = event_addr as windows_sys::Win32::Foundation::HANDLE;
                    loop {
                        let res = windows_sys::Win32::System::Threading::WaitForSingleObject(hevent, INFINITE);
                        if res == 0 {
                            mouzi_lib::request_show_popup();
                        }
                    }
                });
            }
        }
    }

    mouzi_lib::run()
}
