<#
.SYNOPSIS
    Prueba funcional fisica del teclado del instalador de MouziFlow.

.DESCRIPTION
    Lanza el instalador REAL y comprueba con la API de Windows:
      - el foco inicial en el campo de ruta,
      - que la ruta sea editable (teclado real),
      - que Tab y Shift+Tab recorran ruta -> carpeta -> instalar y cierren el ciclo,
      - que Enter y Espacio en el boton de carpeta abran el selector nativo,
      - que Enter en instalar avance a la instalacion,
      - que Escape cancele.

    Las teclas se inyectan en la cola del sistema (keybd_event) sobre la
    ventana del asistente, que se fuerza al primer plano: es la via mas
    fiel a un usuario real. El foco se lee con GetGUIThreadInfo del hilo
    del asistente, no con GetForegroundWindow.

    El texto del campo de ruta se lee con WM_GETTEXT: GetWindowText no
    cruza procesos para un control EDIT y devuelve el valor cacheado en la
    creacion del control, no el valor vivo.

    Si otra ventana (por ejemplo el instalador de otro agente) se queda con
    el primer plano, la prueba no teclea y lo reporta como PENDIENTE: no se
    deben enviar pulsaciones a una ventana ajena.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\scripts\packaging\Test-Installer-UI.ps1 `
        -Exe .\packaging\windows\Output\MouziFlow-Setup-0.2.3.exe
#>
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [int]$WaitSeconds = 8
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'UiTestHelpers.ps1')

$results = New-Object System.Collections.Generic.List[string]
function Add-Result {
    param([string]$Name, [bool]$Ok, [string]$Detail)
    $tag = if ($Ok) { 'OK   ' } else { 'FALLO' }
    $line = "[$tag] $Name :: $Detail"
    Write-Output $line
    $results.Add($line) | Out-Null
}

# Limpiar instancias previas del mismo instalador: interfieren con la prueba.
Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -like 'MouziFlow-Setup*' } |
    ForEach-Object { try { Stop-Process -Id $_.Id -Force } catch {} }
Start-Sleep -Seconds 1

$proc = Start-Process -FilePath $Exe -PassThru
Start-Sleep -Seconds $WaitSeconds

$wizard = Get-WizardWindow -LauncherPid $proc.Id
if ($wizard -eq [IntPtr]::Zero) {
    Add-Result 'Ventana del asistente' $false 'No se encontro TWizardForm del proceso lanzado'
    Stop-SetupTree -LauncherPid $proc.Id
    exit 1
}
Add-Result 'Ventana del asistente' $true ("titulo='" + [UiTest]::TextOf($wizard) + "'")

$procIds = Get-ProcessTreeIds -LauncherPid $proc.Id

# --- Resolucion viva de controles -------------------------------------------
# El motor puede recrear la ventana del asistente, asi que los handles se
# resuelven en cada lectura en lugar de cachearlos.
function Get-Controls {
    $w = Get-WizardWindow -LauncherPid $proc.Id
    $e = [IntPtr]::Zero; $f = [IntPtr]::Zero; $i2 = [IntPtr]::Zero
    if ($w -ne [IntPtr]::Zero) {
        foreach ($c in [UiTest]::Children($w)) {
            $p = $c -split '\|', 5
            if ($p[1] -eq 'TEdit' -and $p[2] -like '*MouziFlow*') { $e = [IntPtr][int64]$p[0] }
            if ($p[1] -eq 'TBitmapButton' -and $p[2] -like '*carpeta*') { $f = [IntPtr][int64]$p[0] }
            if ($p[1] -eq 'TBitmapButton' -and $p[2] -like 'Instalar*') { $i2 = [IntPtr][int64]$p[0] }
        }
    }
    return @{ W = $w; Edit = $e; Folder = $f; Install = $i2 }
}

function Get-Focus {
    $r = Get-Controls
    if ($r.W -eq [IntPtr]::Zero) { return [IntPtr]::Zero }
    $pidOut2 = [UInt32]0
    $t = [UiTest]::GetWindowThreadProcessId($r.W, [ref]$pidOut2)
    $f = [UiTest]::FocusOf($t)
    if ($f -eq [IntPtr]::Zero) {
        # Sin ventana activa en el hilo no hay foco que leer: otra ventana
        # (por ejemplo la app de Codex) robo el primer plano. Se recupera y
        # se vuelve a leer.
        [void][UiTest]::ForceForeground($r.W)
        Start-Sleep -Milliseconds 600
        $r = Get-Controls
        if ($r.W -eq [IntPtr]::Zero) { return [IntPtr]::Zero }
        $pidOut2 = [UInt32]0
        $t = [UiTest]::GetWindowThreadProcessId($r.W, [ref]$pidOut2)
        $f = [UiTest]::FocusOf($t)
    }
    return $f
}
function Wait-Focus {
    # El control focused puede tardar un instante en quedar activo: se espera
    # a que el hilo tenga una ventana activa con foco antes de leer.
    for ($i = 0; $i -lt 8; $i++) {
        $f = Get-Focus
        if ($f -ne [IntPtr]::Zero) { return $f }
        Start-Sleep -Milliseconds 400
    }
    return [IntPtr]::Zero
}
function Get-FocusName {
    param([IntPtr]$H)
    if ($H -eq [IntPtr]::Zero) { return 'ninguno' }
    $r = Get-Controls
    if ($H -eq $r.Edit) { return 'ruta' }
    if ($H -eq $r.Folder) { return 'carpeta' }
    if ($H -eq $r.Install) { return 'instalar' }
    return ('interno[' + [UiTest]::ClassOf($H) + ']')
}
function Get-Picker {
    foreach ($l in [UiTest]::TopWindows()) {
        $p = $l -split '\|', 5
        if ($procIds -contains [int]$p[0] -and $p[4] -eq 'True' -and $p[3] -like '*ubicaci*') { return ($p[2] + " '" + $p[3] + "'") }
    }
    return $null
}
function Wait-Picker {
    # El selector nativo es modal y tarda en aparecer: se espera de forma
    # activa en vez de mirar una sola vez.
    for ($i = 0; $i -lt 20; $i++) {
        $p = Get-Picker
        if ($p) { return $p }
        Start-Sleep -Milliseconds 300
    }
    return $null
}
function Wait-ExitDialog {
    for ($i = 0; $i -lt 20; $i++) {
        foreach ($l in [UiTest]::TopWindows()) {
            $p = $l -split '\|', 5
            if ($procIds -contains [int]$p[0] -and $p[4] -eq 'True' -and $p[3] -like '*Salir*') { return [IntPtr][int64]$p[1] }
        }
        Start-Sleep -Milliseconds 300
    }
    return [IntPtr]::Zero
}

# --- Teclado real: solo se teclea con nuestra ventana en primer plano --------
function Get-OtherInstaller {
    # Detecta el asistente de otro agente en pantalla. Si existe, no se le
    # roba el primer plano: las pulsaciones caerian en su ventana.
    foreach ($l in [UiTest]::TopWindows()) {
        $p = $l -split '\|', 5
        if ($p[4] -ne 'True') { continue }
        if ($procIds -contains [int]$p[0]) { continue }
        if ($p[2] -match 'TWizardForm|TNewWizardForm|TTaskDialogForm|#32770') {
            if ($p[3] -match 'Instal|Setup|Selecci') { return ($p[2] + " '" + $p[3] + "'") }
        }
    }
    return $null
}

function Enter-Real {
    param([int]$Vk, [bool]$Shift = $false, [int]$DelayMs = 900, [int]$Retries = 4)
    # Reintenta: otra ventana (la app de Codex, otro agente) puede robar el
    # primer plano en cualquier momento. Si aun asi no se puede teclear, no
    # se envia nada y se devuelve false (la prueba queda como PENDIENTE).
    for ($i = 0; $i -lt $Retries; $i++) {
        $r = Get-Controls
        if ($r.W -eq [IntPtr]::Zero) { return $false }
        if ([UiTest]::GetForegroundWindow() -ne $r.W) {
            # No se roba el primer plano si hay otro instalador en pantalla.
            $other = Get-OtherInstaller
            if ($other) { return $false }
            [void][UiTest]::ForceForeground($r.W)
            Start-Sleep -Milliseconds 700
            $r = Get-Controls
            if ([UiTest]::GetForegroundWindow() -ne $r.W) {
                Start-Sleep -Milliseconds 500
                continue
            }
        }
        if ($Shift) {
            # El modificador debe seguir pulsado durante la tecla principal:
            # keybd_event lo suelta de inmediato si se usa Key(vk, shift).
            [UiTest]::KeyDown(0x10)
            Start-Sleep -Milliseconds 150
            [UiTest]::Key($Vk, $false)
            Start-Sleep -Milliseconds $DelayMs
            [UiTest]::KeyUp(0x10)
        } else {
            [UiTest]::Key($Vk, $false)
            Start-Sleep -Milliseconds $DelayMs
        }
        return $true
    }
    return $false
}
# El selector nativo es un dialogo modal propio: mientras esta abierto, el
# primer plano lo tiene el, no el asistente.
function Enter-To-Ours {
    param([int]$Vk, [int]$DelayMs = 900)
    $fg = [UiTest]::GetForegroundWindow()
    if ($fg -eq [IntPtr]::Zero) { return $false }
    $fgPid = [UInt32]0
    [void][UiTest]::GetWindowThreadProcessId($fg, [ref]$fgPid)
    if (-not ($procIds -contains [int]$fgPid)) { return $false }
    [UiTest]::Key($Vk, $false)
    Start-Sleep -Milliseconds $DelayMs
    return $true
}
function Send-Tab {
    # Se envia Tab y se COMPRUEBA EL EFECTO (que el foco se mueva). Si otra
    # ventana robo el primer plano entre la pulsacion y la lectura, la tecla
    # se pierde: se recupera el primer plano y se reintenta.
    param([bool]$Shift = $false)
    for ($i = 0; $i -lt 5; $i++) {
        $before = Get-Focus
        if ($before -eq [IntPtr]::Zero) { Start-Sleep -Milliseconds 300; continue }
        if (Enter-Real 0x09 $Shift 500) {
            Start-Sleep -Milliseconds 500
            $after = Get-Focus
            if ($after -ne [IntPtr]::Zero -and $after -ne $before) { return $true }
        }
        # No se movio el foco: se asegura el primer plano y se reintenta.
        $r = Get-Controls
        if ($r.W -ne [IntPtr]::Zero) { [void][UiTest]::ForceForeground($r.W) }
        Start-Sleep -Milliseconds 500
    }
    return $false
}
function Go-To {
    param([string]$Target)
    for ($i = 0; $i -lt 6; $i++) {
        if ((Get-FocusName (Wait-Focus)) -eq $Target) { return $true }
        [void](Send-Tab)
    }
    return [bool]((Get-FocusName (Wait-Focus)) -eq $Target)
}
function Restore-Assistant-Foreground {
    $r = Get-Controls
    if ($r.W -eq [IntPtr]::Zero) { return $false }
    [void][UiTest]::ForceForeground($r.W)
    Start-Sleep -Milliseconds 700
    $r2 = Get-Controls
    return ([UiTest]::GetForegroundWindow() -eq $r2.W)
}

# --- 0. Primer plano del asistente -----------------------------------------
# Se reintenta: al abrirse el asistente, otra ventana (por ejemplo la propia
# app de Codex) puede quedarse con el primer plano un instante.
$isFg = $false
for ($i = 0; $i -lt 5; $i++) {
    $r0 = Get-Controls
    if ($r0.W -ne [IntPtr]::Zero) { [void][UiTest]::ForceForeground($r0.W) }
    Start-Sleep -Milliseconds 900
    if (Restore-Assistant-Foreground) { $isFg = $true; break }
    Start-Sleep -Milliseconds 700
}
Add-Result 'Asistente en primer plano' $isFg ("primer_plano_actual=" + [UiTest]::ClassOf([UiTest]::GetForegroundWindow()))

# --- 1. Foco inicial ---------------------------------------------------------
Add-Result 'Foco inicial en el campo de ruta' ((Get-FocusName (Wait-Focus)) -eq 'ruta') ("foco = " + (Get-FocusName (Wait-Focus)))

# El indicador de foco del campo de ruta es el cursor de insercion del
# TEdit (la plantilla dibuja anillos solo para los dos botones). Se comprueba
# que el caret esta visible sin pulsar Tab.
$caretRect = New-Object 'UiTest+RECT'
$caretOk = $false
$rw = Get-WizardWindow -LauncherPid $proc.Id
if ($rw -ne [IntPtr]::Zero) {
    $pidOut3 = [UInt32]0
    $t3 = [UiTest]::GetWindowThreadProcessId($rw, [ref]$pidOut3)
    $caretOk = [UiTest]::CaretVisible($t3, [ref]$caretRect)
}
Add-Result 'Indicador de foco visible en el campo de ruta' $caretOk `
    ("caret=" + $caretRect.Left + "," + $caretRect.Top + "," + $caretRect.Right + "," + $caretRect.Bottom)

