; Configuración por aplicación. Mantener MyAppId estable entre versiones.
; MouziFlow — instalador de Windows con Inno Setup 6 (Biglex Modern 2.0).
;
; MyAppId: GUID propio y estable. NO es un UpgradeCode de MSI: Inno Setup no
; participa de Windows Installer, así que reutilizar un UpgradeCode no haría que
; una MSI previa se actualice con este instalador. Ver MIGRATION.md.
#ifndef MyAppName
  #define MyAppName "MouziFlow"
#endif
#ifndef MyAppId
  #define MyAppId "{{751D906F-92D3-41B3-A166-2F4AA32D3FE2}"
#endif
#ifndef MyAppDirectory
  #define MyAppDirectory "MouziFlow"
#endif
; Nombre real del binario producido por cargo (crate "mouzi").
#ifndef MyAppExe
  #define MyAppExe "mouzi.exe"
#endif
; Icono oficial transparente de la app (copiado de src-tauri\icons\icon.ico).
#ifndef MyAppIcon
  #define MyAppIcon "icon.ico"
#endif
; Tema automatico segun Windows. "light" y "dark" se compilan para verificacion.
#ifndef MyAppTheme
  #define MyAppTheme "dynamic"
#endif

#ifndef MyAppSubtitle
  #define MyAppSubtitle "Cada archivo en su lugar."
#endif
