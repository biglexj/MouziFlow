import { useEffect, useMemo, useState } from "react";
import { useTranslation } from "react-i18next";
import { useAppStore, Rule, ScheduleSettings } from "../store/useAppStore";
import { invoke } from "@tauri-apps/api/core";
import { save, open } from "@tauri-apps/plugin-dialog";
import About from "./About";
import Partners from "./Partners";
import {
  Folder,
  FolderOpen,
  List,
  History,
  Inbox,
  Globe,
  Plus,
  Trash2,
  Save,
  X,
  Check,
  ChevronLeft,
  RotateCcw,
  Download,
  Upload,
  Info,
  ExternalLink,
  Sparkles,
  Award,
} from "lucide-react";


import { getSmartFolderName } from "../utils/folderName";
import { handleWindowDrag } from "../utils/windowDrag";
import CustomSelect from "./ui/CustomSelect";

type Tab = "folders" | "rules" | "history" | "ignore" | "general" | "partners" | "about";
type GraceUnit = "seconds" | "minutes" | "hours";
type ArchiveImportResult = {
  extractedCount: number;
  sortedCount: number;
  stagingPath: string;
};

const GRACE_STEPS = [
  0, 30, 60, 300, 900, 1800, 3600, 7200, 21600, 43200, 86400, 172800, 604800,
];
const MAX_GRACE_SECONDS = 604800; // 7 days

function formatDuration(seconds: number): string {
  if (seconds <= 0) return "0s";
  const hours = Math.floor(seconds / 3600);
  const minutes = Math.floor((seconds % 3600) / 60);
  const secs = seconds % 60;
  const parts: string[] = [];
  if (hours > 0) parts.push(`${hours}h`);
  if (minutes > 0) parts.push(`${minutes}m`);
  if (secs > 0) parts.push(`${secs}s`);
  return parts.join(" ") || "0s";
}

function secondsToUnit(seconds: number): { value: number; unit: GraceUnit } {
  if (seconds % 3600 === 0 && seconds >= 3600) {
    return { value: seconds / 3600, unit: "hours" };
  }
  if (seconds % 60 === 0 && seconds >= 60) {
    return { value: seconds / 60, unit: "minutes" };
  }
  return { value: seconds, unit: "seconds" };
}

function unitToSeconds(value: number, unit: GraceUnit): number {
  switch (unit) {
    case "hours":
      return value * 3600;
    case "minutes":
      return value * 60;
    default:
      return value;
  }
}

function nearestGraceStep(seconds: number): number {
  return GRACE_STEPS.reduce((prev, curr) =>
    Math.abs(curr - seconds) < Math.abs(prev - seconds) ? curr : prev
  );
}

function getDirectoryFromPath(filePath: string | null): string | null {
  if (!filePath) return null;
  const normalized = filePath.replace(/\\/g, "/");
  const lastSlash = normalized.lastIndexOf("/");
  if (lastSlash <= 0) return normalized;
  return normalized.slice(0, lastSlash);
}

function defaultSchedule(): ScheduleSettings {
  return {
    schedule_enabled: false,
    schedule_times_per_day: 1,
    schedule_time_1: "08:00",
    schedule_time_2: null,
    schedule_time_3: null,
    schedule_time_4: null,
  };
}

