; ============================================================================
; BiglexModern.iss  -  Plantilla base de instaladores Inno Setup (Biglex)
; ----------------------------------------------------------------------------
; DISENO (aprobado): PANTALLA UNICA de entrada con presentacion, ubicacion de
; instalacion y un unico boton principal. Despues: progreso y pantalla de
; exito. En total 3 pantallas (sin licencia, sin grupo de programa, sin
; "listo para instalar").
;
; Requisitos: Inno Setup 6.6+ (WizardStyle=modern {#MyAppTheme}, estilos Win11).
; ISCC en esta maquina: D:\Proyectos\biglexj\Scripts\tools\InnoSetup\ISCC.exe
;
; USO: copiar este archivo, BiglexModernUI.iss, identity.iss y version.iss.
; <app>\packaging\windows\) y configurar identity.iss.
; Cada repositorio queda autocontenido: no referenciar la plantilla compartida.
;
; version.iss lo genera/actualiza el script de build con la version real:
;   #define MyAppVersion "1.2.3"
;
; Compilar:
;   & "D:\Proyectos\biglexj\Scripts\tools\InnoSetup\ISCC.exe" setup.iss
; ============================================================================

#include "version.iss"
#include "identity.iss"

[Setup]
; --- IDENTIDAD DE ACTUALIZACION: unica y estable por app -------------------
; Mantenerla para que una version nueva actualice la anterior y no cree una
; instalacion paralela. (Migracion desde MSI: ver MIGRATION.md)
AppId={#MyAppId}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher=Biglex
AppPublisherURL=https://biglexj.com
AppSupportURL=https://biglexj.com
DefaultDirName={localappdata}\Programs\{#MyAppDirectory}
DefaultGroupName={#MyAppName}
; --- Pantallas: solo la nuestra + progreso + exito --------------------------
DisableWelcomePage=yes
DisableDirPage=yes
DisableProgramGroupPage=yes
DisableReadyPage=yes
OutputDir=Output
OutputBaseFilename={#MyAppDirectory}-Setup-{#MyAppVersion}
SetupIconFile={#MyAppIcon}
UninstallDisplayIcon={app}\{#MyAppExe}
UninstallDisplayName={#MyAppName}
Compression=lzma2/max
SolidCompression=yes
ShowLanguageDialog=no
; --- Identidad visual moderna + tema claro/oscuro automatico (IS 6.6+) ---
WizardStyle=modern {#MyAppTheme}
#if MyAppTheme == "dark"
WizardBackColor=#15191C
WizardImageBackColor=#15191C
#else
WizardBackColor=#F7F9FA
WizardImageBackColor=clWhite
#endif
WizardBackColorDynamicDark=#15191C
WizardImageBackColorDynamicDark=#15191C
; --- Instalacion por usuario (sin privilegios de administrador) -------------
; PrivilegesRequiredOverridesAllowed se deja vacio a proposito: abrir el
; dialogo "Seleccion del Modo de Instalacion" anade una pantalla extra.
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
; --- Comportamiento --------------------------------------------------------
CloseApplications=yes
RestartApplications=no
SetupLogging=yes
VersionInfoDescription={#MyAppName} instalador
VersionInfoProductName={#MyAppName}
VersionInfoCompany=Biglex

[Languages]
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"

[Messages]
spanish.FinishedHeadingLabel=Instalación completada
spanish.FinishedLabel={#MyAppName} se instaló correctamente.
spanish.FinishedLabelNoIcons={#MyAppName} se instaló correctamente.
spanish.ClickFinish=Pulsa Finalizar para cerrar el instalador.

[CustomMessages]
spanish.RunApp=Ejecutar {#MyAppName}

[Files]
; Extraído explícitamente por la UI; al principio para evitar descomprimir payload solid.
Source: "{#MyAppIcon}"; Flags: dontcopy
; Payload real preparado por el script de empaquetado en la carpeta "app\".
Source: "app\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

#ifndef MyTemplatePreview
[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExe}"; WorkingDir: "{app}"
; Acceso directo de escritorio opcional: definido por app sin anadir paginas.
; La plantilla NSIS de Tauri lo dejaba creado; se conserva la paridad.
Name: "{userdesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExe}"; WorkingDir: "{app}"

[Run]
; Lanza la app via el shell del escritorio: heredar el contexto del instalador
; hace que el proceso falle con 0xc00004bc. explorer.exe vive en {win}, no en {sys}.
Filename: "{win}\explorer.exe"; Parameters: """{app}\{#MyAppExe}"""; Description: "{cm:RunApp}"; Flags: nowait postinstall skipifsilent
#endif

; Si ya hay eventos en la app, integrar estas llamadas sin borrar sus hooks.
#include "BiglexModernUI.iss"

[Code]
{ --------------------------------------------------------------------------
  FUNCIONALIDAD PROPIA DE MouziFlow
  --------------------------------------------------------------------------
  Equivalencia de los hooks NSIS que Tauri v2 usaba en src-tauri\installer.nsh
  (macro NSIS_HOOK_PREINSTALL), mas la deteccion de WebView2 y la limpieza
  del inicio automatico al desinstalar. Ninguno de estos bloques sustituye a
  los eventos de la plantilla 2.0: se integran en ellos.

  taskkill /IM MouziFlow.exe /T   -> StopRunningApp (termina suave y luego forzado)
  taskkill /IM mouzi.exe /T      -> StopRunningApp (el binario real se llama mouzi.exe)
  DeleteRegValue HKCU "...\Run" "Mouzi"
                                  -> RemoveLegacyArtifacts (RegDeleteValue)
  Delete "$DESKTOP\Mouzi.lnk"    -> RemoveLegacyArtifacts (DelTree sobre el escritorio)
  Delete "$SMPROGRAMS\Mouzi.lnk" -> RemoveLegacyArtifacts (DelTree sobre el menu Inicio)
  RMDir /r "$LOCALAPPDATA\Mouzi" -> RemoveLegacyArtifacts (DelTree recursivo)
  -------------------------------------------------------------------------- }

{ Cierra la app si esta corriendo: cierre suave, espera y cierre forzado. }
procedure StopRunningApp();
var
  ResultCode: Integer;
begin
  Exec(ExpandConstant('{sys}\taskkill.exe'), '/IM MouziFlow.exe /T', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  Exec(ExpandConstant('{sys}\taskkill.exe'), '/IM mouzi.exe /T', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  Sleep(500);
  Exec(ExpandConstant('{sys}\taskkill.exe'), '/F /IM MouziFlow.exe /T', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  Exec(ExpandConstant('{sys}\taskkill.exe'), '/F /IM mouzi.exe /T', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  Log('Cierre de instancias de MouziFlow en ejecucion completado.');
end;

{ Limpia los rastros de la app legacy "Mouzi" (Mouzi <= 0.2.0). }
procedure RemoveLegacyArtifacts();
var
  ResultCode: Integer;
begin
  RegDeleteValue(HKCU, 'Software\Microsoft\Windows\CurrentVersion\Run', 'Mouzi');
  DelTree(ExpandConstant('{userdesktop}\Mouzi.lnk'), False, True, False);
  DelTree(ExpandConstant('{userprograms}\Mouzi.lnk'), False, True, False);
  DelTree(ExpandConstant('{commonprograms}\Mouzi.lnk'), False, True, False);
  DelTree(ExpandConstant('{localappdata}\Mouzi'), True, True, True);
  { Entrada de desinstalacion heredada de la app legacy. Inno Setup no tiene
    RegDeleteKey: se usa reg.exe, igual que hace la propia app al arrancar. }
  Exec(ExpandConstant('{sys}\reg.exe'), 'delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Uninstall\Mouzi" /f', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  Log('Limpieza de restos de la app legacy Mouzi completada.');
end;

{ --------------------------------------------------------------------------
  WEBVIEW2
  --------------------------------------------------------------------------
  Tauri v2 usa wry, que necesita el WebView2 Runtime. El instalador NSIS lo
  gestionaba con webviewInstallMode = downloadBootstrapper: si falta el
  runtime, descarga el bootstrapper oficial de Microsoft y lo ejecuta.
  Aqui se replica ese comportamiento: se detecta el runtime en el registro de
  EdgeUpdate y, solo si falta, se descarga y ejecuta el bootstrapper oficial.
  En Windows 10/11 el runtime ya viene instalado, asi que la app no exige
  ningun requisito nuevo.
  -------------------------------------------------------------------------- }

function IsWebView2Installed(var RuntimeVersion: String): Boolean;
var
  Version: String;
begin
  RuntimeVersion := '';
  Version := '';
  Result := RegQueryStringValue(HKLM64, 'SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}', 'pv', Version);
  if not Result then
    Result := RegQueryStringValue(HKLM32, 'SOFTWARE\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}', 'pv', Version);
  if not Result then
    Result := RegQueryStringValue(HKCU, 'SOFTWARE\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}', 'pv', Version);
  if Result then
    RuntimeVersion := Version;
end;

procedure EnsureWebView2Runtime();
var
  RuntimeVersion: String;
  Downloaded: Int64;
  SetupPath: String;
  ResultCode: Integer;
begin
  if IsWebView2Installed(RuntimeVersion) then
  begin
    Log('WebView2 Runtime detectado (version ' + RuntimeVersion + '). No hace falta instalarlo.');
    Exit;
  end;

  Log('WebView2 Runtime no detectado. Descargando el bootstrapper oficial de Microsoft...');
  try
    Downloaded := DownloadTemporaryFile('https://go.microsoft.com/fwlink/p/?LinkId=2124703', 'MicrosoftEdgeWebview2Setup.exe', '', nil);
  except
    Log('No se pudo descargar el bootstrapper de WebView2: ' + GetExceptionMessage);
    Exit;
  end;

  if Downloaded <= 0 then
  begin
    Log('El bootstrapper de WebView2 no se descargo. Se continua con la instalacion.');
    Exit;
  end;

  SetupPath := ExpandConstant('{tmp}\MicrosoftEdgeWebview2Setup.exe');
  if not Exec(SetupPath, '/silent /install', '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
    Log('No se pudo ejecutar el instalador de WebView2.')
  else if (ResultCode <> 0) and (ResultCode <> 3010) then
    Log('El instalador de WebView2 termino con el codigo ' + IntToStr(ResultCode) + '.');
end;

// --------------------------------------------------------------------------
// TECLADO
// --------------------------------------------------------------------------
// La revision 2.0 de la plantilla compartida ya resuelve el teclado completo:
//   1) WinSetFocus en lugar de WizardForm.ActiveControl, que no mueve el foco
//      a los controles que viven dentro de un panel.
//   2) ModernPathKeyDown en el TEdit: el campo de ruta gestiona su propio Tab
//      y su propia Enter, porque el motor no enruta al formulario las teclas
//      que consume el control de edicion.
//   3) ModernKeyUp atiende Enter y Espacio sobre los botones de la plantilla.
//   4) Los botones nativos Siguiente y Cancelar salen del recorrido del Tab
//      y Siguiente deja de ser el boton por defecto en la pantalla de entrada,
//      sin ocultarlos: el motor los necesita en modo silencioso.
//   5) El foco inicial va al campo de ruta (WinSetFocus con un flag
//      ModernFocusSet, para no quitarselo al usuario si vuelve a esa pagina).
//
// Por eso aqui ya no se sustituyen los manejadores de la plantilla: se
// respetan tal cual, incluido el foco inicial, que la plantilla gestiona con
// su propio flag de una sola vez.

procedure InitializeWizard();
begin
  ModernInitialize;
end;

procedure CurPageChanged(CurPageID: Integer);
begin
  ModernPageChanged(CurPageID);
end;

function NextButtonClick(WizardPageID: Integer): Boolean;
begin
  Result := ModernNextButtonClick(WizardPageID);
  if not Result then Exit;
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
begin
  Result := '';
  NeedsRestart := False;

  { Equivalencia de la macro NSIS_HOOK_PREINSTALL. }
  StopRunningApp;
  RemoveLegacyArtifacts;

  { WebView2: solo hace falta instalar si el runtime no esta presente. }
  EnsureWebView2Runtime;
end;

{ Limpieza al desinstalar: el valor de inicio automatico lo escribe
  tauri-plugin-autostart al ejecutar la app (no el instalador), asi que se
  borra aqui para no dejar una entrada apuntando a un binario inexistente. }
procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if CurUninstallStep = usPostUninstall then
  begin
    RegDeleteValue(HKCU, 'Software\Microsoft\Windows\CurrentVersion\Run', 'MouziFlow');
    RegDeleteValue(HKCU, 'Software\Microsoft\Windows\CurrentVersion\Run', 'Mouzi');
    Log('Valores de inicio automatico eliminados.');
  end;
end;

[Code]
procedure CancelButtonClick(CurPageID: Integer; var Cancel, Confirm: Boolean);
begin
  ModernCancelButtonClick(CurPageID, Cancel, Confirm);
end;
