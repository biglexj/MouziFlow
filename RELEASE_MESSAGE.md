# 📦 MouziFlow v0.2.3 — Instalador de Windows modernizado (Inno Setup)

El instalador oficial de Windows se reconstruye sobre una base propia con Inno Setup 6, la herramienta de empaquetado que sustituye al empaquetador NSIS que generaba Tauri. La instalación se vuelve más clara, coherente con la identidad visual de la aplicación y sin privilegios de administrador.

---

### Novedades destacadas

- **Instalador de Windows modernizado (Inno Setup):** Pantalla única de entrada (presentación, ruta editable y botón principal), progreso y éxito nativos, tema claro/oscuro automático según Windows, esquinas nativas de Windows 11 e ícono centrado.
- **Instalación por usuario y actualización en sitio:** Instalación sin elevación de privilegios y aplicada en el mismo directorio, sin instalar en paralelo.
- **Migración documentada:** La guía de migración explica cómo desinstalar el instalador NSIS anterior (que instalaba en `AppData\Local\MouziFlow` con `uninstall.exe`), la nueva ubicación de instalación (`AppData\Local\Programs\MouziFlow` con `unins000.exe`) y la conservación de la limpieza de restos de la app heredada "Mouzi".
- **Empaquetado oficial Inno Setup:** Distribución oficial y verificada mediante el instalador `MouziFlow_0.2.3-setup.exe`.
- **Panel principal más grande y centrado:** La ventana flotante pasa a 500×720 px y se abre centrada en la pantalla, en lugar de restaurar la última posición guardada.

---

### Descarga

https://github.com/biglexj/MouziFlow/releases/download/v0.2.3/MouziFlow_0.2.3-setup.exe

---

### Soporte

- **Sitio oficial:** https://www.biglexj.com/
- **GitHub:** https://github.com/biglexj/MouziFlow
