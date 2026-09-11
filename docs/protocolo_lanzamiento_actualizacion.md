# Protocolo Oficial de Lanzamiento de Actualizaciones

> **Estándar Universal para el Ecosistema biglexj (Escritorio, Móvil, Web)**

Al recibir la instrucción del usuario **"Lanzar actualización"** o iniciar cualquier ciclo oficial de publicación, el agente DEBE seguir estrictamente el siguiente flujo ordenado y metódico:

---

## 1. Verificación de Versión en Remoto (Inmutabilidad Absoluta)
1. Consultar de forma obligatoria las versiones y tags publicados en GitHub (`gh release list -L 5` o `git ls-remote --tags`).
2. Si la versión local (`versionName` / `versionCode`) coincide con una versión que ya ha sido publicada en el repositorio remoto o en `biglexj.com` (sin importar cuándo fue subida), es **OBLIGATORIO** avanzar a la siguiente versión de parche (ej. de `1.1.4` a `1.1.5` e incrementar `versionCode`).
3. **Prohibición de Sobrescritura**: NUNCA sobrescribir, re-etiquetar (`git tag -f`) ni reemplazar un tag o release existente en la nube. Toda versión publicada es inmutable.
4. **SemVer sin límite artificial por dígito**: Los segmentos pueden superar `9`; `1.2.12` es válido. Avanzar `PATCH`, `MINOR` o `MAJOR` según compatibilidad y alcance, sin saltos basados únicamente en la cantidad de dígitos.

---

## 2. Auditoría y Sincronización de Documentación de Producto
Antes de ejecutar el script de compilación y publicación, auditar y actualizar los siguientes archivos clave:

1. **`RELEASE_MESSAGE.md`**:
   - Título y versión con emojis destacados.
   - Resumen conciso de novedades redactado para usuarios finales.
   - Lista corta con viñetas de cambios clave.
   - Cumplir el estándar de Release Message para la web, incluida la codificación UTF-8 y la correspondencia entre artefacto y etiqueta de descarga.
2. **`RELEASE_NOTES.md`**:
   - Sanitización rigurosa: eliminar cualquier referencia a rutas absolutas del entorno local, nombres de variables internas o volcados de consola de depuración.
   - Extensión proporcional al alcance (de 2 a 5 párrafos agrupados temáticamente).
3. **`ROADMAP.md`**:
   - Revisar si tareas listadas en `## 🔴 Pendientes activos` o `## 🟡 Intermedio` se resolvieron durante el ciclo y marcarlas como completadas.
   - Registrar la nueva versión en la sección `## 🟢 Completado` con su fecha (`YYYY-MM-DD`) y síntesis de novedades.
4. **`process/`**:
   - Mover los procesos completados a `process/completed/YYYY/`.

5. **Sincronización con la web**:
   - Todas las aplicaciones con página de detalles deben publicar su Release Message; no basta con subir el binario a GitHub, una tienda o un CDN.
   - Usar GitHub Releases como fuente predeterminada.
   - **Publicación Comunitaria / Desarrolladores Externos**: Quien desee publicar su aplicación en Aurora debe registrar su cuenta en `biglexj.com` y configurar su aplicación desde el portal. Próximamente se integrará un kit de desarrollo (SDK/CLI) para automatizar la publicación mediante scripts de terminal análogos a `build-release.ps1`.

---

## 3. Ejecución Centralizada mediante Script de Release
1. **Script de Publicación Obligatorio**: NUNCA compilar ni publicar binarios manualmente uno a uno en la terminal.
2. **Búsqueda del Script**:
   - Buscar `build-release.ps1` en la raíz del proyecto o dentro de `scripts/release/`.
   - Si no existe, crearlo basándose en las herramientas estándar de `Docs`.
3. **Automatización Integral del Script**:
   - Validación semántica de versión y preflight de Git.
   - Compilación y pruebas automáticas.
   - Empaquetado de instaladores nativos. En Windows se distribuye exclusivamente la versión ejecutable unificada **`.exe`** (`.msi` queda descartada de las distribuciones oficiales de Windows), garantizando compatibilidad directa con el instalador y soporte para WinGet.
   - Firma digital local si está configurada.
   - Generación de hashes de integridad (`SHA256SUMS.txt`).
   - Commit, tag atómico y push a GitHub (`HEAD:main` + tag).
   - Creación y subida automática de assets a GitHub Releases con `gh release create`.
   - Verificación posterior mediante la API de GitHub: el ejecutable `.exe` debe aparecer en `assets[]` del mismo tag y su URL de descarga responder correctamente.

---

## 4. Política de Ramas de Trabajo (Preview & Merge a Main) [CRÍTICO]
1. **Desarrollo Exclusivo en Rama `preview`**: Todo desarrollo activo, refactorización, integración de features y resolución de bugs DEBE realizarse en una rama de trabajo `preview` (o derivada), NUNCA directamente en `main`.
2. **Merge Autorizado**: Solo tras la validación final y la instrucción explícita del usuario de lanzar o unir la versión, se realiza el `merge` de `preview` hacia `main` (o push sincronizado a `main`).
3. **Ciclo Siguiente**: Inmediatamente después del merge a `main`, se crea o actualiza la siguiente rama `preview` para continuar el nuevo ciclo de trabajo de forma aislada y segura.
