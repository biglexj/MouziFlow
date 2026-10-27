# Migración del instalador de MouziFlow: NSIS (Tauri) → Inno Setup 6

MouziFlow distribuyó su instalador de Windows con el empaquetador **NSIS** de
Tauri v2 (`bundle.windows.nsis` + hooks en `src-tauri/installer.nsh`). Desde la
versión **0.2.3** el instalador oficial se compila con **Inno Setup 6** desde
`packaging/windows/setup.iss`.

El instalador nuevo produce el mismo artefacto público y con el mismo nombre:

```
release\MouziFlow_<version>-setup.exe
```

---

## 0. Diseño 2.0 (Biglex Modern)

La pantalla del instalador usa el diseño **Biglex Modern 2.0** (plantilla
compartida en `D:\Proyectos\biglexj\Scripts\tools\inno\`). El repo es
autocontenido: la copia local de la plantilla vive en
`packaging/windows/BiglexModernUI.iss` y no se referencia la ruta compartida.

Ficheros del paquete de empaquetado:

| Fichero | Origen / función |
| --- | --- |
| `packaging/windows/setup.iss` | Guion principal: `[Setup]`, `[Files]`, `[Icons]`, `[Run]` y el `[Code]` propio de MouziFlow. |
| `packaging/windows/BiglexModernUI.iss` | Copia exacta de `Scripts\tools\inno\BiglexModernUI.iss` (UI 2.0 y sus cuatro ajustes de teclado). |
| `packaging/windows/identity.iss` | Identidad de la app: nombre, AppId, carpeta, ejecutable, icono, tema. |
| `packaging/windows/version.iss` | Generado por el build con la versión real. No editar a mano. |
| `packaging/windows/icon.ico` | Copia de `src-tauri/icons/icon.ico`. |

### Pantallas

Son **tres** en total:

1. **Entrada** (panel 2.0): presentación, ubicación de instalación editable y un
   único botón **Instalar MouziFlow**.
2. **Progreso**: pantalla nativa de Inno Setup.
3. **Éxito**: pantalla nativa de Inno Setup, con **Finalizar**.

No hay página de licencia, ni de grupo de programa, ni de "listo para instalar"
(`DisableWelcomePage`, `DisableDirPage`, `DisableProgramGroupPage` y
`DisableReadyPage` están en `yes`).

### Tema claro / oscuro

`WizardStyle=modern {#MyAppTheme}` con `MyAppTheme=dynamic` en
`identity.iss`: Inno Setup 6.6+ elige el tema según la configuración del
sistema. La variante **clara** de verificación se compila con el mismo guion y
un parámetro de línea de comandos:

```powershell
& "D:\Proyectos\biglexj\Scripts\tools\InnoSetup\ISCC.exe" `
  "setup.iss" "/DMyAppTheme=light" "/O<dir>" "/FMouziFlow-Setup-<version>-light"
```

### Integración con la funcionalidad propia (no se duplica)

El `[Code]` de `setup.iss` **no reemplaza** los eventos de la plantilla: los
extiende. Los hooks propios se ejecutan dentro de los eventos de la plantilla:

| Evento de la plantilla | Hook propio de MouziFlow |
| --- | --- |
| `InitializeWizard` → `ModernInitialize` | — (la plantilla ya prepara la UI) |
| `CurPageChanged` → `ModernPageChanged` | `WinSetFocus(ModernPath.Handle)`: el foco inicial en el campo de ruta. |
| `NextButtonClick` → `ModernNextButtonClick` | El guion hereda la validación de ruta absoluta de la plantilla. |
| `PrepareToInstall` | `StopRunningApp`, `RemoveLegacyArtifacts`, `EnsureWebView2Runtime`. |
| `CurUninstallStepChanged` | Borra `Run\MouziFlow` y `Run\Mouzi` al desinstalar. |

---

## 1. Qué cambia para el usuario final

| Antes (NSIS / Tauri) | Ahora (Inno Setup 6) |
| --- | --- |
| `C:\Users\<usuario>\AppData\Local\MouziFlow` | `C:\Users\<usuario>\AppData\Local\Programs\MouziFlow` |
| Desinstalador `uninstall.exe` (Tauri NSIS) | Desinstalador `unins000.exe` + `unins000.dat` (Inno Setup) |
| Entrada de "Agregar o quitar programas": `MouziFlow` | Entrada de "Agregar o quitar programas": `MouziFlow` (AppId `{751D906F-92D3-41B3-A166-2F4AA32D3FE2}`) |
| Sin acceso directo en el Escritorio por omisión | Se crea siempre el acceso directo del Escritorio |
| Sin las pantallas nativas de progreso y éxito del diseño | Ahora sí: progreso y éxito son las pantallas nativas de Inno Setup |

El ejecutable sigue llamándose **`mouzi.exe`** (nombre del crate de Rust) para
no romper el acceso directo de inicio automático que escribe
`tauri-plugin-autostart`.

---

## 2. Pasos para migrar en un equipo con la versión NSIS instalada

### 2.1 Desinstalar la versión NSIS previa (obligatorio)

Las dos instalaciones son **independientes** (distinto `AppId` y distinta
carpeta), por lo que no se reemplazan solas: hay que quitar la anterior.

1. Cerrar MouziFlow (icono en la bandeja del sistema → Salir).
2. **Configuración → Aplicaciones → Aplicaciones instaladas → MouziFlow →
   Desinstalar**, o ejecutar directamente:
   ```powershell
   & "$env:LOCALAPPDATA\MouziFlow\uninstall.exe" /S
   ```
   (`/S` = desinstalación silenciosa; omitirlo para ver el asistente.)
3. Verificar que quedaron limpios:
   ```powershell
   Test-Path "$env:LOCALAPPDATA\MouziFlow"           # False
   Test-Path "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\MouziFlow.lnk"  # False
   Test-Path "$env:USERPROFILE\Desktop\MouziFlow.lnk" # False
   ```

> La desinstalación de Inno Setup **sí** borra el valor de inicio automático
> `HKCU\...\Run\MouziFlow`. El desinstalador NSIS de Tauri no lo hacía, así que
> quien migra puede encontrar esa entrada apuntando a una rutainexistente
> hasta el primer arranque de la app nueva (que la reescribe sola).

### 2.2 Instalar la versión Inno Setup

1. Ejecutar `MouziFlow_<version>-setup.exe`.
2. Pantalla única de entrada: revisar la **ubicación de instalación** y pulsar
   **Instalar MouziFlow**.
3. Al terminar, opcionalmente **Ejecutar MouziFlow**.

> La instalación es **por usuario** (`PrivilegesRequired=lowest`): no pide
> elevación UAC y no toca archivos del sistema.

### 2.3 Si ya se instaló la versión Inno sin desinstalar la NSIS

- El acceso directo del Escritorio y del menú Inicio pasan a apuntar a la
  versión nueva (mismo nombre de archivo `.lnk`).
- El valor de inicio automático
  `HKCU\Software\Microsoft\Windows\CurrentVersion\Run\MouziFlow` se reescribe
  solo en el primer arranque de la app nueva (el plugin de autostart lo
  sincroniza), pero conviene **desinstalar la versión NSIS** para no dejar la
  carpeta antigua en disco.

---

## 3. WebView2

Tauri v2 usa **wry**, que necesita el **WebView2 Runtime**. El instalador
antiguo lo gestionaba con `webviewInstallMode = downloadBootstrapper`.

El instalador nuevo replica ese comportamiento:

1. Detecta el runtime en el registro de EdgeUpdate
   (`{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}`).
2. Si ya está instalado (caso normal en Windows 10 y 11), no hace nada.
3. Si falta, descarga el **bootstrapper Evergreen oficial de Microsoft**
   (`https://go.microsoft.com/fwlink/p/?LinkId=2124703`) y lo ejecuta en
   silencio.

Es decir: **no se exige ningún requisito nuevo** respecto a la versión NSIS.

---

## 4. Identidad de actualización (AppId)

El `AppId` de Inno Setup define la identidad de la instalación. Debe
**mantenerse estable** para que una versión nueva actualice la anterior en
lugar de crear una instalación paralela:

```
AppId={751D906F-92D3-41B3-A166-2F4AA32D3FE2}
```

> **No cambiar este valor.** Si cambia, Inno Setup treats la nueva versión como
> una instalación distinta y conviven las dos.

---

## 5. Limpieza de restos de la app legacy "Mouzi" (≤ 0.2.0)

Los hooks NSIS antiguos (`src-tauri/installer.nsh`) limpiaban los rastros de la
app legacy **"Mouzi"**. Esa limpieza se traslada al instalador de Inno Setup
(`RemoveLegacyArtifacts`, sección `[Code]`):

| Hook NSIS | Equivalente en Inno Setup |
| --- | --- |
| `DeleteRegValue HKCU "...\CurrentVersion\Run" "Mouzi"` | `RegDeleteValue(HKCU, 'Software\Microsoft\Windows\CurrentVersion\Run', 'Mouzi')` |
| `Delete "$DESKTOP\Mouzi.lnk"` | `DelTree(ExpandConstant('{userdesktop}\Mouzi.lnk'), False, True, False)` |
| `Delete "$SMPROGRAMS\Mouzi.lnk"` | `DelTree(ExpandConstant('{userprograms}\Mouzi.lnk'), False, True, False)` |
| `RMDir /r "$LOCALAPPDATA\Mouzi"` | `DelTree(ExpandConstant('{localappdata}\Mouzi'), True, True, True)` |

Dos limpiezas adicionales que el instalador de Inno Setup sí hace (el hook NSIS
no las cubría):

| Limpieza | Dónde |
| --- | --- |
| Entrada de desinstalación heredada `HKCU\...\Uninstall\Mouzi` (apuntaba a una carpeta ya borrada) | `RemoveLegacyArtifacts`, con `reg.exe delete ... /f` (Inno no tiene `RegDeleteKey`) |
| Valor de inicio automático `HKCU\...\Run\MouziFlow` (lo escribe `tauri-plugin-autostart` al ejecutar la app, no el instalador) | `CurUninstallStepChanged` → `usPostUninstall` |

---

## 6. Manifiestos de winget

Los manifiestos de winget **sí existen** en este repositorio, preparados para
la versión 0.2.3 en:

```
packaging\winget\manifests\b\biglexj\MouziFlow\0.2.3\
```

Apuntan al instalador de Inno Setup:

- `InstallerType`: `inno`
- `InstallerSwitches`: `Silent: /VERYSILENT /SUPPRESSMSGBOXES /NORESTART` y
  `SilentWithProgress: /SILENT /SUPPRESSMSGBOXES /NORESTART` (Inno Setup)
- `Scope`: `user` (la instalación es por usuario)
- `InstallerSha256`: el del artefacto publicado, idéntico al de
  `release\SHA256SUMS.txt`

Están **preparados pero no publicados**: no se ha enviado nada a
`microsoft/winget-pkgs`. El `InstallerSha256` solo es válido contra el
instalador definitivo de `release\`, así que se fija después del empaquetado
final. Ver `packaging\winget\README.md`.

---

## 7. Compilar el instalador

```powershell
# Build completo (compila la app con Tauri y luego el instalador)
powershell -ExecutionPolicy Bypass -File .\scripts\packaging\Build-Installer.ps1

# Solo recompilar el instalador (sin recompilar la app)
powershell -ExecutionPolicy Bypass -File .\scripts\packaging\Build-Installer.ps1 -SkipBuild

# Variante clara de prueba (para verificación visual)
powershell -ExecutionPolicy Bypass -File .\scripts\packaging\Build-Installer.ps1 -LightTheme
```

El script:

1. reescribe `packaging\windows\version.iss` con la versión real;
2. copia `src-tauri\icons\icon.ico` a `packaging\windows\icon.ico`;
3. compila la app con Tauri (`tauri build`);
4. prepara el staging en `packaging\windows\app\`;
5. invoca `ISCC.exe` sobre `packaging\windows\setup.iss`;
6. deja el instalador en `release\MouziFlow_<version>-setup.exe` y actualiza
   `release\SHA256SUMS.txt`.

En Windows, Tauri ya **no** genera instalador: `src-tauri/tauri.windows.conf.json`
desactiva el bundler (`bundle.active = false`). Los bundles de Linux y macOS no
se ven afectados.

Compilador de Inno Setup usado en esta máquina:

```
D:\Proyectos\biglexj\Scripts\tools\InnoSetup\ISCC.exe
```

---

## 8. Validación física

Las comprobaciones se hacen sobre el **instalador real**, no sobre el código.
Los scripts de prueba están en `scripts/packaging/`:

| Script | Qué hace |
| --- | --- |
| `Test-Installer-UI.ps1` | Batería de teclado: foco inicial, ciclo de Tab y Shift+Tab, edición de la ruta, Enter/Espacio en el botón de carpeta, Enter instalando y cancelación con Escape. |
| `UiTestHelpers.ps1` | Utilidades Win32 compartidas (foco real con `GetGUIThreadInfo`, inyección de teclas en la cola del sistema, toma de primer plano). |
| `Capture-Installer.ps1` | Captura de la pantalla de entrada (`PrintWindow`), filtrada por PID. |
| `Capture-Install-Screens.ps1` | Captura de las pantallas nativas de progreso y de éxito, etiquetando cada fotograma. |

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\packaging\Test-Installer-UI.ps1 `
    -Exe .\packaging\windows\Output\MouziFlow-Setup-0.2.3.exe
```

### Notas de la instrumentación (importante para reproducir)

- `GetWindowText` **no cruza procesos** para un control `EDIT`: devuelve el
  texto cacheado en la creación del control, no el valor vivo. Para leer el
  campo de ruta hay que usar `WM_GETTEXT` (`[UiTest]::LiveText`).
- Con `keybd_event`, `Shift` se suelta de inmediato si se usa
  `Key(vk, shift)`: para `Shift+Tab` el modificador debe mantenerse con
  `KeyDown`/`KeyUp`.
- La ventana del asistente puede cambiar de handle: los controles se resuelven
  en vivo en cada lectura, no se cachean.
- El motor de Inno Setup no enruta al formulario las teclas que consumen sus
  propios controles. La plantilla lo resuelve con `ModernPathKeyDown` (asignado
  al `TEdit`), `ModernKeyUp` (Enter/Espacio sobre los botones) y
  `WinSetFocus`.

### Estado

#### Instalador 0.2.3 (instalador definitivo de esta entrega)

Verificado sobre `MouziFlow-Setup-0.2.3.exe` (Inno Setup 6.7.3):

| Prueba | Resultado |
| --- | --- |
| El asistente abre con el título "Instalar MouziFlow" | OK |
| La instalación se completa por usuario en `AppData\Local\Programs\MouziFlow` | OK |
| El binario instalado es idéntico al de la compilación (`SHA-256 faf754bb…`) | OK |
| Metadatos del binario instalado (`FileVersion` y `ProductVersion` 0.2.3, `ProductName` MouziFlow) | OK |
| Desinstalador de Inno Setup creado (`unins000.exe`, `unins000.dat`) | OK |
| Foco inicial, recorrido de Tab/Shift+Tab y teclas del asistente | NO VERIFICADO |

> La última fila queda **NO VERIFICADA**: el arnés de pruebas no puede
> ejecutarla en una sesión no interactiva, porque el asistente pierde el primer
> plano frente a la ventana de la terminal y la herramienta se niega a inyectar
> teclas en una ventana ajena. La matriz de teclado de más abajo se verificó
> físicamente sobre el instalador **0.2.2**, que comparte la plantilla visual,
> pero `setup.iss` se modificó después (2026-10-26). Conviene repetir esa
> comprobación manual antes de publicar.

#### Matriz de teclado y pantalla (verificada sobre el instalador 0.2.2)

| Prueba | Resultado |
| --- | --- |
| Ventana del asistente con el panel 2.0 (ruta, carpeta, instalar) | OK |
| Foco inicial en el campo de ruta | OK |
| Indicador de foco visible en el campo de ruta sin pulsar Tab | OK (cursor de inserción visible) |
| Tab recorre ruta → carpeta → instalar y cierra el ciclo | OK |
| Shift+Tab recorre en reversa | OK |
| La ruta es editable con teclado real (y se restaura) | OK |
| Enter en el botón de carpeta abre el selector nativo | OK |
| Espacio en el botón de carpeta abre el selector nativo | OK |
| Escape abre la confirmación "Salir de la Instalación" y cancela | OK |
| Enter en instalar avanza a la instalación | OK |
| Pantalla nativa de éxito mostrada | OK |
| Enter en la pantalla de éxito activa "Finalizar" y cierra el instalador | OK |
| Instalación por usuario sin elevación (`HKCU`, 0 escrituras en HKLM) | OK |
| Arranque de la app instalada (`MainWindowTitle = MouziFlow`) | OK |
| Actualización con el mismo AppId (una sola entrada de registro) | OK |
| Desinstalación limpia (carpeta, accesos directos y registro) | OK |
| Capturas de entrada, progreso y éxito | OK |

Capturas en `packaging\windows\screenshots\`:

| Fichero | Contenido |
| --- | --- |
| `installer-oscuro.png` | Pantalla de entrada, tema oscuro. |
| `installer-claro.png` | Pantalla de entrada, tema claro. |
| `instalador-entrada.png` | Fotograma de la pantalla de entrada durante la instalación interactiva. |
| `instalador-progreso.png` | Pantalla nativa de progreso ("Instalando"). |
| `instalador-exito.png` | Pantalla nativa de éxito ("Instalación completada"). |
| `installer-nombre-largo.png` | Pantalla de entrada con un nombre de aplicación muy largo (ver pendientes). |
| `app-abierta.png` | La app instalada, arrancando. |

Pendientes (no verificables en esta máquina sin afectar a los demás agentes
que trabajan en paralelo):

- **Escalado 125 % / 150 % / 200 %**: no verificado. Cambiar la escala del
  sistema (`HKCU\Control Panel\Desktop\LogPixels` / `Win8DpiScale`) es
  reversible, pero afecta en caliente a todos los procesos del equipo, y
  varios agentes están ejecutando instaladores al mismo tiempo. Compilar
  variantes con `WizardSizePercent` **no** es una prueba equivalente: esa
  directiva agranda las ventanas sin cambiar el factor de escalado de los
  controles, así que no reproduce el comportamiento a 125/150/200 %.
- **Nombres largos de aplicación**: verificado físicamente con el nombre real
  completo ("MouziFlow Gestor Automatico de Descargas y Archivos"). Los tres
  puntos que fallaban antes de los parches de la plantilla ahora están bien:
  - **Cabecera**: el nombre se ve entero (364 px de ancho frente a los 334 px
    recortados antes). La etiqueta usa `ModernAppName`, que mide el texto con
    el canvas de un bitmap auxiliar y reduce el cuerpo de la fuente hasta que
    cabe, en vez de recortar. No invade el indicador "INSTALADOR" (borde
    derecho de la etiqueta: 422 px de imagen; el texto llega a 395).
  - **Subtítulo**: ocupa dos líneas completas y se lee entero.
  - **Botón**: "Instalar MouziFlow Gestor Automatico de Descargas y Archivos"
    cabe dentro del rectángulo de acento, con 50 px de margen a la izquierda
    y 49 px a la derecha.

### Detalles técnicos de la plantilla (para quien la integre)

- `TPanel` **no** expone `Canvas` en el Pascal Script de Inno (el compilador
  responde `Unknown identifier 'CANVAS'`). Para medir texto hay que usar
  `TBitmapImage.Bitmap.Canvas`.
- `TCanvas` sí existe como tipo, pero el tamaño de fuente se controla con
  `Font.Height` **en píxeles negativos**, no con `Font.Size`.
- El botón de instalar reduce su cuerpo de fuente hasta que el texto cabe,
  con un mínimo legible (9 px de altura de fuente).
- `InitializeBitmapImageFromIcon` **redimensiona el control** al tamaño del
  ícono que carga (32 px dentro de una caja de 40 px). Hay que restaurar los
  límites del control después de la carga para que el ícono quede centrado.

### Ícono centrado (parche del 22-10 23:00)

`InitializeBitmapImageFromIcon` redimensiona el control al tamaño del ícono
que carga (32 px dentro de una caja de 40 px), de modo que el gráfico quedaba
pegado a la esquina superior izquierda de su caja. La plantilla lo corrige
restaurando los límites del control tras la carga, en `ModernLogo`:

```pascal
  Image.Stretch := True;
  Image.SetBounds(ScaleX(X), ScaleY(Y), ScaleX(Size), ScaleY(Size));
```

Medido por píxeles sobre la captura real (recuadro de 64×64 del logo):

| Compilación | Márgenes (izq/der/arr/aba) | Descentrado |
| --- | --- | --- |
| Sin el parche | 18 / 26 / 22 / 29 | 8 px horizontal, 7 px vertical |
| Con el parche | 19 / 19 / 24 / 24 | **0 px en ambos ejes** |

El ícono de la cabecera (20×20) también queda centrado: márgenes 6 px
verticales y diferencia horizontal de 2 px, que corresponde al propio glifo y
no a un desplazamiento del control.

### Concurrencia con otros agentes

En esta máquina conviven varios agentes que ejecutan sus propios instaladores
al mismo tiempo. Las pruebas de `Test-Installer-UI.ps1` **no les roban el
primer plano**: si detectan otra ventana de instalador, no envían pulsaciones
y marcan el resultado como `PENDIENTE` en lugar de darlo por bueno. Por eso
una corrida puede mostrar varios `PENDIENTE` y la siguiente, sin instaladores
ajenos, pasa las 16 comprobaciones. Es el comportamiento correcto: es mejor
dejar una comprobación sin hacer que interferir con la ventana de otro
proceso.

---

## 9. Coexistencia MSI / NSIS / Inno

| Instalador previo | Qué ocurre |
| --- | --- |
| **NSIS (Tauri v2)** | No participa de Windows Installer. Es una instalación independiente: hay que desinstalarla (sección 2.1) para no dejar dos copias. |
| **MSI (Windows Installer)** | Tampoco se actualiza con este instalador. El `AppId` de Inno Setup **no** es un `UpgradeCode` de MSI y no se registra en `HKLM\...\Installer`. |
| **Inno Setup (versión anterior)** | Sí se actualiza en sitio: el `AppId` es el mismo y la carpeta de destino no cambia. |

Consecuencia práctica: un equipo que venga de MSI o de NSIS necesita
**desinstalar a mano** antes de instalar este instalador. La limpieza de
restos de la app legacy "Mouzi" (≤ 0.2.0) cubre los rastros conocidos, pero no
una instalación MSI o NSIS de "MouziFlow" completo.

En este repositorio **no hay artefactos MSI**: Tauri ya no genera ni NSIS ni
MSI en Windows (`src-tauri/tauri.windows.conf.json` desactiva el bundler) y no
existe ningún `.wixproj`, `.msi` ni carpeta `installer/` en el árbol. La
coexistencia es por tanto una advertencia documental para equipos ya
instalados, no un conflicto entre artefactos del repo.

### Identidad de desinstalación

Inno Setup registra la entrada en:

```
HKCU\Software\Microsoft\Windows\CurrentVersion\Uninstall\{751D906F-92D3-41B3-A166-2F4AA32D3FE2}_is1
```

El sufijo `_is1` lo añade Inno Setup. La clave heredada de la app legacy se
borra con `reg.exe delete` (Inno no expone `RegDeleteKey`).

---

## 10. Manifiestos de winget (publicación)

Los manifiestos de winget de la 0.2.3 están ya preparados en
`packaging\winget\manifests\b\biglexj\MouziFlow\0.2.3\` y declaran:

- `InstallerType`: `inno`
- `InstallerSwitches`: `Silent: /VERYSILENT /SUPPRESSMSGBOXES /NORESTART` y
  `SilentWithProgress: /SILENT /SUPPRESSMSGBOXES /NORESTART` (Inno Setup)
- `Scope`: `user` (la instalación es por usuario)
- `InstallerSha256`: el del artefacto publicado, idéntico al de
  `release\SHA256SUMS.txt`

> **Preparados, no publicados**: publicar en `microsoft/winget-pkgs` es una
> acción aparte, que requiere abrir un pull request con los manifiestos de
> `packaging\winget\manifests\`. El `InstallerSha256` debe fijarse contra el
> instalador definitivo publicado, por lo que se actualiza tras el empaquetado
> final de cada versión.