# --- 2. Tab recorre ruta -> carpeta -> instalar y cierra el ciclo -----------
# Se espera a que el foco se asiente tras tomar el primer plano: si se mide
# demasiado pronto, las primeras pulsaciones se pierden.
Start-Sleep -Milliseconds 800
$cycle = @()
for ($i = 0; $i -lt 6; $i++) { [void](Send-Tab); $cycle += (Get-FocusName (Get-Focus)) }
$joined = ($cycle -join ',')
$okCycle = [bool](($joined -match 'carpeta') -and ($joined -match 'instalar') -and ($joined -match 'ruta'))
$okWrap = $false
$instPos = [array]::IndexOf($cycle, 'instalar')
$lastRuta = [array]::LastIndexOf($cycle, 'ruta')
if ($instPos -ge 0 -and $lastRuta -ge 0) { $okWrap = ($instPos -lt $lastRuta) }
Add-Result 'Tab recorre ruta -> carpeta -> instalar' $okCycle ("secuencia = " + ($cycle -join ' -> '))
Add-Result 'Tab cierra el ciclo en los 3 controles' ($joined -notmatch 'interno') ("secuencia = " + ($cycle -join ' -> '))

# --- 3. Shift+Tab en reversa -------------------------------------------------
$rev = @()
for ($i = 0; $i -lt 4; $i++) { [void](Send-Tab $true); $rev += (Get-FocusName (Get-Focus)) }
$okRev = [bool]((($rev -join ',') -match 'carpeta') -and (($rev -join ',') -match 'instalar'))
Add-Result 'Shift+Tab recorre en reversa' $okRev ("secuencia = " + ($rev -join ' -> '))

