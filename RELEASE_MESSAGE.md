# MouziFlow v0.2.0 — Selectores modernos, arrastre de ventana, instancia única y entorno de desarrollo aislado

Nueva versión mayor: MouziFlow estrena selectores desplegables personalizados y modernos en toda la interfaz, soporte para arrastre nativo de ventana sin marco en Windows, gestión perfeccionada de instancia única, alineación del arranque automático y aislamiento completo para que el desarrollo en vivo no colisione con la aplicación instalada.

---

### Novedades destacadas

- **Selectores desplegables con diseño oscuro:** Se reemplazaron los antiguos selectores nativos del sistema por desplegables elegantes adaptados al tema oscuro de MouziFlow, con bordes definidos, previsualización de rutas y chevrones animados.
- **Arrastre fluido de ventana:** Ahora es posible mover la ventana flotante y la ventana de ajustes haciendo clic y arrastrando directamente desde la cabecera, con cursores interactivos y barra de agarre visual perfeccionada.
- **Aislamiento de desarrollo vs. versión instalada:** Se separaron los identificadores (`cc.mouzi.dev`), la base de datos (`mouzi-dev`) y las claves de autorun en modo depuración, permitiendo programar y depurar (`bun run tauri:dev`) mientras la versión instalada sigue activa sin conflicto alguno.
- **Instancia única optimizada:** El sistema intercepta al instante cualquier intento de apertura repetida de la aplicación, trayendo al frente y enfocando la ventana activa sin abrir procesos duplicados.
- **Arranque automático alineado:** Configuración limpia en el registro de inicio de Windows para operar de forma silenciosa en la bandeja del sistema al encender el equipo.

---

### Soporte

- **Sitio oficial:** https://www.biglexj.com/
- **GitHub:** https://github.com/biglexj
