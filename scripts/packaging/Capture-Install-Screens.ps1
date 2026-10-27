<#
.SYNOPSIS
    Captura las pantallas nativas de progreso y de exito del instalador de MouziFlow.

.DESCRIPTION
    Lanza el instalador REAL en modo interactivo, pulsa el boton principal con
    Enter y captura fotogramas sucesivos de la ventana del asistente hasta
    terminar. Cada fotograma se etiqueta con la pagina detectada (entrada,
    progreso o exito) para poder elegir las capturas finales.

    No depende del primer plano: las teclas se envian al control enfocado del
    propio asistente y las capturas se hacen con PrintWindow.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\scripts\packaging\Capture-Install-Screens.ps1 `
        -Exe .\packaging\windows\Output\MouziFlow-Setup-0.2.3.exe -OutDir .\temp-ui-debug\frames
#>
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [Parameter(Mandatory = $true)][string]$OutDir,
    [int]$Frames = 60,
    [int]$IntervalMs = 200
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'UiTestHelpers.ps1')
Add-Type -AssemblyName System.Drawing

if (-not ('SCap' -as [type])) {
    Add-Type @"
using System; using System.Runtime.InteropServices;
public class SCap {
  [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr dc, uint f);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
}
"@
}

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
Get-ChildItem -LiteralPath $OutDir -Filter 'frame-*.png' -ErrorAction SilentlyContinue |
    ForEach-Object { Remove-Item -LiteralPath $_.FullName -Force }

# Limpiar instancias previas del mismo instalador: interfieren con la captura.
Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -like 'MouziFlow-Setup*' } |
    ForEach-Object { try { Stop-Process -Id $_.Id -Force } catch {} }
Start-Sleep -Seconds 1

$proc = Start-Process -FilePath $Exe -PassThru
Start-Sleep -Seconds 8
$wizard = Get-WizardWindow -LauncherPid $proc.Id
if ($wizard -eq [IntPtr]::Zero) {
    Write-Output 'No se encontro la ventana del asistente'
    Stop-SetupTree -LauncherPid $proc.Id
    exit 1
}

$pidOut = [UInt32]0
$threadId = [UiTest]::GetWindowThreadProcessId($wizard, [ref]$pidOut)

# Resolver los controles en vivo: el motor puede recrear la ventana.
function Get-Controls {
    $w = Get-WizardWindow -LauncherPid $proc.Id
    $e = [IntPtr]::Zero; $f = [IntPtr]::Zero; $i2 = [IntPtr]::Zero
    foreach ($c in [UiTest]::Children($w)) {
        $p = $c -split '\|', 5
        if ($p[1] -eq 'TEdit' -and $p[2] -like '*MouziFlow*') { $e = [IntPtr][int64]$p[0] }
        if ($p[1] -eq 'TBitmapButton' -and $p[2] -like '*carpeta*') { $f = [IntPtr][int64]$p[0] }
        if ($p[1] -eq 'TBitmapButton' -and $p[2] -like 'Instalar*') { $i2 = [IntPtr][int64]$p[0] }
    }
    return @{ W = $w; Edit = $e; Folder = $f; Install = $i2 }
}
function Get-Focus {
    $r = Get-Controls
    if ($r.W -eq [IntPtr]::Zero) { return [IntPtr]::Zero }
    $pidOut2 = [UInt32]0
    $t = [UiTest]::GetWindowThreadProcessId($r.W, [ref]$pidOut2)
    return [UiTest]::FocusOf($t)
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

$ctrl = Get-Controls
Write-Output ("Controles: ruta=" + $ctrl.Edit + " carpeta=" + $ctrl.Folder + " instalar=" + $ctrl.Install)

# Llevar el foco al boton de instalar con Tab real (igual que un usuario).
[void][UiTest]::ForceForeground($ctrl.W)
Start-Sleep -Milliseconds 900
$focused = $false
for ($i = 0; $i -lt 6; $i++) {
    if ((Get-FocusName (Get-Focus)) -eq 'instalar') { $focused = $true; break }
    $ctrl = Get-Controls
    if ($ctrl.W -eq [IntPtr]::Zero) { break }
    if ([UiTest]::GetForegroundWindow() -ne $ctrl.W) {
        [void][UiTest]::ForceForeground($ctrl.W)
        Start-Sleep -Milliseconds 600
        $ctrl = Get-Controls
        if ([UiTest]::GetForegroundWindow() -ne $ctrl.W) { break }
    }
    [UiTest]::Key(0x09, $false)
    Start-Sleep -Milliseconds 800
}
Write-Output ("Foco en boton instalar: " + $focused + " (" + (Get-FocusName (Get-Focus)) + ")")
if (-not $focused) {
    Write-Output 'No se pudo enfocar el boton instalar; se aborta la captura.'
    Stop-SetupTree -LauncherPid $proc.Id
    exit 2
}

function Get-PageTag {
    param([IntPtr]$W)
    $texts = New-Object System.Collections.Generic.List[string]
    foreach ($c in [UiTest]::Children($W)) {
        $p = $c -split '\|', 5
        if ($p[3] -like '*,-1,*' -and $p[2]) { continue }
        $texts.Add($p[2])
    }
    $joined = ($texts -join ' | ')
    if ($joined -match 'Finalizar|Reiniciar|reinstalar|reiniciar') { return 'exito' }
    if ($joined -match 'Instalando|Preparándose|Preparando|Extrayendo|Copiando|Terminado|Desinstalando|Actualizando') { return 'progreso' }
    if ($joined -match 'Todo listo para comenzar|Ubicaci') { return 'entrada' }
    return 'otra'
}

function Save-Frame {
    param([IntPtr]$W, [string]$File, [string]$Tag)
    $r = New-Object 'SCap+RECT'
    [void][SCap]::GetWindowRect($W, [ref]$r)
    $ww = $r.Right - $r.Left; $hh = $r.Bottom - $r.Top
    if ($ww -le 0 -or $hh -le 0) { return $false }
    $bmp = New-Object System.Drawing.Bitmap $ww, $hh
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $hdc = $g.GetHdc()
    [void][SCap]::PrintWindow($W, $hdc, 2)
    $g.ReleaseHdc($hdc); $g.Dispose()
    $bmp.Save($File, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    Write-Output ("{0}  {1}  {2}x{3}" -f (Split-Path $File -Leaf), $Tag, $ww, $hh)
    return $true
}

# Pulsar Enter sobre el boton de instalar con teclado real.
$ctrl = Get-Controls
[void][UiTest]::ForceForeground($ctrl.W)
Start-Sleep -Milliseconds 800
$ctrl = Get-Controls
Write-Output ("Primer plano antes de Enter: " + [UiTest]::ClassOf([UiTest]::GetForegroundWindow()))

# Fotograma de la pantalla de ENTRADA, antes de pulsar Enter.
$entryFile = Join-Path $OutDir 'frame-entrada.png'
$w = Get-WizardWindow -LauncherPid $proc.Id
if ($w -ne [IntPtr]::Zero) {
    [void](Save-Frame -W $w -File $entryFile -Tag (Get-PageTag -W $w))
}

[UiTest]::Key(0x0D, $false)

for ($i = 0; $i -lt $Frames; $i++) {
    Start-Sleep -Milliseconds $IntervalMs
    $w = Get-WizardWindow -LauncherPid $proc.Id
    if ($w -eq [IntPtr]::Zero) { break }
    $tag = Get-PageTag -W $w
    $file = Join-Path $OutDir ("frame-{0:D2}-{1}.png" -f $i, $tag)
    [void](Save-Frame -W $w -File $file -Tag $tag)
}

Stop-SetupTree -LauncherPid $proc.Id
Write-Output 'Captura finalizada.'
