<a id="-release-notes---mouziflow"></a>

# Release Notes - MouziFlow

> [!IMPORTANT]
> **Protocolo de Verificación de Versión en GitHub ("Lanzar actualización") [CRÍTICO]:**
> - Al recibir la orden de *"Lanzar actualización"*, es **OBLIGATORIO Y DE LEY** consultar primero la última versión publicada en GitHub / remoto (`gh release list` o `git ls-remote --tags`).
> - Si la versión local ya fue subida (así haya sido lanzada hace minutos), NUNCA se debe sobrescribir ni re-etiquetar. Se DEBE incrementar obligatoriamente a la siguiente versión de parche (e.g. `0.1.6` → `0.1.7`).
>
> **Sanitización de Notas (CRÍTICO):**
> - Los mensajes de las notas de lanzamiento DEBEN estar limpios de rutas de archivos del sistema local (ej. `d:\Proyectos\...`), nombres de variables internas, fragmentos de prompts o logs técnicos de depuración. Deben redactarse con lenguaje limpio, profesional y enfocado al usuario final.
>
> **Versionado SemVer:**
> - Los segmentos de versión no tienen un límite de un dígito. Versiones como `0.1.10` y `1.2.12` son válidas.
> - Incrementar `PATCH`, `MINOR` o `MAJOR` según compatibilidad y alcance. Una versión publicada no se sobrescribe.
> - **Extensión proporcional en Release Notes:** La cantidad de párrafos depende del alcance: 1 para un hito pequeño, 2 cuando hay dos cambios relevantes, 3 como extensión habitual, 4 para hitos relativamente grandes y hasta 5 para lanzamientos de gran alcance. Cada párrafo debe concentrarse en un cambio principal y evitar descripciones excesivamente largas o listas detalladas de archivos.
> - **No duplicar versiones**: Si una versión ya está registrada localmente pero aún no se ha hecho push a Git, añadir los nuevos cambios bajo la misma versión activa en lugar de crear una nueva versión de parche.

Registro histórico de cambios y versiones del proyecto.

## [0.2.2] - 2026-10-04

### Resumen
Actualización de estabilidad y corrección de comportamiento en el arranque del sistema. Se garantiza el inicio completamente silencioso en segundo plano en la bandeja del sistema al encender o reiniciar el equipo, evitando aperturas no deseadas de la ventana principal. Se perfecciona el filtrado de eventos en instancias secundarias y se automatiza la limpieza y migración de claves de registro y accesos directos anteriores.

### Detalles
- **Arranque en segundo plano 100% silencioso**: Detección exhaustiva de banderas de inicio automático y segundo plano para mantener la ventana oculta y la aplicación residiendo exclusivamente en la bandeja del sistema durante el inicio de sesión de Windows.
- **Filtrado inteligente en instancia única**: Bloqueo de señales de activación visual cuando se invocan instancias secundarias en modo automático o desatendido, asegurando que la interfaz solo se despliegue ante una apertura manual explícita por parte del usuario.
- **Limpieza y migración automática del instalador**: El instalador y el ciclo de vida de la aplicación ahora eliminan automáticamente claves de inicio residuales, carpetas obsoletas y accesos directos anteriores para evitar colisiones entre versiones.

## [0.2.1] - 2026-10-03

### Resumen
Actualización de mantenimiento e identidad visual. Se consolida el branding oficial a MouziFlow en todos los componentes del sistema: tooltips de la bandeja del sistema en los 10 idiomas oficiales, ventana principal y encabezados de configuración, notificaciones del sistema, paquetes de idioma y artefactos del instalador oficial.

### Detalles
- **Consolidación de marca en bandeja del sistema (System Tray)**: Actualización de tooltips de estado, contadores de archivos pendientes y títulos en la bandeja del sistema para reflejar de forma consistente la identidad MouziFlow en todos los idiomas soportados.
- **Unificación de interfaz y configuración**: Actualización del título de la ventana y de las vistas principales (Popup, Configuración y Acerca de), integrando enlaces oficiales del proyecto y sincronización del nombre por defecto en la exportación de reglas (`mouziflow-rules.json`).
- **Alineación de empaquetado e instalador**: Configuración de `productName` a nivel de Tauri y scripts de compilación NSIS para generar de forma nativa el instalador unificado `MouziFlow_0.2.1_x64-setup.exe` y control de procesos preinstalación.
- **Sincronización de internacionalización y documentación**: Actualización completa de las cadenas de marca en los 10 archivos de idioma (`es.json`, `en.json`, `de.json`, `fr.json`, `it.json`, `ja.json`, `pl.json`, `ru.json`, `uk.json`, `vi.json`), políticas de seguridad y guías de contribución.

## [0.2.0] - 2026-09-11

### Resumen
Actualización mayor que incorpora diseño moderno para selectores desplegables personalizados en toda la aplicación, soporte completo y perfeccionado para arrastre nativo de ventanas sin marco en Windows, gestión optimizada de instancia única (single-instance), alineación del arranque automático (autorun) y aislamiento total entre la versión instalada y el entorno de desarrollo para evitar colisiones.

### Detalles
- **Selectores desplegables modernos y temáticos**: Reemplazo total de los selectores nativos del sistema por componentes desplegables con diseño oscuro integrado, chevrones animados, resaltado de elemento seleccionado con iconos y soporte táctil y de teclado.
- **Arrastre fluido de ventana**: Habilitación del arrastre nativo en ventanas sin marco en Windows mediante regiones de arrastre dedicadas en la cabecera tanto en la vista flotante como en ajustes, desactivando la intercepción OLE y permitiendo un movimiento suave e instantáneo.
- **Aislamiento de desarrollo vs. instalación**: Configuración de identificador (`cc.mouzi.dev`), almacenamiento de base de datos (`mouzi-dev`) y entrada de registro independientes en modo depuración para permitir desarrollo en vivo sin colisionar con la versión instalada en el sistema.
- **Instancia única optimizada**: Control de instancia única nativo en Windows mediante Mutex y Eventos IPC, trayendo al frente y enfocando la ventana activa sin procesos duplicados ni bloqueos de base de datos.
- **Arranque automático alineado**: Consolidación del autorun mediante registro seguro de Windows, asegurando que el inicio con el sistema opere en segundo plano silencioso en la bandeja.

## [0.1.6] - 2026-09-11

### Resumen
Actualización de identidad visual y estabilidad en el entorno de Windows. Se elimina por completo la apertura de ventanas de terminal de depuración en el arranque del sistema, se integran los iconos nativos con transparencia alfa en la barra de tareas y en la bandeja del sistema, y se alinea el flujo de empaquetado al estándar Core para canalizar instaladores a la carpeta `release/`.

### Detalles
- **Arranque silencioso sin terminal**: Configuración incondicional del subsistema Windows GUI en el ejecutable nativo para evitar la aparición de consolas negras al iniciar sesión o abrir la aplicación.
- **Identidad nativa transparente**: Regeneración de todos los derivados de iconos (`icon.ico`, resoluciones PNG de 16 a 256 píxeles) desde el original canónico transparente, adaptándose de forma natural a temas claros, oscuros y translúcidos.
- **Integración con la barra de tareas**: Ajuste del comportamiento de ventana para que MouziFlow muestre su icono en la barra de tareas cuando la interfaz esté en uso y se repliegue silenciosamente a la bandeja del sistema al cerrarse.
- **Estandarización de scripts de lanzamiento**: Incorporación de scripts de empaquetado para generar automáticamente instaladores NSIS y MSI en la carpeta `release/` con cálculo de firmas y sumas SHA256.
