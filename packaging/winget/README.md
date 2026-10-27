# Manifiestos de winget — MouziFlow

Manifiestos de winget en formato winget-pkgs, preparados localmente para la
versión **0.2.3** (instalador de Inno Setup 6).

## Estructura

```
packaging\winget\manifests\b\biglexj\MouziFlow\<version>\
  biglexj.MouziFlow.yaml              (manifiesto de version)
  biglexj.MouziFlow.installer.yaml     (manifiesto de installer)
  biglexj.MouziFlow.locale.es-PE.yaml  (manifiesto de defaultLocale)
```

## Estado

**Preparado, NO publicado.** Nada sale de esta máquina: no se ha enviado nada a
`microsoft/winget-pkgs` ni se ha creado pull request.

## Datos del manifiesto 0.2.3

| Campo | Valor |
| --- | --- |
| `PackageIdentifier` | `biglexj.MouziFlow` |
| `PackageVersion` | `0.2.3` |
| `InstallerType` | `inno` |
| `Scope` | `user` (instalación por usuario, sin elevación) |
| `InstallerUrl` | `https://github.com/biglexj/MouziFlow/releases/download/v0.2.3/MouziFlow_0.2.3-setup.exe` |
| `InstallerSha256` | `11AC0817BD331C00F11D15DEACFAD0543CA1E6237AD56F533092DE7DEA5F0CB7` |

El `InstallerSha256` es el mismo valor que figura en `release\SHA256SUMS.txt`
(en minúsculas) para el artefacto
`release\MouziFlow_0.2.3-setup.exe`.

## Requisitos para publicar

1. Que exista el release `v0.2.3` en GitHub con el asset
   `MouziFlow_0.2.3-setup.exe` (el hash del manifiesto solo es válido contra
   ese archivo publicado).
2. Copiar esta carpeta a
   `manifests\b\biglexj\MouziFlow\0.2.3\` dentro de un clon de
   `microsoft/winget-pkgs` y abrir el pull request con la etiqueta
   `Package-Exists`, `Installer-Type-Updated` o la que corresponda.

## Nota

El `InstallerSha256` se fija contra el instalador definitivo de `release\`.
Como Inno Setup no produce binarios reproducibles, el hash cambia en cada
empaquetado: hay que repetir este paso tras cada build final de la versión.

`packaging\windows\MIGRATION.md` (secciones 6 y 10) ya no afirma que "no hay
manifiestos de winget en este repositorio": se corrigió para reflejar que los
manifiestos de la 0.2.3 están preparados y pendientes de publicación.
