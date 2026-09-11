import { useEffect, useState } from "react";
import { useTranslation } from "react-i18next";
import { useAppStore } from "../store/useAppStore";
import {
  Folder,
  FolderOpen,
  FolderPlus,
  Sparkles,
  RotateCcw,
  X,
  FileText,
  Image,
  Music,
  Video,
  Archive,
  Package,
  File,
  ExternalLink,
  Inbox,
  Settings as SettingsIcon,
} from "lucide-react";
import { invoke } from "@tauri-apps/api/core";
import { listen } from "@tauri-apps/api/event";
import { open } from "@tauri-apps/plugin-dialog";

function getIconForType(typeName: string) {
  const lower = typeName.toLowerCase();
  if (lower.includes("image")) return <Image size={14} />;
  if (lower.includes("music")) return <Music size={14} />;
  if (lower.includes("video")) return <Video size={14} />;
  if (lower.includes("archive")) return <Archive size={14} />;
  if (lower.includes("install")) return <Package size={14} />;
  if (lower.includes("document")) return <FileText size={14} />;
  return <File size={14} />;
}

import { getSmartFolderName } from "../utils/folderName";
import { handleWindowDrag } from "../utils/windowDrag";
import CustomSelect from "./ui/CustomSelect";

function getFolderFromPath(filePath: string | null | undefined): string | null {
  if (!filePath) return null;
  const lastSlash = Math.max(filePath.lastIndexOf("/"), filePath.lastIndexOf("\\"));
  if (lastSlash === -1) return filePath;
  return filePath.slice(0, lastSlash) || filePath;
}

