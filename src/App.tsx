import { useEffect, useState } from "react";
import { useTranslation } from "react-i18next";
import { initI18n, SupportedLang } from "./i18n";
import { useAppStore } from "./store/useAppStore";
import Popup from "./components/Popup";
import Settings from "./components/Settings";
import { listen } from "@tauri-apps/api/event";
import { invoke } from "@tauri-apps/api/core";
import { onAction } from "@tauri-apps/plugin-notification";

function applyTheme(theme: string) {
  const root = document.documentElement;
  if (theme === "dark") {
    root.classList.add("dark");
  } else if (theme === "light") {
    root.classList.remove("dark");
  } else {
    const prefersDark = window.matchMedia("(prefers-color-scheme: dark)").matches;
    if (prefersDark) {
      root.classList.add("dark");
    } else {
      root.classList.remove("dark");
    }
  }
}

function App() {
  const { t } = useTranslation();
  const [ready, setReady] = useState(true);
  const { loadSettings, settings, currentView, setCurrentView } = useAppStore();

  useEffect(() => {
    async function boot() {
      await loadSettings();
    }
    boot();
  }, [loadSettings]);

  useEffect(() => {
    if (!settings) return;
    const lang = (settings.language === "en" || !settings.language ? "es" : settings.language) as SupportedLang;
    initI18n(lang).then(() => setReady(true));
  }, [settings]);

  useEffect(() => {
    if (!settings) return;
    applyTheme(settings.theme);
  }, [settings?.theme]);

  useEffect(() => {
    const unlistenOrganized = listen("file-organized", (event) => {
      console.log("File organized:", event.payload);
      useAppStore.getState().loadLogs();
      useAppStore.getState().loadStats();
    });

    const unlistenToSettings = listen("navigate-to-settings", () => {
      setCurrentView("settings");
    });

    const unlistenToPopup = listen("navigate-to-popup", () => {
      setCurrentView("popup");
    });

    let actionListener: { unregister: () => Promise<void> } | null = null;

    // Listen for notification action clicks centrally
    onAction((notification) => {
      console.log("Notification click received:", notification);
      const destFolder = (notification.extra as Record<string, unknown> | undefined)?.destFolder as string | undefined;
      if (destFolder) {
        invoke("open_folder_cmd", { path: destFolder })
          .catch((e) => console.error("open_folder_cmd from onAction failed:", e));
      }
    }).then((listener) => {
      actionListener = listener;
    }).catch(console.error);

    const handleFocus = async () => {
      try {
        const folder = await invoke<string | null>("get_pending_open_folder_cmd");
        if (folder) {
          await invoke("open_folder_cmd", { path: folder }).catch(console.error);
        }
      } catch (e) {
        console.error("get_pending_open_folder_cmd error:", e);
      }
    };

    window.addEventListener("focus", handleFocus);

    return () => {
      unlistenOrganized.then((f) => f());
      unlistenToSettings.then((f) => f());
      unlistenToPopup.then((f) => f());
      window.removeEventListener("focus", handleFocus);
      if (actionListener) {
        actionListener.unregister().catch(console.error);
      }
    };
  }, [setCurrentView]);

  if (!ready) {
    return (
      <div className="flex h-full items-center justify-center bg-surface text-text">
        <div className="animate-pulse text-sm">{t("app.loading")}</div>
      </div>
    );
  }

  return (
    <div className="h-full w-full bg-surface text-text rounded-xl border border-border shadow-xl overflow-hidden flex flex-col select-none">
      {currentView === "settings" ? <Settings /> : <Popup />}
    </div>
  );
}

export default App;
