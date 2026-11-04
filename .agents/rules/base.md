---
trigger: always_on
---

# Instrucciones del proyecto — MouziFlow

## Documentación Core — entrada compartida

Consultar primero [Documentación Core](../../../Docs/README.md) y seleccionar solo los módulos pertinentes. Los estándares compartidos se mantienen allí; este archivo conserva el alcance y los contratos específicos del proyecto.

- [Calidad y entrega proporcionales](../../../Docs/global/quality/quality-baseline.md): build para ajustes visuales pequeños; pruebas pertinentes para elementos, lógica o páginas nuevos y cambios grandes; revisión acotada para documentación.
- [Procesos según alcance](../../../Docs/global/documentation/process-workflow.md): no añadir fases, archivos ni nuevas aprobaciones por rutina a ajustes pequeños ya autorizados.
- [Diseño común](../../../Docs/global/design/design_system.md) y [textos de interfaz](../../../Docs/global/design/interface-writing.md): contenido preciso, espacio útil, mínimo scroll innecesario, conservando la identidad del producto.
- [Estilo de comunicación](../../../Docs/global/agents/communication-style.md): registro «Scientific Elegant» en resúmenes y cierres; no aplica a los textos de interfaz.
- [Reglas de trabajo del agente](../../../Docs/global/documentation/agent-working-rules.md): entrada única, límite de 12.000 caracteres por archivo de reglas y commits de resguardo.
- [Comandos mediante Mise](../../../Docs/global/architecture/mise-command-standard.md) y [scripts y alias](../../../Docs/global/architecture/command-scripts-standard.md): Mise es la interfaz de comandos; los scripts de `package.json` son implementación, no interfaz.
- [Base de lanzamientos](../../../Docs/global/releases/release-baseline.md) y [protocolo de lanzamiento](../../../Docs/global/releases/protocolo_lanzamiento_actualizacion.md): versionado, artefactos e inmutabilidad de lo publicado. El protocolo local es un [puente a Core](../../docs/protocolo_lanzamiento_actualizacion.md).
- [Soporte oficial y diálogo «Acerca de»](../../../Docs/features/official-support/official-support-baseline.md): autoría, licencia y enlaces oficiales del ecosistema.
- [Diagnósticos reutilizables](../../../Docs/troubleshooting/README.md) y [promoción a Core](../../../Docs/global/documentation/core-promotion-workflow.md): documentar en Core los fallos confirmados o aprendizajes generalizables y enlazarlos desde el proyecto; mantener locales los detalles exclusivos.

En estos criterios comunes, aplicar las bases vigentes enlazadas en lugar de copias históricas de este archivo. Respetar la dirección actual de Biglex y los contratos específicos del producto; ante una contradicción, comprobar la implementación vigente y resolverla explícitamente. Las skills generales importadas son apoyo técnico, no una autoridad para redefinir estas reglas.

Entrada única de instrucciones: `.agents/rules/base.md`. No se crean `AGENTS.md` ni `agent.md` equivalentes en la raíz.

## Contratos locales de MouziFlow

- Aplicación de escritorio **Tauri v2 + Rust + React 19** para organizar descargas y archivos, 100 % privada y local. Licencia MIT; autoría `biglexj` (2026).
- MouziFlow es un fork y evolución de [Mouzi](https://github.com/hsr88/mouzi) de @hsr88: conserva la atribución original y añade mejoras propias. La atribución vive en [`LICENSE.md`](../../LICENSE.md) y en el `README.md` del proyecto.
- El proyecto tiene dos piezas con ciclos de publicación distintos: la **aplicación de escritorio** (release con instalador Inno Setup) y el **sitio web** en `website/` (Astro, desplegado en Vercel). La publicación del sitio no se ejecuta desde `mise publish`.
- Comandos: `mise dev`, `mise build`, `mise check`, `mise test`, `mise release` (prepara, no publica) y `mise publish` (publicación explícita).
