# 🎯 MouziFlow — Roadmap

Plan de trabajo, objetivos de producto y hoja de ruta estratégica del proyecto.

> **Regla del roadmap:** El Roadmap reúne los pendientes, prioridades, pausas y logros del producto. Cuando un ciclo queda finalizado y aprobado, el elemento correspondiente pasa a **Completado** (`- [x] **vX.X.X**`).

---

## 🔴 Pendientes activos

- [ ] **Sincronización de Reglas en la Nube / Copia de Seguridad**: Exportación e importación de reglas de organización en formato JSON/YAML.
- [ ] **Filtros Avanzados por Expresión Regular y Tamaño**: Reglas basadas en patrones Regex complejos y rangos de tamaño de archivo (e.g. `> 100 MB`).

---

## 🟡 Intermedio (Prioridad Media/Baja)

- [ ] Selector de sonido de confirmación al organizar archivos en modo silencioso.
- [ ] Vista previa de acciones pendientes con botón de aprobación por lotes.
- [ ] Integración de menú contextual en el Explorador de Windows («Organizar con MouziFlow»).

---

## ⚪ Descartado / En Pausa

- ⏸️ Integración con almacenamiento en la nube (MouziFlow se mantiene como organizador 100% local-first y privado).

---

## 🟢 Completado

- [x] **v0.2.0** (2026-09-11)
  - **Rediseño Integral de UI, Menús Desplegables Dark Mode, Arrastre Fluido de Ventana y Empaquetado Oficial**:
    - **Reemplazo del 100% de Selectores Nativos por `CustomSelect`**:
      - Creación del átomo UI `CustomSelect.tsx` con estética moderna oscura, elevación contextual `z-50`, rotación animada de chevron a 180°, marcas de verificación `Check` y soporte para iconos y rutas contextuales.
      - Migración total en Popup principal (selector de carpetas) y Configuración (modo de carpeta, filtros de ámbito, edición de regla mover/ignorar, idioma, tema, período de gracia y programación).
    - **Arquitectura de Arrastre de Ventana Dual-Layer en Windows 11**:
      - Eliminación de `-webkit-app-region` en CSS para permitir la captura limpia de eventos en WebView2.
      - Inclusión de `data-tauri-drag-region="deep"` en la cabecera y en el handle central.
      - Doble capa de ejecución: llamada directa a `startDragging()` de Tauri v2 combinada con seguimiento físico de cursor throttled por `requestAnimationFrame` mediante `set_window_position_cmd` en Rust.
    - **Corrección de Diagnósticos Rust Win32**:
      - Tipado idiomático con `std::ptr::null_mut()` en `main.rs` para punteros de mutex/eventos Windows.
    - **Empaquetado Nativo NSIS con Icono Embebido**:
      - Declaración explícita de `installerIcon` y `uninstallerIcon` en `tauri.conf.json`.
      - Generación de instalador unificado `Mouzi_0.2.0_x64-setup.exe` con hashes SHA-256 en `release/`.