export default function Settings() {
  const { t, i18n } = useTranslation();
  const {
    rules,
    folders,
    presetFolders,
    logs,
    loadRules,
    loadFolders,
    loadPresetFolders,
    loadLogs,
    addFolder,
    addFolders,
    removeFolder,
    updateFolderMode,
    addRule,
    updateRule,
    deleteRule,
    clearLogs,
    undoAction,
    undoAll,
    scanFolder,
    settings,
    saveSettings,
    setAutostart,
    schedule,
    getSchedule,
    updateSchedule,
    exportRules,
    importRules,
  } = useAppStore();

  const [tab, setTab] = useState<Tab>("folders");
  const [editingRule, setEditingRule] = useState<Rule | null>(null);
  const [newFolderPath, setNewFolderPath] = useState("");
  const [selectedFolderFilter, setSelectedFolderFilter] = useState<string>("all");
  const [ignoreTargetFolder, setIgnoreTargetFolder] = useState<string>("");

  const [graceValue, setGraceValue] = useState(300);
  const [graceUnit, setGraceUnit] = useState<GraceUnit>("seconds");
  const [graceError, setGraceError] = useState<string | null>(null);

  const [localSchedule, setLocalSchedule] = useState<ScheduleSettings>(defaultSchedule());
  const [ruleToast, setRuleToast] = useState<{ message: string; type: "success" | "error" } | null>(null);
  const [folderToast, setFolderToast] = useState<{ message: string; type: "success" | "error"; folderId?: number } | null>(null);
  const [cleaningFolderId, setCleaningFolderId] = useState<number | null>(null);
  const [replaceOnImport, setReplaceOnImport] = useState(false);
  const [archiveToast, setArchiveToast] = useState<{
    message: string;
    type: "success" | "error" | "info";
    stagingPath?: string;
  } | null>(null);
  const [isImportingArchive, setIsImportingArchive] = useState(false);

  useEffect(() => {
    loadRules();
    loadFolders();
    loadPresetFolders();
    loadLogs();
    getSchedule();
  }, [loadRules, loadFolders, loadPresetFolders, loadLogs, getSchedule]);

  // Sync local grace editor with loaded settings
  useEffect(() => {
    if (settings) {
      const clamped = Math.min(settings.grace_period_seconds, MAX_GRACE_SECONDS);
      const converted = secondsToUnit(clamped);
      setGraceValue(converted.value);
      setGraceUnit(converted.unit);
      setGraceError(null);
    }
  }, [settings?.grace_period_seconds]);

  // Sync local schedule editor with loaded schedule
  useEffect(() => {
    if (schedule) {
      setLocalSchedule(schedule);
    }
  }, [schedule]);

  const handleAddFolder = async () => {
    if (!newFolderPath.trim()) return;
    await addFolder(newFolderPath.trim(), "silent");
    setNewFolderPath("");
  };

  const handleBrowseFolder = async () => {
    try {
      const selected = await open({
        directory: true,
        multiple: true,
      });
      if (!selected) return;
      const paths = Array.isArray(selected) ? selected : [selected];
      await addFolders(paths, "silent");
    } catch (e) {
      console.error("Browse folder failed:", e);
    }
  };

  const handleBrowseDestination = async () => {
    if (!editingRule) return;
    try {
      const selected = await open({
        directory: true,
        multiple: false,
      });
      const dest = Array.isArray(selected) ? selected[0] : selected;
      if (dest) {
        setEditingRule({ ...editingRule, destination: dest });
      }
    } catch (e) {
      console.error("Browse destination failed:", e);
    }
  };

  const handleCleanFolder = async (f: { id?: number; path: string }) => {
    if (!f.id) return;
    setCleaningFolderId(f.id);
    try {
      const results = await scanFolder(f.path);
      setFolderToast({
        message: t("notifications.cleaned", { count: results.length }),
        type: "success",
        folderId: f.id,
      });
    } catch (e) {
      setFolderToast({
        message: String(e),
        type: "error",
        folderId: f.id,
      });
    } finally {
      setCleaningFolderId(null);
      setTimeout(() => setFolderToast(null), 3000);
    }
  };

  const handleSaveRule = async () => {
    if (!editingRule) return;
    if (editingRule.id) {
      await updateRule(editingRule);
    } else {
      await addRule(editingRule);
    }
    setEditingRule(null);
  };

  const handleChangeLanguage = async (lang: string) => {
    if (!settings) return;
    await i18n.changeLanguage(lang);
    await saveSettings({ ...settings, language: lang });
  };

  const handleGraceSliderChange = (stepIndex: number) => {
    if (!settings) return;
    const seconds = GRACE_STEPS[stepIndex];
    const converted = secondsToUnit(seconds);
    setGraceValue(converted.value);
    setGraceUnit(converted.unit);
    setGraceError(null);
    saveSettings({ ...settings, grace_period_seconds: seconds });
  };

  const handleGraceNumberChange = (value: number, unit: GraceUnit) => {
    if (!settings) return;
    const seconds = unitToSeconds(value, unit);
    if (seconds > MAX_GRACE_SECONDS) {
      setGraceError(t("settings.general.gracePeriodMaxError"));
      setGraceValue(value);
      setGraceUnit(unit);
      return;
    }
    setGraceError(null);
    setGraceValue(value);
    setGraceUnit(unit);
    saveSettings({ ...settings, grace_period_seconds: Math.max(0, seconds) });
  };

  const handleScheduleChange = (patch: Partial<ScheduleSettings>) => {
    setLocalSchedule((prev) => {
      const next = { ...prev, ...patch };
      const times = Math.max(1, Math.min(4, next.schedule_times_per_day || 1));
      // Ensure required time slots have defaults when increasing count
      if (times >= 1 && !next.schedule_time_1) next.schedule_time_1 = "08:00";
      if (times >= 2 && !next.schedule_time_2) next.schedule_time_2 = "14:00";
      if (times >= 3 && !next.schedule_time_3) next.schedule_time_3 = "20:00";
      if (times >= 4 && !next.schedule_time_4) next.schedule_time_4 = "23:00";
      return { ...next, schedule_times_per_day: times };
    });
  };

  const handleSaveSchedule = async () => {
    try {
      await updateSchedule(localSchedule);
    } catch (e) {
      console.error("Failed to save schedule:", e);
    }
  };

  const handleExportRules = async () => {
    try {
      const path = await save({
        filters: [{ name: "JSON", extensions: ["json"] }],
        defaultPath: "mouzi-rules.json",
      });
      if (path) {
        await exportRules(path);
        setRuleToast({ message: t("settings.rules.exportSuccess"), type: "success" });
      }
    } catch (e) {
      console.error("Export rules failed:", e);
      setRuleToast({ message: t("settings.rules.exportError"), type: "error" });
    }
    setTimeout(() => setRuleToast(null), 3000);
  };

  const handleImportRules = async () => {
    try {
      const selected = await open({
        filters: [{ name: "JSON", extensions: ["json"] }],
        multiple: false,
      });
      const path = Array.isArray(selected) ? selected[0] : selected;
      if (path) {
        const count = await importRules(path, replaceOnImport);
        setRuleToast({
          message: t("settings.rules.importSuccess", { count }),
          type: "success",
        });
      }
    } catch (e) {
      console.error("Import rules failed:", e);
      setRuleToast({ message: t("settings.rules.importError"), type: "error" });
    }
    setTimeout(() => setRuleToast(null), 3000);
  };

  const handleImportArchive = async () => {
    try {
      const selected = await open({
        filters: [{ name: "Archives", extensions: ["zip", "tgz", "gz"] }],
        multiple: false,
      });
      const path = Array.isArray(selected) ? selected[0] : selected;
      if (!path) return;

      setIsImportingArchive(true);
      setArchiveToast({ message: t("settings.archive.importing"), type: "info" });

      const summary = await invoke<ArchiveImportResult>("import_archive_cmd", { path });
      await loadLogs();
      setArchiveToast({
        message: t("settings.archive.importSuccess", {
          count: summary.sortedCount,
          extracted: summary.extractedCount,
        }),
        type: "success",
        stagingPath: summary.stagingPath,
      });
    } catch (e) {
      console.error("Import archive failed:", e);
      setArchiveToast({
        message: t("settings.archive.importError", { error: String(e) }),
        type: "error",
      });
    } finally {
      setIsImportingArchive(false);
    }
  };

  const currentGraceSeconds = useMemo(
    () => unitToSeconds(graceValue, graceUnit),
    [graceValue, graceUnit]
  );

  const sliderIndex = useMemo(() => {
    const clamped = Math.min(currentGraceSeconds, MAX_GRACE_SECONDS);
    const nearest = nearestGraceStep(clamped);
    return GRACE_STEPS.indexOf(nearest);
  }, [currentGraceSeconds]);

  const filteredRules = useMemo(() => {
    if (selectedFolderFilter === "all") return rules;
    if (selectedFolderFilter === "0") return rules.filter((r) => r.folder_id === 0);
    const fid = Number(selectedFolderFilter);
    return rules.filter((r) => r.folder_id === fid);
  }, [rules, selectedFolderFilter]);

  const getFolderName = (folderPath: string) => {
    return getSmartFolderName(folderPath, folders);
  };

  const { setCurrentView } = useAppStore();

  const handleBack = async () => {
    setCurrentView("popup");
    await invoke("set_view_mode_cmd", { mode: "popup" }).catch(console.error);
  };

  const handleClose = () => {
    invoke("close_popup").catch(console.error);
  };

  return (
    <div className="flex h-full bg-surface text-text overflow-hidden">
      {/* Sidebar */}
      <div className="w-56 border-r border-border bg-surface-dark flex flex-col">
        <div
          data-tauri-drag-region
          onMouseDown={handleWindowDrag}
          className="px-4 py-4 flex items-center justify-between border-b border-border/40 select-none cursor-grab active:cursor-grabbing"
        >
          <div data-tauri-drag-region className="flex items-center gap-2">
            <button
              data-no-drag
              data-tauri-drag-region="false"
              onClick={handleBack}
              className="p-1.5 rounded-md hover:bg-border transition-colors text-text-muted hover:text-text"
              title="Volver"
            >
              <ChevronLeft size={16} />
            </button>
            <span data-tauri-drag-region className="font-semibold text-sm pointer-events-none">{t("settings.title")}</span>
          </div>
          <button
            data-no-drag
            data-tauri-drag-region="false"
            onClick={handleClose}
            className="p-1.5 rounded-md hover:bg-border transition-colors text-text-muted hover:text-text"
            title="Cerrar"
          >
            <X size={14} />
          </button>
        </div>
        <nav className="flex-1 px-2 py-2 space-y-0.5">
          <SidebarButton
            active={tab === "folders"}
            onClick={() => setTab("folders")}
            icon={<Folder size={16} />}
            label={t("settings.folders.title")}
          />
          <SidebarButton
            active={tab === "rules"}
            onClick={() => setTab("rules")}
            icon={<List size={16} />}
            label={t("settings.rules.title")}
          />
          <SidebarButton
            active={tab === "history"}
            onClick={() => setTab("history")}
            icon={<History size={16} />}
            label={t("settings.history.title")}
          />
          <SidebarButton
            active={tab === "ignore"}
            onClick={() => setTab("ignore")}
            icon={<X size={16} />}
            label={t("settings.ignore.title")}
          />
          <SidebarButton
            active={tab === "general"}
            onClick={() => setTab("general")}
            icon={<Globe size={16} />}
            label={t("settings.general.title")}
          />
          <SidebarButton
            active={tab === "partners"}
            onClick={() => setTab("partners")}
            icon={<Award size={16} />}
            label={t("settings.partners.title", "Partner y Aportes")}
          />
          <SidebarButton
            active={tab === "about"}
            onClick={() => setTab("about")}
            icon={<Info size={16} />}
            label={t("settings.about.title")}
          />
        </nav>
      </div>

      {/* Content */}
      <div className="flex-1 overflow-auto p-6">
        {tab === "folders" && (
          <div className="space-y-5">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <div>
                <h2 className="text-lg font-semibold">{t("settings.folders.title")}</h2>
                <p className="text-xs text-text-muted mt-0.5">
                  {t("settings.folders.modeDesc")}
                </p>
              </div>
              <button
                onClick={handleBrowseFolder}
                className="flex items-center gap-1.5 rounded-md bg-primary px-3.5 py-2 text-sm font-medium text-white hover:bg-primary-hover shadow-sm transition-colors shrink-0"
              >
                <FolderOpen size={15} />
                {t("settings.folders.browse")}
              </button>
            </div>

            {/* Quick add manual path input */}
            <div className="flex gap-2">
              <input
                type="text"
                value={newFolderPath}
                onChange={(e) => setNewFolderPath(e.target.value)}
                onKeyDown={(e) => e.key === "Enter" && handleAddFolder()}
                placeholder={t("settings.folders.placeholder")}
                className="flex-1 rounded-md border border-border bg-surface px-3 py-2 text-sm outline-none focus:border-primary"
              />
              <button
                onClick={handleAddFolder}
                disabled={!newFolderPath.trim()}
                className="flex items-center gap-1.5 rounded-md border border-border bg-surface px-3 py-2 text-sm font-medium hover:bg-surface-dark disabled:opacity-50 transition-colors"
              >
                <Plus size={14} />
                {t("settings.folders.add")}
              </button>
            </div>

            {/* Presets Chips */}
            {presetFolders.length > 0 && (
              <div className="rounded-lg border border-border/80 bg-surface-dark/50 p-3">
                <div className="text-xs font-semibold text-text-muted uppercase tracking-wider mb-2">
                  {t("settings.folders.quickPresets")}
                </div>
                <div className="flex flex-wrap gap-2">
                  {presetFolders.map((p) => {
                    const isAdded = folders.some((f) => f.path.toLowerCase() === p.path.toLowerCase());
                    return (
                      <button
                        key={p.path}
                        onClick={() => !isAdded && addFolder(p.path, "silent")}
                        disabled={isAdded}
                        className={`inline-flex items-center gap-1.5 rounded-full px-3 py-1 text-xs font-medium border transition-colors ${
                          isAdded
                            ? "border-border bg-surface text-text-muted opacity-60 cursor-default"
                            : "border-primary/30 bg-primary/10 text-primary hover:bg-primary/20"
                        }`}
                      >
                        <Folder size={12} />
                        <span>{p.name}</span>
                        {isAdded ? (
                          <Check size={11} className="text-primary ml-0.5" />
                        ) : (
                          <Plus size={11} className="ml-0.5" />
                        )}
                      </button>
                    );
                  })}
                </div>
              </div>
            )}

            {/* Folder action feedback toast */}
            {folderToast && (
              <div
                className={`text-xs px-3 py-2 rounded-md ${
                  folderToast.type === "success"
                    ? "bg-green-50 text-green-700 border border-green-200"
                    : "bg-red-50 text-red-700 border border-red-200"
                }`}
              >
                {folderToast.message}
              </div>
            )}

            {/* Watched Folders List */}
            <div className="space-y-3">
              {folders.length === 0 ? (
                <div className="flex flex-col items-center justify-center py-10 rounded-lg border border-dashed border-border bg-surface-dark/30 text-text-muted">
                  <FolderOpen size={36} className="mb-2 opacity-50" />
                  <p className="text-sm font-medium">{t("settings.folders.empty")}</p>
                  <button
                    onClick={handleBrowseFolder}
                    className="mt-3 flex items-center gap-1.5 rounded-md bg-primary px-3 py-1.5 text-xs font-medium text-white hover:bg-primary-hover"
                  >
                    <Plus size={13} />
                    {t("settings.folders.browse")}
                  </button>
                </div>
              ) : (
                folders.map((f) => {
                  const folderName = getFolderName(f.path);
                  const isCleaning = cleaningFolderId === f.id;
                  return (
                    <div
                      key={f.id}
                      className="rounded-lg border border-border bg-surface-dark/40 p-4 space-y-3 hover:border-border-hover transition-colors"
                    >
                      <div className="flex items-start justify-between gap-3">
                        <div className="flex items-center gap-2.5 min-w-0 flex-1">
                          <div className="p-2 rounded-lg bg-primary/10 text-primary shrink-0">
                            <Folder size={18} />
                          </div>
                          <div className="min-w-0 flex-1">
                            <div className="flex items-center gap-2">
                              <span className="text-sm font-semibold truncate">{folderName}</span>
                              <span
                                className={`text-[10px] px-2 py-0.5 rounded-full font-medium ${
                                  f.mode === "silent"
                                    ? "bg-teal-500/15 text-teal-700 dark:text-teal-300 border border-teal-500/20"
                                    : f.mode === "manual"
                                    ? "bg-cyan-500/15 text-cyan-700 dark:text-cyan-300 border border-cyan-500/20"
                                    : "bg-zinc-200 text-zinc-700 dark:bg-zinc-800 dark:text-zinc-400"
                                }`}
                              >
                                {f.mode === "silent"
                                  ? t("settings.folders.modeSilent")
                                  : f.mode === "manual"
                                  ? t("settings.folders.modeManual")
                                  : t("settings.folders.modePaused")}
                              </span>
                            </div>
                            <div className="text-xs text-text-muted font-mono truncate mt-0.5" title={f.path}>
                              {f.path}
                            </div>
                          </div>
                        </div>

                        <button
                          onClick={() => f.id && removeFolder(f.id)}
                          className="p-1.5 rounded-md text-text-muted hover:text-red-500 hover:bg-red-50 dark:hover:bg-red-950/40 shrink-0 transition-colors"
                          title={t("settings.folders.remove")}
                        >
                          <Trash2 size={15} />
                        </button>
                      </div>

                      <div className="flex flex-wrap items-center justify-between gap-2 pt-2 border-t border-border/60">
                        {/* Mode selector */}
                        <div className="flex items-center gap-2">
                          <span className="text-xs text-text-muted">{t("settings.folders.mode")}:</span>
                          <CustomSelect
                            value={f.mode || "silent"}
                            onChange={(val) => f.id && updateFolderMode(f.id, val)}
                            options={[
                              { value: "silent", label: t("settings.folders.modeSilent") },
                              { value: "manual", label: t("settings.folders.modeManual") },
                              { value: "paused", label: t("settings.folders.modePaused") },
                            ]}
                            className="w-28"
                          />
                        </div>

                        {/* Actions for this specific folder */}
                        <div className="flex items-center gap-1.5">
                          <button
                            onClick={() => handleCleanFolder(f)}
                            disabled={isCleaning || f.mode === "paused"}
                            className="flex items-center gap-1 rounded-md border border-border bg-surface px-2.5 py-1 text-xs font-medium hover:bg-surface-dark disabled:opacity-50 transition-colors"
                            title={t("settings.folders.cleanNow")}
                          >
                            <Sparkles size={12} className="text-primary" />
                            <span>{isCleaning ? "..." : t("settings.folders.cleanNow")}</span>
                          </button>
                          <button
                            onClick={() => invoke("open_folder_cmd", { path: f.path })}
                            className="flex items-center gap-1 rounded-md border border-border bg-surface px-2.5 py-1 text-xs font-medium hover:bg-surface-dark transition-colors"
                            title={t("settings.folders.openFolder")}
                          >
                            <ExternalLink size={12} />
                            <span>{t("settings.folders.openFolder")}</span>
                          </button>
                          <button
                            onClick={() => {
                              setIgnoreTargetFolder(f.path);
                              setTab("ignore");
                            }}
                            className="flex items-center gap-1 rounded-md border border-border bg-surface px-2.5 py-1 text-xs font-medium hover:bg-surface-dark transition-colors text-text-muted hover:text-text"
                            title={t("settings.folders.configureIgnore")}
                          >
                            <X size={12} />
                            <span>.mouziignore</span>
                          </button>
                        </div>
                      </div>
                    </div>
                  );
                })
              )}
            </div>

            {/* Archive Import */}
            <div className="rounded-lg border border-border bg-surface-dark p-4 space-y-3">
              <div className="flex items-start justify-between gap-3">
                <div>
                  <h3 className="text-sm font-semibold">{t("settings.archive.title")}</h3>
                  <p className="mt-1 text-xs text-text-muted">
                    {t("settings.archive.description")}
                  </p>
                </div>
                <button
                  onClick={handleImportArchive}
                  disabled={isImportingArchive}
                  className="flex shrink-0 items-center gap-1.5 rounded-md border border-border px-3 py-2 text-sm hover:bg-surface transition-colors disabled:cursor-not-allowed disabled:opacity-60"
                >
                  <Upload size={14} />
                  {isImportingArchive
                    ? t("settings.archive.importingShort")
                    : t("settings.archive.import")}
                </button>
              </div>
              {archiveToast && (
                <div
                  className={`text-xs px-3 py-2 rounded-md ${
                    archiveToast.type === "success"
                      ? "bg-green-50 text-green-700 border border-green-200"
                      : archiveToast.type === "error"
                      ? "bg-red-50 text-red-700 border border-red-200"
                      : "bg-blue-50 text-blue-700 border border-blue-200"
                  }`}
                >
                  <div>{archiveToast.message}</div>
                  {archiveToast.stagingPath && (
                    <button
                      onClick={() =>
                        invoke("open_folder_cmd", { path: archiveToast.stagingPath })
                      }
                      className="mt-2 inline-flex items-center gap-1 text-xs font-medium underline"
                    >
                      <ExternalLink size={12} />
                      {t("settings.archive.openImportFolder")}
                    </button>
                  )}
                </div>
              )}
            </div>
          </div>
        )}

        {tab === "rules" && (
          <div className="space-y-4">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <div>
                <h2 className="text-lg font-semibold">{t("settings.rules.title")}</h2>
                <p className="text-xs text-text-muted">
                  {t("settings.about.tagline")}
                </p>
              </div>
              <button
                onClick={() =>
                  setEditingRule({
                    name: "",
                    priority: 0,
                    enabled: true,
                    extensions: [],
                    pattern: null,
                    destination: "",
                    action: "move",
                    folder_id: 0,
                  })
                }
                className="flex items-center gap-1.5 rounded-md bg-primary px-3 py-2 text-sm font-medium text-white hover:bg-primary-hover shadow-sm transition-colors"
              >
                <Plus size={14} />
                {t("settings.rules.add")}
              </button>
            </div>

            {/* Filter & Export / Import toolbar */}
            <div className="flex flex-wrap items-center justify-between gap-3 rounded-lg border border-border bg-surface-dark p-3">
              {/* Filter by scope */}
              <div className="flex items-center gap-2">
                <span className="text-xs font-medium text-text-muted">{t("settings.rules.scope")}:</span>
                <CustomSelect
                  value={selectedFolderFilter}
                  onChange={(val) => setSelectedFolderFilter(val)}
                  options={[
                    { value: "all", label: t("settings.rules.filterAll") },
                    { value: "0", label: t("settings.rules.filterGlobal") },
                    ...folders.map((f) => ({
                      value: String(f.id),
                      label: getFolderName(f.path),
                      description: f.path,
                    })),
                  ]}
                  className="w-56"
                />
              </div>

              {/* Export / Import */}
              <div className="flex items-center gap-3">
                <label className="flex items-center gap-1.5 text-xs text-text-muted cursor-pointer select-none">
                  <input
                    type="checkbox"
                    checked={replaceOnImport}
                    onChange={(e) => setReplaceOnImport(e.target.checked)}
                    className="rounded border-border text-primary focus:ring-primary"
                  />
                  <span>{t("settings.rules.replaceOnImport")}</span>
                </label>
                <button
                  onClick={handleExportRules}
                  className="flex items-center gap-1 rounded-md border border-border bg-surface px-2.5 py-1 text-xs hover:bg-surface-dark transition-colors"
                >
                  <Download size={13} />
                  {t("settings.rules.export")}
                </button>
                <button
                  onClick={handleImportRules}
                  className="flex items-center gap-1 rounded-md border border-border bg-surface px-2.5 py-1 text-xs hover:bg-surface-dark transition-colors"
                >
                  <Upload size={13} />
                  {t("settings.rules.import")}
                </button>
              </div>
            </div>

            {ruleToast && (
              <div
                className={`text-xs px-3 py-2 rounded-md ${
                  ruleToast.type === "success"
                    ? "bg-green-50 text-green-700 border border-green-200"
                    : "bg-red-50 text-red-700 border border-red-200"
                }`}
              >
                {ruleToast.message}
              </div>
            )}

            {/* Rule Edit / Add Form */}
            {editingRule && (
              <div className="rounded-lg border-2 border-primary/40 bg-surface-dark p-4 space-y-4 shadow-sm">
                <div className="flex items-center justify-between pb-2 border-b border-border">
                  <span className="font-semibold text-sm">
                    {editingRule.id ? t("settings.rules.edit") : t("settings.rules.add")}
                  </span>
                  <button
                    onClick={() => setEditingRule(null)}
                    className="p-1 rounded text-text-muted hover:bg-border"
                  >
                    <X size={14} />
                  </button>
                </div>

                <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
                  <div>
                    <label className="text-xs font-medium text-text-muted">{t("settings.rules.name")}</label>
                    <input
                      value={editingRule.name}
                      onChange={(e) => setEditingRule({ ...editingRule, name: e.target.value })}
                      placeholder="e.g. Images, Documents"
                      className="mt-1 w-full rounded-md border border-border bg-surface px-2.5 py-1.5 text-sm outline-none focus:border-primary"
                    />
                  </div>

                  {/* Target Scope */}
                  <div>
                    <label className="text-xs font-medium text-text-muted">{t("settings.rules.scope")}</label>
                    <div className="mt-1">
                      <CustomSelect
                        value={editingRule.folder_id || 0}
                        onChange={(val) =>
                          setEditingRule({ ...editingRule, folder_id: Number(val) || 0 })
                        }
                        options={[
                          { value: 0, label: t("settings.rules.scopeGlobal") },
                          ...folders.map((f) => ({
                            value: f.id || 0,
                            label: getFolderName(f.path),
                            description: f.path,
                          })),
                        ]}
                      />
                    </div>
                  </div>

                  <div>
                    <label className="text-xs font-medium text-text-muted">{t("settings.rules.extensions")}</label>
                    <input
                      value={editingRule.extensions.join(", ")}
                      onChange={(e) =>
                        setEditingRule({
                          ...editingRule,
                          extensions: e.target.value
                            .split(",")
                            .map((s) => s.trim().toLowerCase())
                            .filter(Boolean),
                        })
                      }
                      placeholder="jpg, png, webp or *"
                      className="mt-1 w-full rounded-md border border-border bg-surface px-2.5 py-1.5 text-sm outline-none focus:border-primary"
                    />
                  </div>

                  <div>
                    <label className="text-xs font-medium text-text-muted">{t("settings.rules.pattern")}</label>
                    <input
                      value={editingRule.pattern || ""}
                      onChange={(e) =>
                        setEditingRule({
                          ...editingRule,
                          pattern: e.target.value.trim() === "" ? null : e.target.value,
                        })
                      }
                      placeholder="(?i)invoice.*\.pdf"
                      className="mt-1 w-full rounded-md border border-border bg-surface px-2.5 py-1.5 text-sm outline-none focus:border-primary font-mono text-xs"
                    />
                  </div>

                  <div className="md:col-span-2">
                    <label className="text-xs font-medium text-text-muted">{t("settings.rules.destination")}</label>
                    <div className="flex gap-2 mt-1">
                      <input
                        value={editingRule.destination}
                        onChange={(e) => setEditingRule({ ...editingRule, destination: e.target.value })}
                        placeholder={t("settings.rules.destinationPlaceholder")}
                        className="flex-1 rounded-md border border-border bg-surface px-2.5 py-1.5 text-sm outline-none focus:border-primary"
                      />
                      <button
                        type="button"
                        onClick={handleBrowseDestination}
                        className="flex items-center gap-1 rounded-md border border-border bg-surface px-3 py-1.5 text-xs font-medium hover:bg-surface-dark transition-colors"
                      >
                        <FolderOpen size={13} />
                        {t("settings.rules.browseDestination")}
                      </button>
                    </div>
                  </div>

                  <div>
                    <label className="text-xs font-medium text-text-muted">{t("settings.rules.priority")}</label>
                    <input
                      type="number"
                      value={editingRule.priority}
                      onChange={(e) =>
                        setEditingRule({ ...editingRule, priority: parseInt(e.target.value, 10) || 0 })
                      }
                      className="mt-1 w-full rounded-md border border-border bg-surface px-2.5 py-1.5 text-sm outline-none focus:border-primary"
                    />
                  </div>

                  <div>
                    <label className="text-xs font-medium text-text-muted">{t("settings.rules.action")}</label>
                    <div className="mt-1">
                      <CustomSelect
                        value={editingRule.action}
                        onChange={(val) => setEditingRule({ ...editingRule, action: val })}
                        options={[
                          { value: "move", label: "Move" },
                          { value: "ignore", label: "Ignore" },
                        ]}
                      />
                    </div>
                  </div>
                </div>

                <div className="flex items-center gap-3">
                  <label className="flex items-center gap-2 text-sm cursor-pointer select-none">
                    <input
                      type="checkbox"
                      checked={editingRule.enabled}
                      onChange={(e) => setEditingRule({ ...editingRule, enabled: e.target.checked })}
                      className="rounded border-border text-primary focus:ring-primary"
                    />
                    {t("settings.rules.enabled")}
                  </label>
                </div>

                <div className="flex gap-2 pt-2 border-t border-border/60">
                  <button
                    onClick={handleSaveRule}
                    disabled={!editingRule.name.trim() || !editingRule.destination.trim()}
                    className="flex items-center gap-1.5 rounded-md bg-primary px-4 py-2 text-sm font-medium text-white hover:bg-primary-hover disabled:opacity-50 shadow-sm transition-colors"
                  >
                    <Save size={14} />
                    {t("settings.rules.edit")}
                  </button>
                  <button
                    onClick={() => setEditingRule(null)}
                    className="flex items-center gap-1.5 rounded-md border border-border px-3 py-2 text-sm hover:bg-surface transition-colors"
                  >
                    <X size={14} />
                    {t("common.cancel")}
                  </button>
                </div>
              </div>
            )}

            {/* Rules Cards List */}
            <div className="space-y-2">
              {filteredRules.length === 0 ? (
                <div className="py-8 text-center text-text-muted text-sm border border-dashed border-border rounded-lg">
                  {t("popup.noActions")}
                </div>
              ) : (
                filteredRules.map((r) => {
                  const targetFolder = folders.find((f) => f.id === r.folder_id);
                  const isGlobal = !r.folder_id || r.folder_id === 0;
                  return (
                    <div
                      key={r.id}
                      className="flex items-center justify-between rounded-lg border border-border px-4 py-3 bg-surface hover:border-border-hover transition-colors"
                    >
                      <div className="flex-1 min-w-0 pr-3">
                        <div className="flex items-center gap-2 flex-wrap">
                          <span className="text-sm font-semibold">{r.name}</span>
                          <span
                            className={`text-[10px] px-2 py-0.5 rounded-full font-medium ${
                              isGlobal
                                ? "bg-blue-100 text-blue-800 dark:bg-blue-950 dark:text-blue-300"
                                : "bg-purple-100 text-purple-800 dark:bg-purple-950 dark:text-purple-300"
                            }`}
                          >
                            {isGlobal
                              ? t("settings.rules.scopeGlobal")
                              : `📁 ${targetFolder ? getFolderName(targetFolder.path) : "Folder #" + r.folder_id}`}
                          </span>
                          {!r.enabled && (
                            <span className="text-[10px] px-1.5 py-0.5 rounded bg-border text-text-muted font-medium">
                              {t("common.off")}
                            </span>
                          )}
                        </div>
                        <div className="text-xs text-text-muted mt-1 truncate">
                          <span className="font-mono">{r.extensions.join(", ") || "*"}</span>
                          <span className="mx-1.5">→</span>
                          <span className="font-medium text-text">{r.destination}</span>
                          {r.pattern && (
                            <span className="ml-2 font-mono text-[11px] text-primary/80">({r.pattern})</span>
                          )}
                        </div>
                      </div>

                      <div className="flex items-center gap-2 shrink-0">
                        <button
                          type="button"
                          role="switch"
                          aria-checked={r.enabled}
                          aria-label={`${r.name}: ${r.enabled ? t("settings.rules.enabled") : t("common.off")}`}
                          onClick={() => updateRule({ ...r, enabled: !r.enabled })}
                          className={`relative inline-flex h-5 w-9 items-center rounded-full transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary ${
                            r.enabled ? "bg-primary" : "bg-border"
                          }`}
                        >
                          <span
                            className={`inline-block h-3 w-3 transform rounded-full bg-white transition-transform ${
                              r.enabled ? "translate-x-5" : "translate-x-1"
                            }`}
                          />
                        </button>
                        <button
                          onClick={() => setEditingRule({ ...r })}
                          className="p-1.5 rounded-md hover:bg-border text-text-muted hover:text-text transition-colors"
                          title={t("settings.rules.edit")}
                        >
                          <Save size={14} />
                        </button>
                        <button
                          onClick={() => r.id && deleteRule(r.id)}
                          className="p-1.5 rounded-md text-text-muted hover:text-red-500 hover:bg-red-50 dark:hover:bg-red-950/40 transition-colors"
                          title={t("settings.rules.delete")}
                        >
                          <Trash2 size={14} />
                        </button>
                      </div>
                    </div>
                  );
                })
              )}
            </div>
          </div>
        )}

        {tab === "history" && (
          <div className="space-y-4">
            <div className="flex items-center justify-between">
              <h2 className="text-lg font-semibold">{t("settings.history.title")}</h2>
              <div className="flex items-center gap-2">
                <button
                  onClick={async () => { await undoAll(); }}
                  disabled={logs.length === 0 || logs.every((log) => log.undone)}
                  title={logs.length === 0 || logs.every((log) => log.undone) ? t("settings.history.revertAllDisabled") : undefined}
                  className="flex items-center gap-1.5 rounded-md border border-border px-3 py-2 text-sm text-text hover:bg-surface-dark disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  <RotateCcw size={14} />
                  {t("settings.history.revertAll")}
                </button>
                <button
                  onClick={clearLogs}
                  className="flex items-center gap-1.5 rounded-md border border-red-200 px-3 py-2 text-sm text-red-600 hover:bg-red-50"
                >
                  <Trash2 size={14} />
                  {t("settings.history.clear")}
                </button>
              </div>
            </div>
            {logs.length === 0 ? (
              <div className="flex flex-col items-center justify-center py-12 text-text-muted">
                <Inbox size={48} className="mb-3 opacity-50" />
                <span>{t("settings.history.empty")}</span>
              </div>
            ) : (
              <div className="space-y-2">
                {logs.map((log) => (
                  <div
                    key={log.id}
                    className={`flex items-center justify-between rounded-lg border px-4 py-3 ${log.undone ? "border-border bg-surface-dark opacity-50" : "border-border"
                      }`}
                  >
                    <div>
                      <div className="text-sm">{log.file_name}</div>
                      <div className="text-xs text-text-muted">
                        {log.file_type} → {log.destination_path || "-"}
                      </div>
                    </div>
                    <div className="flex items-center gap-2">
                      {log.destination_path && (
                        <button
                          onClick={async () => {
                            const folderPath = getDirectoryFromPath(log.destination_path);
                            if (folderPath) {
                              try {
                                await invoke("open_folder_cmd", { path: folderPath });
                              } catch (e) {
                                console.error("Failed to open folder:", e);
                              }
                            }
                          }}
                          className="p-1.5 rounded-md text-text-muted hover:bg-border"
                          title="Open folder"
                        >
                          <FolderOpen size={16} />
                        </button>
                      )}
                      {log.undone ? (
                        <span className="text-xs text-text-muted flex items-center gap-1">
                          <Check size={12} />
                          {t("settings.history.undone")}
                        </span>
                      ) : (
                        <button
                          onClick={() => log.id && undoAction(log.id)}
                          className="text-xs text-primary hover:underline"
                        >
                          {t("settings.history.undo")}
                        </button>
                      )}
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        )}

        {tab === "general" && (
          <div className="space-y-6 max-w-md">
            {/* Settings */}
            <div className="space-y-4">
              <div>
                <label className="text-sm font-medium text-text-muted block mb-2">
                  {t("settings.general.language")}
                </label>
                <CustomSelect
                  value={settings?.language || "en"}
                  onChange={(val) => handleChangeLanguage(val)}
                  options={[
                    { value: "en", label: "English" },
                    { value: "es", label: "Español" },
                    { value: "pl", label: "Polski" },
                    { value: "it", label: "Italiano" },
                    { value: "de", label: "Deutsch" },
                    { value: "fr", label: "Français" },
                    { value: "ru", label: "Русский" },
                    { value: "ja", label: "日本語" },
                    { value: "vi", label: "Tiếng Việt" },
                    { value: "uk", label: "Українська" },
                  ]}
                  size="md"
                />
              </div>
              <div>
                <label className="text-sm font-medium text-text-muted block mb-2">
                  {t("settings.general.theme")}
                </label>
                <CustomSelect
                  value={settings?.theme || "system"}
                  onChange={(val) =>
                    settings && saveSettings({ ...settings, theme: val })
                  }
                  options={[
                    { value: "system", label: t("settings.general.themeSystem") },
                    { value: "light", label: t("settings.general.themeLight") },
                    { value: "dark", label: t("settings.general.themeDark") },
                  ]}
                  size="md"
                />
              </div>
              <div className="flex items-center justify-between">
                <label className="text-sm font-medium text-text-muted">
                  {t("settings.general.startWithSystem")}
                </label>
                <button
                  onClick={() => setAutostart(!settings?.autostart)}
                  className={`relative inline-flex h-6 w-11 items-center rounded-full transition-colors ${settings?.autostart ? "bg-primary" : "bg-surface-dark"
                    }`}
                >
                  <span
                    className={`inline-block h-4 w-4 transform rounded-full bg-white transition-transform ${settings?.autostart ? "translate-x-6" : "translate-x-1"
                      }`}
                  />
                </button>
              </div>

              {/* Grace Period */}
              <div className="space-y-2">
                <div className="flex items-center justify-between">
                  <label className="text-sm font-medium text-text-muted">
                    {t("settings.general.gracePeriod")}
                  </label>
                  <span className="text-xs text-text-muted">
                    {formatDuration(currentGraceSeconds)}
                  </span>
                </div>
                <input
                  type="range"
                  min={0}
                  max={GRACE_STEPS.length - 1}
                  step={1}
                  value={sliderIndex}
                  onChange={(e) => handleGraceSliderChange(parseInt(e.target.value, 10))}
                  className="w-full"
                />
                <div className="flex items-center gap-2">
                  <input
                    type="number"
                    min={0}
                    value={graceValue}
                    onChange={(e) =>
                      handleGraceNumberChange(parseInt(e.target.value, 10) || 0, graceUnit)
                    }
                    className="w-24 rounded-md border border-border bg-surface px-2 py-1.5 text-sm outline-none focus:border-primary"
                  />
                  <div className="w-32">
                    <CustomSelect
                      value={graceUnit}
                      onChange={(val) =>
                        handleGraceNumberChange(graceValue, val as GraceUnit)
                      }
                      options={[
                        { value: "seconds", label: t("settings.general.gracePeriodSeconds") },
                        { value: "minutes", label: t("settings.general.gracePeriodMinutes") },
                        { value: "hours", label: t("settings.general.gracePeriodHours") },
                      ]}
                    />
                  </div>
                </div>
                {graceError && <p className="text-xs text-red-500">{graceError}</p>}
                <p className="text-xs text-text-muted">{t("settings.general.gracePeriodDesc")}</p>
              </div>

              {/* Check File Lock */}
              <div className="flex items-center justify-between">
                <div>
                  <label className="text-sm font-medium text-text-muted block">
                    {t("settings.general.checkFileLock")}
                  </label>
                  <span className="text-xs text-text-muted">
                    {t("settings.general.checkFileLockDesc")}
                  </span>
                </div>
                <button
                  onClick={() =>
                    settings &&
                    saveSettings({
                      ...settings,
                      lock_check_enabled: !settings.lock_check_enabled,
                    })
                  }
                  className={`relative inline-flex h-6 w-11 items-center rounded-full transition-colors ${settings?.lock_check_enabled ? "bg-primary" : "bg-surface-dark"
                    }`}
                >
                  <span
                    className={`inline-block h-4 w-4 transform rounded-full bg-white transition-transform ${settings?.lock_check_enabled ? "translate-x-6" : "translate-x-1"
                      }`}
                  />
                </button>
              </div>
            </div>

            {/* Scheduler */}
            <div className="space-y-4 pt-4 border-t border-border">
              <div>
                <h3 className="text-base font-semibold">{t("settings.scheduler.title")}</h3>
                <p className="text-xs text-text-muted">{t("settings.scheduler.desc")}</p>
              </div>

              <div className="flex items-center justify-between">
                <label className="text-sm font-medium text-text-muted">
                  {t("settings.scheduler.enable")}
                </label>
                <button
                  onClick={() => handleScheduleChange({ schedule_enabled: !localSchedule.schedule_enabled })}
                  className={`relative inline-flex h-6 w-11 items-center rounded-full transition-colors ${localSchedule.schedule_enabled ? "bg-primary" : "bg-surface-dark"
                    }`}
                >
                  <span
                    className={`inline-block h-4 w-4 transform rounded-full bg-white transition-transform ${localSchedule.schedule_enabled ? "translate-x-6" : "translate-x-1"
                      }`}
                  />
                </button>
              </div>

              <div>
                <label className="text-sm font-medium text-text-muted block mb-2">
                  {t("settings.scheduler.timesPerDay")}
                </label>
                <CustomSelect
                  value={localSchedule.schedule_times_per_day}
                  onChange={(val) =>
                    handleScheduleChange({ schedule_times_per_day: Number(val) })
                  }
                  options={[
                    { value: 1, label: t("settings.scheduler.once") },
                    { value: 2, label: t("settings.scheduler.twice") },
                    { value: 3, label: t("settings.scheduler.thrice") },
                    { value: 4, label: t("settings.scheduler.fourTimes") },
                  ]}
                  size="md"
                />
              </div>

              <div className="space-y-2">
                {Array.from({ length: localSchedule.schedule_times_per_day }).map((_, idx) => {
                  const key = `schedule_time_${idx + 1}` as keyof ScheduleSettings;
                  return (
                    <div key={idx}>
                      <label className="text-xs font-medium text-text-muted block mb-1">
                        {t("settings.scheduler.time", { number: idx + 1 })}
                      </label>
                      <input
                        type="time"
                        value={(localSchedule[key] as string | null) || ""}
                        onChange={(e) =>
                          handleScheduleChange({ [key]: e.target.value || null } as Partial<ScheduleSettings>)
                        }
                        className="w-full rounded-md border border-border bg-surface px-3 py-2 text-sm outline-none focus:border-primary"
                      />
                    </div>
                  );
                })}
              </div>

              <button
                onClick={handleSaveSchedule}
                className="flex items-center gap-1.5 rounded-md bg-primary px-3 py-2 text-sm font-medium text-white hover:bg-primary-hover shadow-sm"
              >
                <Save size={14} />
                {t("settings.rules.edit")}
              </button>
            </div>

          </div>
        )}

        {tab === "ignore" && (
          <IgnoreTab initialFolder={ignoreTargetFolder} />
        )}

        {tab === "partners" && (
          <Partners />
        )}

        {tab === "about" && (
          <About />
        )}
      </div>
    </div>
  );
}

function IgnoreTab({ initialFolder = "" }: { initialFolder?: string }) {
  const { t } = useTranslation();
  const { folders } = useAppStore();
  const [selectedFolder, setSelectedFolder] = useState(initialFolder || folders[0]?.path || "");
  const [patterns, setPatterns] = useState<string[]>([]);
  const [newPattern, setNewPattern] = useState("");
  const [saved, setSaved] = useState(false);

  useEffect(() => {
    if (initialFolder) {
      setSelectedFolder(initialFolder);
    } else if (!selectedFolder && folders.length > 0) {
      setSelectedFolder(folders[0].path);
    }
  }, [initialFolder, folders]);

  useEffect(() => {
    if (selectedFolder) {
      invoke<string[]>("load_mouziignore_cmd", { folderPath: selectedFolder })
        .then(setPatterns)
        .catch(() => setPatterns([]));
    } else {
      setPatterns([]);
    }
  }, [selectedFolder]);

  const handleAdd = () => {
    const trimmed = newPattern.trim();
    if (!trimmed || patterns.includes(trimmed)) return;
    setPatterns([...patterns, trimmed]);
    setNewPattern("");
    setSaved(false);
  };

  const handleRemove = (idx: number) => {
    setPatterns(patterns.filter((_, i) => i !== idx));
    setSaved(false);
  };

  const handleSave = async () => {
    if (!selectedFolder) return;
    try {
      await invoke("save_mouziignore_cmd", {
        folderPath: selectedFolder,
        patterns,
      });
      setSaved(true);
      setTimeout(() => setSaved(false), 2000);
    } catch (e) {
      console.error("save_mouziignore failed:", e);
    }
  };

  return (
    <div className="space-y-6 max-w-md">
      <h2 className="text-lg font-semibold">{t("settings.ignore.rulesTitle")}</h2>
      <p className="text-sm text-text-muted">
        {t("settings.ignore.description")}
      </p>

      <div>
        <label className="text-sm font-medium text-text-muted block mb-2">
          {t("settings.ignore.folder")}
        </label>
        <CustomSelect
          value={selectedFolder}
          onChange={(val) => setSelectedFolder(val)}
          placeholder={t("settings.ignore.selectFolder")}
          options={[
            { value: "", label: t("settings.ignore.selectFolder") },
            ...folders.map((f) => ({
              value: f.path,
              label: getSmartFolderName(f.path, folders),
              description: f.path,
            })),
          ]}
          size="md"
        />
      </div>

      {selectedFolder && (
        <>
          <div className="space-y-2">
            <label className="text-sm font-medium text-text-muted block">
              {t("settings.ignore.patterns")}
            </label>
            {patterns.length === 0 && (
              <p className="text-sm text-text-muted italic">
                {t("settings.ignore.noRules")}
              </p>
            )}
            {patterns.map((p, i) => (
              <div
                key={i}
                className="flex items-center justify-between rounded-md border border-border bg-surface px-3 py-2"
              >
                <code className="text-sm text-primary">{p}</code>
                <button
                  onClick={() => handleRemove(i)}
                  className="text-text-muted hover:text-red-400 transition-colors"
                  title={t("settings.ignore.remove")}
                >
                  <X size={14} />
                </button>
              </div>
            ))}
          </div>

          <div className="flex gap-2">
            <input
              type="text"
              value={newPattern}
              onChange={(e) => setNewPattern(e.target.value)}
              onKeyDown={(e) => e.key === "Enter" && handleAdd()}
              placeholder={t("settings.ignore.placeholder")}
              className="flex-1 rounded-md border border-border bg-surface px-3 py-2 text-sm outline-none focus:border-primary"
            />
            <button
              onClick={handleAdd}
              disabled={!newPattern.trim()}
              className="rounded-md bg-primary px-4 py-2 text-sm font-medium text-white hover:bg-primary-hover disabled:opacity-40 transition-colors"
            >
              {t("settings.ignore.add")}
            </button>
          </div>

          <div className="rounded-md border border-border bg-surface p-3">
            <p className="text-xs text-text-muted mb-1">
              <strong className="text-text">{t("settings.ignore.tips")}</strong>
            </p>
            <ul className="text-xs text-text-muted space-y-1 list-disc pl-4">
              <li><code>*.tmp</code> — ignore all .tmp files</li>
              <li><code>node_modules/</code> — ignore the folder</li>
              <li><code>~$*</code> — ignore Office temp files</li>
              <li><code>.DS_Store</code> — ignore exact file name</li>
            </ul>
          </div>

          <button
            onClick={handleSave}
            className="flex items-center gap-2 rounded-md bg-primary px-4 py-2.5 text-sm font-medium text-white hover:bg-primary-hover transition-colors"
          >
            <Save size={16} />
            {saved ? t("settings.ignore.saved") : t("settings.ignore.save")}
          </button>
        </>
      )}
    </div>
  );
}

function SidebarButton({
  active,
  onClick,
  icon,
  label,
}: {
  active: boolean;
  onClick: () => void;
  icon: React.ReactNode;
  label: string;
}) {
  return (
    <button
      onClick={onClick}
      className={`w-full flex items-center gap-2.5 rounded-md px-3 py-2 text-sm font-medium transition-colors ${active
        ? "bg-primary/10 text-primary"
        : "text-text-muted hover:bg-border hover:text-text"
        }`}
    >
      {icon}
      {label}
    </button>
  );
}
