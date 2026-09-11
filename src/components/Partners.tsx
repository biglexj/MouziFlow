import { useTranslation } from "react-i18next";
import { invoke } from "@tauri-apps/api/core";
import {
  Heart,
  ExternalLink,
  GitBranch,
  Award,
  Sparkles,
  Coffee,
  GitPullRequest,
  Users,
  MessageSquare,
  Star,
} from "lucide-react";

export default function Partners() {
  const { t } = useTranslation();

  const handleOpenLink = (url: string) => {
    invoke("open_folder_cmd", { path: url }).catch(console.error);
  };

  return (
    <div className="space-y-6 max-w-2xl">
      {/* Header */}
      <div>
        <div className="flex items-center gap-2">
          <Award className="text-primary" size={22} />
          <h2 className="text-xl font-bold text-text">
            {t("settings.partners.title", "Partner, Donaciones y Aportes")}
          </h2>
        </div>
        <p className="text-xs text-text-muted mt-1">
          {t(
            "settings.partners.subtitle",
            "Conoce a los creadores, apoya el desarrollo continuo y colabora con la comunidad."
          )}
        </p>
      </div>

      {/* Partner Principal / Creador */}
      <div className="rounded-xl border border-primary/30 bg-gradient-to-br from-primary/10 via-surface to-surface-dark p-5 shadow-sm space-y-4">
        <div className="flex items-start justify-between gap-4">
          <div className="flex items-center gap-3.5">
            <div className="relative h-14 w-14 rounded-2xl overflow-hidden border-2 border-primary/40 shadow-md shadow-primary/20 shrink-0 bg-surface flex items-center justify-center">
              <img
                src="https://github.com/biglexj.png"
                alt="Biglex J"
                className="h-full w-full object-cover"
                onError={(e) => {
                  (e.currentTarget as HTMLElement).style.display = "none";
                }}
              />
              <span className="absolute inset-0 flex items-center justify-center text-primary font-bold text-lg -z-10">
                BJ
              </span>
            </div>
            <div>
              <div className="flex items-center gap-2">
                <span className="text-base font-bold text-text">Biglex J</span>
                <span className="inline-flex items-center gap-1 rounded-full bg-primary/20 px-2 py-0.5 text-[10px] font-semibold text-primary border border-primary/30">
                  <Sparkles size={10} /> Partner & Lead Dev
                </span>
              </div>
              <p className="text-xs text-text-muted mt-0.5">
                Content Creator | Developer | MouziFlow Maintainer
              </p>
            </div>
          </div>
        </div>

        <p className="text-xs text-text-muted leading-relaxed">
          {t(
            "settings.partners.biglexDesc",
            "Desarrollo y mantenimiento de la edición personalizada MouziFlow con soporte multicarpetas, optimizaciones de rendimiento, traducción completa al español y diseño Cyberpunk/Teal."
          )}
        </p>

        {/* Botones de acción principales */}
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-2.5 pt-1">
          <button
            onClick={() => handleOpenLink("https://ko-fi.com/biglexj")}
            className="flex items-center justify-center gap-2 rounded-lg bg-gradient-to-r from-teal-500 to-cyan-500 px-4 py-2.5 text-xs font-semibold text-white shadow-md shadow-teal-500/20 hover:brightness-110 active:scale-[0.98] transition-all"
          >
            <Coffee size={15} />
            <span>{t("settings.partners.donateKofi", "Donar en Ko-fi / Apoyar")}</span>
            <ExternalLink size={12} className="ml-auto opacity-80" />
          </button>

          <button
            onClick={() => handleOpenLink("https://github.com/biglexj/MouziFlow")}
            className="flex items-center justify-center gap-2 rounded-lg border border-border bg-surface-dark px-4 py-2.5 text-xs font-semibold text-text hover:border-primary/40 hover:bg-surface transition-colors shadow-sm"
          >
            <GitBranch size={15} className="text-primary" />
            <span>{t("settings.partners.githubRepo", "Repositorio en GitHub")}</span>
            <ExternalLink size={12} className="ml-auto text-text-muted" />
          </button>
        </div>
      </div>

      {/* Aportes y Contribuciones */}
      <div className="rounded-xl border border-border bg-surface-dark/40 p-5 space-y-4">
        <div className="flex items-center gap-2">
          <GitPullRequest size={18} className="text-primary" />
          <h3 className="text-sm font-semibold text-text">
            {t("settings.partners.contributionsTitle", "¿Cómo hacer tus aportes?")}
          </h3>
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
          <div className="rounded-lg border border-border bg-surface p-3.5 space-y-1.5">
            <div className="flex items-center gap-1.5 text-primary text-xs font-semibold">
              <Star size={14} />
              <span>{t("settings.partners.step1Title", "1. Sugerencias y Bugs")}</span>
            </div>
            <p className="text-[11px] text-text-muted leading-relaxed">
              {t(
                "settings.partners.step1Desc",
                "Abre un Issue en GitHub para proponer nuevas funciones o reportar problemas."
              )}
            </p>
          </div>

          <div className="rounded-lg border border-border bg-surface p-3.5 space-y-1.5">
            <div className="flex items-center gap-1.5 text-primary text-xs font-semibold">
              <GitPullRequest size={14} />
              <span>{t("settings.partners.step2Title", "2. Código y Reglas")}</span>
            </div>
            <p className="text-[11px] text-text-muted leading-relaxed">
              {t(
                "settings.partners.step2Desc",
                "Envía Pull Requests con nuevas reglas por defecto, extensiones o arreglos."
              )}
            </p>
          </div>

          <div className="rounded-lg border border-border bg-surface p-3.5 space-y-1.5">
            <div className="flex items-center gap-1.5 text-primary text-xs font-semibold">
              <Heart size={14} />
              <span>{t("settings.partners.step3Title", "3. Difusión y Donación")}</span>
            </div>
            <p className="text-[11px] text-text-muted leading-relaxed">
              {t(
                "settings.partners.step3Desc",
                "Comparte la herramienta y ayuda a mantener los servidores y el desarrollo activo."
              )}
            </p>
          </div>
        </div>

        <div className="flex flex-wrap items-center gap-2 pt-2 border-t border-border/60">
          <button
            onClick={() => handleOpenLink("https://github.com/biglexj/MouziFlow/issues")}
            className="inline-flex items-center gap-1.5 rounded-md border border-border bg-surface px-3 py-1.5 text-xs font-medium hover:bg-border transition-colors"
          >
            <MessageSquare size={13} className="text-primary" />
            <span>{t("settings.partners.openIssue", "Reportar en GitHub")}</span>
          </button>

          <button
            onClick={() => handleOpenLink("https://github.com/biglexj/MouziFlow/pulls")}
            className="inline-flex items-center gap-1.5 rounded-md border border-border bg-surface px-3 py-1.5 text-xs font-medium hover:bg-border transition-colors"
          >
            <GitPullRequest size={13} className="text-primary" />
            <span>{t("settings.partners.openPr", "Enviar Pull Request")}</span>
          </button>
        </div>
      </div>

      {/* Créditos del Proyecto Base */}
      <div className="rounded-xl border border-border bg-surface-dark/20 p-4 flex items-center justify-between gap-4">
        <div className="flex items-center gap-3 min-w-0">
          <div className="p-2 rounded-lg bg-surface border border-border shrink-0">
            <Users size={16} className="text-text-muted" />
          </div>
          <div className="min-w-0">
            <div className="text-xs font-semibold text-text truncate">
              {t("settings.partners.originalAuthor", "Proyecto Original: Mouzi")}
            </div>
            <div className="text-[11px] text-text-muted truncate">
              Creado originalmente por hsr88. Licencia libre y de código abierto.
            </div>
          </div>
        </div>

        <button
          onClick={() => handleOpenLink("https://github.com/hsr88/mouzi")}
          className="p-1.5 rounded-md hover:bg-border text-text-muted hover:text-text transition-colors shrink-0"
          title="Ver autor original en GitHub"
        >
          <ExternalLink size={14} />
        </button>
      </div>
    </div>
  );
}