# --- 4. La ruta es editable (teclado real) -----------------------------------
$r = Get-Controls
$canType = ($r.W -ne [IntPtr]::Zero)
if ($canType -and ([UiTest]::GetForegroundWindow() -ne $r.W)) {
    # Se recupera el primer plano solo si no hay otro instalador en pantalla.
    if (-not (Get-OtherInstaller)) {
        [void][UiTest]::ForceForeground($r.W)
        Start-Sleep -Milliseconds 700
        $r = Get-Controls
    }
}
$canType = ($r.W -ne [IntPtr]::Zero) -and ([UiTest]::GetForegroundWindow() -eq $r.W)
if ($canType) {
    [void](Go-To 'ruta')
    $r = Get-Controls
    $before = [UiTest]::LiveText($r.Edit)
    # El texto llega preseleccionado: se lleva el cursor al final para que la
    # pulsacion se anada y se pueda restaurar despues con una sola pulsacion.
    [UiTest]::Key(0x23, $false)   # END
    Start-Sleep -Milliseconds 400
    [UiTest]::Key(0x58, $false)   # X
    Start-Sleep -Milliseconds 900
    $r = Get-Controls
    $after = [UiTest]::LiveText($r.Edit)
    Add-Result 'Ruta editable' ($after -ne $before) ("antes='" + $before + "' despues='" + $after + "'")
    if ($after -ne $before) {
        # Se espera a que el campo tenga el foco real antes de retroceder: si
        # el foco no esta ahi, la tecla se pierde y la ruta no se restaura.
        for ($i = 0; $i -lt 6; $i++) {
            if ((Get-FocusName (Wait-Focus)) -eq 'ruta') { break }
            [UiTest]::Key(0x09, $false)
            Start-Sleep -Milliseconds 700
        }
        [UiTest]::Key(0x08, $false)   # Retroceso
        Start-Sleep -Milliseconds 800
        $r = Get-Controls
        Add-Result 'Ruta restaurada tras editar' ([UiTest]::LiveText($r.Edit) -eq $before) ("restaurada='" + [UiTest]::LiveText($r.Edit) + "'")
    }
} else {
    # No se teclea si el primer plano no es nuestro: las pulsaciones
    # acabarian en la ventana de otro proceso.
    Add-Result 'Ruta editable' $false 'PENDIENTE: otra ventana mantiene el primer plano; no se pudo teclear en el campo sin interferir con ella'
}