export default function Popup() {
  const { t } = useTranslation();
  const {
    logs,
    stats,
    isLoading,
    loadLogs,
    loadStats,
    loadFolders,
    scanFolder,
    undoAction,
    folders,
    addFolders,
    pendingFiles,
    getPendingFiles,
  } = useAppStore();

  const [selectedFolderTarget, setSelectedFolderTarget] = useState<string>("all");
  const [scanResults, setScanResults] = useState<
    { file: string; rule: string; destination: string }[]
  >([]);
  const [toast, setToast] = useState<{
    file: string;
    rule: string;
    destination: string;
    destination_folder: string;
  } | null>(null);

  useEffect(() => {
    loadLogs();
    loadStats();
    loadFolders();
    getPendingFiles();

    // Listen for file-organized events from Rust watcher — show in-app toast
    const unlisten = listen("file-organized", (event: any) => {
      const payload = event.payload;
      if (payload?.success) {
        const destFolder: string = payload.destination_folder || payload.destination;
        setToast({
          file: payload.file,
          rule: payload.rule,
          destination: payload.destination,
          destination_folder: destFolder,
        });
        setTimeout(() => setToast(null), 30000);
        loadLogs();
        loadStats();
        getPendingFiles();
      }
    });

    // Poll for pending files in manual-mode folders
    const interval = setInterval(() => {
      getPendingFiles();
    }, 3000);

    return () => {
      unlisten.then((f) => f());
      clearInterval(interval);
    };
  }, [loadLogs, loadStats, loadFolders, getPendingFiles]);

  const handleClean = async () => {
    let allResults: { file: string; rule: string; destination: string }[] = [];
    const activeFolders = folders.filter((f) => f.mode !== "paused");

    let targets: string[] = [];
    if (selectedFolderTarget === "all") {
      targets = activeFolders.length > 0 ? activeFolders.map((f) => f.path) : [await invoke<string>("get_downloads_folder")];
    } else {
      targets = [selectedFolderTarget];
    }

    for (const path of targets) {
      const results = await scanFolder(path);
      allResults = allResults.concat(results);
    }
    setScanResults(allResults);
    await getPendingFiles();
    if (allResults.length > 0) {
      await invoke("show_notification", {
        title: t("app.name"),
        body: t("notifications.cleaned", { count: allResults.length }),
      });
    }
  };

  const handleOpenFolder = async () => {
    let targetPath = selectedFolderTarget;
    if (targetPath === "all") {
      targetPath = folders[0]?.path || (await invoke<string>("get_downloads_folder"));
    }
    if (targetPath) {
      await invoke("open_folder_cmd", { path: targetPath });
    }
  };

  const handleQuickAddFolder = async () => {
    try {
      const selected = await open({
        directory: true,
        multiple: true,
      });
      if (!selected) return;
      const paths = Array.isArray(selected) ? selected : [selected];
      await addFolders(paths, "silent");
      if (paths.length > 0) {
        setSelectedFolderTarget(paths[0]);
      }
    } catch (e) {
      console.error("Failed to add folder from popup:", e);
    }
  };

  const { setCurrentView } = useAppStore();

  const handleOpenSettings = async () => {
    setCurrentView("settings");
    await invoke("set_view_mode_cmd", { mode: "settings" }).catch(console.error);
  };

  const handleOpenActionFolder = async (filePath: string | null | undefined) => {
    const folderPath = getFolderFromPath(filePath);
    if (!folderPath) return;
    try {
      await invoke("open_folder_cmd", { path: folderPath });
    } catch {
      console.error("Failed to open folder");
    }
  };

  const handleQuit = () => {
    invoke("close_popup");
  };

  const totalStats = stats.reduce((sum, s) => sum + s.count, 0);

  const selectedFolderName =
    selectedFolderTarget === "all"
      ? t("popup.allFolders")
      : getSmartFolderName(selectedFolderTarget, folders);

  return (
    <div className="flex h-full flex-col bg-surface text-text overflow-hidden select-none">
      {/* Header */}
      <div
        data-tauri-drag-region="deep"
        onMouseDown={handleWindowDrag}
        onPointerDown={handleWindowDrag}
        className="flex items-center justify-between px-4 py-3 bg-surface-dark border-b border-border select-none cursor-grab active:cursor-grabbing"
      >
        <div
          data-tauri-drag-region="deep"
          className="flex items-center gap-2 cursor-grab active:cursor-grabbing"
        >
          <Sparkles size={16} className="text-primary pointer-events-none" />
          <span data-tauri-drag-region="deep" className="font-semibold text-sm">{t("popup.title")}</span>
        </div>

        {/* Drag handle indicator */}
        <div
          data-tauri-drag-region="deep"
          className="flex-1 flex justify-center py-1 cursor-grab active:cursor-grabbing"
        >
          <div
            data-tauri-drag-region="deep"
            className="w-10 h-1.5 rounded-full bg-border hover:bg-primary/50 transition-colors cursor-grab active:cursor-grabbing"
          />
        </div>

        <div className="flex items-center gap-1" data-no-drag data-tauri-drag-region="false">
          <button
            data-no-drag
            data-tauri-drag-region="false"
            onClick={handleOpenSettings}
            className="p-1.5 rounded-md hover:bg-border text-text-muted hover:text-text transition-colors"
            title={t("popup.settings")}
          >
            <SettingsIcon size={14} />
          </button>
          <button
            data-no-drag
            data-tauri-drag-region="false"
            onClick={handleQuit}
            className="p-1.5 rounded-md hover:bg-border text-text-muted hover:text-text transition-colors"
            title={t("popup.quit")}
          >
            <X size={14} />
          </button>
        </div>
      </div>

      {/* Main Actions Area */}
      <div className="p-3 space-y-2">
        {/* Clean Now Main Button */}
        <button
          onClick={handleClean}
          disabled={isLoading}
          className="w-full flex items-center justify-center gap-2 rounded-lg bg-primary px-3 py-2.5 text-sm font-medium text-white hover:bg-primary-hover shadow-sm transition-colors disabled:opacity-60"
        >
          <Sparkles size={15} />
          <span>
            {isLoading
              ? "..."
              : selectedFolderTarget === "all"
              ? t("popup.cleanNow")
              : `${t("popup.cleanManual")} (${selectedFolderName})`}
          </span>
        </button>

        {/* Add Folders To Organize Button */}
        <button
          onClick={handleQuickAddFolder}
          className="w-full flex items-center justify-center gap-2 rounded-lg border border-border bg-surface px-3 py-2 text-xs font-medium hover:bg-surface-dark transition-colors text-text shadow-sm"
        >
          <FolderPlus size={15} className="text-primary shrink-0" />
          <span>{t("popup.addFoldersToOrganize")}</span>
        </button>

        {/* Folder Selector & Open Folder quick toolbar if folders exist */}
        {folders.length > 0 && (
          <div className="flex items-center gap-1.5 pt-1">
            <CustomSelect
              value={selectedFolderTarget}
              onChange={(val) => setSelectedFolderTarget(val)}
              options={[
                {
                  value: "all",
                  label: `${t("popup.allFolders")} (${folders.length})`,
                  icon: <Folder size={13} className="text-primary shrink-0" />,
                },
                ...folders.map((f) => ({
                  value: f.path,
                  label: getSmartFolderName(f.path, folders),
                  description:
                    f.mode === "paused"
                      ? `${f.path} • (${t("settings.folders.modePaused")})`
                      : f.path,
                  icon: <Folder size={13} className="text-text-muted shrink-0" />,
                })),
              ]}
              className="flex-1"
            />
            <button
              onClick={handleOpenFolder}
              className="p-1.5 rounded-md border border-border bg-surface hover:bg-surface-dark text-text-muted hover:text-text transition-colors shrink-0"
              title={t("popup.openDownloads")}
            >
              <FolderOpen size={13} />
            </button>
          </div>
        )}

        {pendingFiles.length > 0 && (
          <div className="text-center text-xs text-primary font-medium">
            {t("popup.pendingFiles", { count: pendingFiles.length })}
          </div>
        )}
      </div>

      {/* Recent Actions List */}
      <div className="flex-1 overflow-auto px-3">
        <div className="text-xs font-semibold text-text-muted uppercase tracking-wider mb-2">
          {t("popup.recentActions")}
        </div>
        {logs.length === 0 ? (
          <div className="flex flex-col items-center justify-center py-6 text-sm text-text-muted">
            <Inbox size={28} className="mb-2 opacity-60" />
            {t("popup.noActions")}
          </div>
        ) : (
          <div className="space-y-1.5">
            {logs.slice(0, 5).map((log) => (
              <div
                key={log.id}
                className="flex items-center gap-2 rounded-md bg-surface-dark px-2.5 py-2 text-xs"
              >
                <span className="text-text-muted shrink-0">
                  {getIconForType(log.file_type)}
                </span>
                <span className="flex-1 truncate" title={log.file_name}>
                  {log.file_name}
                </span>
                <span className="text-text-muted truncate max-w-[80px]">
                  {log.file_type}
                </span>
                {!log.undone && log.id && (
                  <>
                    <button
                      onClick={() => handleOpenActionFolder(log.destination_path)}
                      className="p-1 rounded hover:bg-border text-text-muted hover:text-text transition-colors"
                      title="Open folder"
                    >
                      <FolderOpen size={12} />
                    </button>
                    <button
                      onClick={() => undoAction(log.id!)}
                      className="p-1 rounded hover:bg-border text-text-muted hover:text-text transition-colors"
                      title={t("popup.undo")}
                    >
                      <RotateCcw size={12} />
                    </button>
                  </>
                )}
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Weekly Stats */}
      {stats.length > 0 && (
        <div className="border-t border-border p-3">
          <div className="text-xs font-semibold text-text-muted uppercase tracking-wider mb-2">
            {t("popup.weeklyStats")}
          </div>
          <div className="space-y-1.5">
            {stats.map((s) => {
              const pct = totalStats > 0 ? Math.round((s.count / totalStats) * 100) : 0;
              return (
                <div key={s.file_type} className="flex items-center gap-2 text-xs">
                  <span className="w-16 truncate text-text-muted">{s.file_type}</span>
                  <div className="flex-1 h-1.5 bg-border rounded-full overflow-hidden">
                    <div
                      className="h-full bg-primary rounded-full transition-all"
                      style={{ width: `${pct}%` }}
                    />
                  </div>
                  <span className="w-8 text-right text-text-muted">{pct}%</span>
                </div>
              );
            })}
          </div>
        </div>
      )}

      {/* Clickable toast for auto-organized files */}
      {toast && (
        <div className="px-3 pb-2">
          <div
            onPointerDown={async () => {
              try {
                await invoke("open_folder_cmd", { path: toast.destination_folder });
              } catch {
                console.error("Failed to open folder");
              }
              setToast(null);
            }}
            className="w-full text-left rounded-lg bg-primary/10 border border-primary/20 px-3 py-2 text-xs hover:bg-primary/20 transition-colors cursor-pointer"
            role="button"
          >
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-1.5 text-primary">
                <ExternalLink size={12} />
                <span className="font-medium">{t("popup.organized", { file: toast.file })}</span>
              </div>
              <button
                onClick={(e) => {
                  e.stopPropagation();
                  setToast(null);
                }}
                className="p-0.5 rounded hover:bg-primary/20 text-primary"
              >
                <X size={10} />
              </button>
            </div>
            <div className="text-text-muted mt-0.5 truncate">
              {t("popup.openFolder", { folder: toast.destination_folder })}
            </div>
          </div>
        </div>
      )}

      {/* Scan results toast */}
      {scanResults.length > 0 && (
        <div className="px-3 pb-3">
          <div className="rounded-lg bg-primary/10 border border-primary/20 px-3 py-2 text-xs text-primary font-medium">
            {t("notifications.cleaned", { count: scanResults.length })}
          </div>
        </div>
      )}
    </div>
  );
}

