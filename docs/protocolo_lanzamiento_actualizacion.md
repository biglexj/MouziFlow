# Protocolo de lanzamiento y actualización

- Estado: histórico (documento puente)
- Última actualización: 2026-11-03
- Fuente canónica: [protocolo oficial de lanzamiento y actualización](../../Docs/global/releases/protocolo_lanzamiento_actualizacion.md)

Este archivo conserva la ruta que el proyecto tenía antes de la consolidación. La norma ya no vive aquí: el protocolo compartido del ecosistema está en Core, con estas fuentes:

- [Protocolo oficial de lanzamiento y actualización](../../Docs/global/releases/protocolo_lanzamiento_actualizacion.md): verificación remota previa, inmutabilidad de una versión publicada, auditoría de `RELEASE_MESSAGE.md`, `RELEASE_NOTES.md`, `ROADMAP.md` y `process/`, ejecución centralizada por script de release y política de ramas `preview` → `main`.
- [Base de lanzamientos](../../Docs/global/releases/release-baseline.md): reglas mínimas de versionado, artefactos y publicación.
- [Estándar de Release Message para la web](../../Docs/global/releases/web-release-message-standard.md): contrato del mensaje público.
- [Estándar de comandos mediante Mise](../../Docs/global/architecture/mise-command-standard.md): `release` prepara artefactos y no publica; `publish` publica de forma explícita.

Si el código y este documento discrepan, prevalece la implementación vigente y se corrige el documento.

## particularidades de MouziFlow

- La implementación local del flujo es `scripts/release/build-release.ps1`, invocado por `mise release` (preparación local, sin publicar) y por `mise publish` (publicación explícita).
- MouziFlow distribuye además una **sitio web** en `website/` (Astro, desplegado en Vercel). Esa publicación es independiente de la release de la aplicación de escritorio y no se ejecuta desde `mise publish`.