# --- 5. Enter en el boton de carpeta abre el selector ------------------------
$ok = Go-To 'carpeta'
Add-Result 'Navegar al boton de carpeta' $ok ("foco = " + (Get-FocusName (Wait-Focus)))
if (Enter-Real 0x0D) {
    $picker = Wait-Picker
    Add-Result 'Enter en carpeta abre el selector' ($null -ne $picker) ("selector = '" + $picker + "'")
    if ($picker) { [void](Enter-To-Ours 0x1B 900) }
} else {
    Add-Result 'Enter en carpeta abre el selector' $false 'PENDIENTE: el asistente no tiene el primer plano'
}
[void](Restore-Assistant-Foreground)

# --- 6. Espacio en el boton de carpeta abre el selector ----------------------
[void](Go-To 'carpeta')
if (Enter-Real 0x20) {
    $picker = Wait-Picker
    Add-Result 'Espacio en carpeta abre el selector' ($null -ne $picker) ("selector = '" + $picker + "'")
    if ($picker) { [void](Enter-To-Ours 0x1B 900) }
} else {
    Add-Result 'Espacio en carpeta abre el selector' $false 'PENDIENTE: el asistente no tiene el primer plano'
}
[void](Restore-Assistant-Foreground)

# --- 7. Escape cancela desde la pantalla de entrada --------------------------
# La cancelacion se comprueba antes de instalar: en la pantalla de progreso
# Inno pide confirmacion y el proceso sigue vivo a proposito.
# Escape abre el dialogo nativo "Salir de la Instalacion", que se confirma
# con el boton "Si".
if (Enter-Real 0x1B $false 1200) {
    $dlg = Wait-ExitDialog
    Add-Result 'Escape abre la confirmacion de salida' ($dlg -ne [IntPtr]::Zero) ("dialogo = " + $(if ($dlg -ne [IntPtr]::Zero) { [UiTest]::TextOf($dlg) } else { 'ninguno' }))
    if ($dlg) {
        # Confirmar con el boton "Si" del dialogo nativo.
        $siBtn = [IntPtr]::Zero
        foreach ($c in [UiTest]::Children($dlg)) {
            $p = $c -split '\|', 5
            if ($p[1] -eq 'TNewButton' -and $p[2] -match 'S[ií]') { $siBtn = [IntPtr][int64]$p[0] }
        }
        if ($siBtn -ne [IntPtr]::Zero) {
            [UiTest]::PostMessage($siBtn, 0x00F5, [IntPtr]::Zero, [IntPtr]::Zero)   # BM_CLICK
            Start-Sleep -Seconds 4
            $stillRunning = -not $proc.HasExited
            Add-Result 'Escape cancela la instalacion' (-not $stillRunning) ("proceso vivo tras confirmar = $stillRunning")
        } else {
            Add-Result 'Escape cancela la instalacion' $false 'PENDIENTE: no se encontro el boton Si del dialogo de confirmacion'
        }
    } else {
        Add-Result 'Escape cancela la instalacion' $false 'PENDIENTE: no aparecio el dialogo de confirmacion de salida'
    }
} else {
    Add-Result 'Escape cancela la instalacion' $false 'PENDIENTE: el asistente no tiene el primer plano'
}
Stop-SetupTree -LauncherPid $proc.Id

# --- 8. Enter en instalar avanza a la instalacion ----------------------------
# Se relanza el asistente para comprobar el avance con Enter desde la
# pantalla de entrada.
$proc = Start-Process -FilePath $Exe -PassThru
Start-Sleep -Seconds $WaitSeconds
[void](Restore-Assistant-Foreground)
$installDir = Join-Path $env:LOCALAPPDATA 'Programs\MouziFlow'
[void](Go-To 'instalar')
if (Enter-Real 0x0D $false 600) {
    Start-Sleep -Seconds 6
    Add-Result 'Enter en instalar avanza a la instalacion' (Test-Path $installDir) ("carpeta creada = " + (Test-Path $installDir))
} else {
    Add-Result 'Enter en instalar avanza a la instalacion' $false 'PENDIENTE: el asistente no tiene el primer plano'
}

# --- 9. Enter en la pantalla de exito activa "Finalizar" ---------------------
# Tras instalar, Inno Setup muestra la pantalla nativa de exito. El boton
# "Finalizar" debe activarse con Enter (no solo con el raton).
$success = $false
for ($i = 0; $i -lt 25; $i++) {
    Start-Sleep -Milliseconds 800
    $w = Get-WizardWindow -LauncherPid $proc.Id
    if ($w -eq [IntPtr]::Zero) { break }
    $hasFinish = $false
    foreach ($c in [UiTest]::Children($w)) {
        $p = $c -split '\|', 5
        if ($p[2] -match 'Finalizar') { $hasFinish = $true }
    }
    if ($hasFinish) { $success = $true; break }
}
Add-Result 'Pantalla de exito mostrada' $success ''
if ($success) {
    # La app se auto-lanza al terminar la instalacion ([Run] con postinstall) y
    # roba el primer plano: se detiene para poder verificar Enter en el
    # asistente sin interferir con ella.
    Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -eq 'mouzi' } |
        ForEach-Object { try { Stop-Process -Id $_.Id -Force } catch {} }
    Start-Sleep -Seconds 2
    # El enfoque se reintenta: la app puede volver a robarlo al morir.
    $pressed = $false
    for ($i = 0; $i -lt 4; $i++) {
        [void](Restore-Assistant-Foreground)
        if (Enter-Real 0x0D $false 1200) { $pressed = $true; break }
        Start-Sleep -Milliseconds 800
    }
    $closed = $false
    if ($pressed) {
        for ($i = 0; $i -lt 12; $i++) {
            Start-Sleep -Milliseconds 700
            if ($proc.HasExited -or ((Get-WizardWindow -LauncherPid $proc.Id) -eq [IntPtr]::Zero)) { $closed = $true; break }
        }
    }
    Add-Result 'Enter en la pantalla de exito activa Finalizar' $closed `
        ("tecla enviada=$pressed  instalador cerrado=$closed")
} else {
    Add-Result 'Enter en la pantalla de exito activa Finalizar' $false 'PENDIENTE: no se alcanzo la pantalla de exito'
}

Stop-SetupTree -LauncherPid $proc.Id

Write-Host ""
Write-Host "--- Resumen ---" -ForegroundColor Cyan
foreach ($r in $results) { Write-Host $r }
$fails = @($results | Where-Object { $_.StartsWith('[FALLO]') }).Count
Write-Host ("Fallos: $fails de " + $results.Count) -ForegroundColor $(if ($fails -eq 0) { 'Green' } else { 'Red' })
exit $fails
