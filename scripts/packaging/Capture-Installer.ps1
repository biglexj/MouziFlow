<#
.SYNOPSIS
    Captura la pantalla de entrada del instalador de MouziFlow sin traarla al frente.

.DESCRIPTION
    Lanza el instalador, espera a que aparezca la ventana del asistente y la
    guarda en PNG usando PrintWindow (P/Invoke). Es la forma de verificar
    visualmente la pantalla unica de entrada en maquinas en tema oscuro.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\scripts\packaging\Capture-Installer.ps1 `
        -Exe .\packaging\windows\Output\MouziFlow-Setup-0.2.3.exe `
        -Out .\captura-oscuro.png
#>
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [Parameter(Mandatory = $true)][string]$Out,
    [int]$WaitSeconds = 8
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

if (-not ('Win4' -as [type])) {
    Add-Type @"
using System;
using System.Text;
using System.Collections.Generic;
using System.Runtime.InteropServices;
public class Win4 {
  public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);
  [DllImport("user32.dll")] public static extern int GetClassName(IntPtr hWnd, StringBuilder lpClassName, int nMaxCount);
  [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);
  [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr hwnd, IntPtr hdcBlt, uint nFlags);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hwnd, out RECT lpRect);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
  public static List<string> Dump() {
    var res = new List<string>();
    EnumWindows((h, l) => {
      var c = new StringBuilder(256); GetClassName(h, c, 256);
      var t = new StringBuilder(512); GetWindowText(h, t, 512);
      uint pid; GetWindowThreadProcessId(h, out pid);
      if (IsWindowVisible(h)) res.Add(pid + "|" + h.ToInt64() + "|" + c.ToString() + "|" + t.ToString());
      return true;
    }, IntPtr.Zero);
    return res;
  }
}
"@
}

$proc = Start-Process -FilePath $Exe -PassThru
Start-Sleep -Seconds $WaitSeconds

# El lanzador de Inno Setup crea un proceso hijo: se aceptan ambos PIDs para
# no capturar ventanas de otros instaladores que esten corriendo en paralelo.
$ownedPids = @($proc.Id)
try {
    $children = Get-CimInstance Win32_Process -Filter "ParentProcessId=$($proc.Id)" -ErrorAction SilentlyContinue
    $ownedPids += @($children | ForEach-Object { [int]$_.ProcessId })
} catch {}

$target = [IntPtr]::Zero
$alt = [IntPtr]::Zero
foreach ($l in [Win4]::Dump()) {
    $p = $l -split '\|', 4
    if ($ownedPids -notcontains [int]$p[0]) { continue }
    if ($p[2] -match 'TWizardForm') { $target = [IntPtr][int64]$p[1]; Write-Output "TARGET pid=$($p[0]) $($p[2]) $($p[3])"; break }
    elseif ($p[2] -match 'TTaskDialogForm|#32770') { $alt = [IntPtr][int64]$p[1]; Write-Output "ALT pid=$($p[0]) $($p[2]) $($p[3])" }
}
if ($target -eq [IntPtr]::Zero -and $alt -ne [IntPtr]::Zero) { $target = $alt }
if ($target -eq [IntPtr]::Zero) { Write-Output 'NONE'; exit 1 }

$r = New-Object 'Win4+RECT'
[void][Win4]::GetWindowRect($target, [ref]$r)
$w = $r.Right - $r.Left
$ht = $r.Bottom - $r.Top
$bmp = New-Object System.Drawing.Bitmap $w, $ht
$g = [System.Drawing.Graphics]::FromImage($bmp)
$hdc = $g.GetHdc()
[void][Win4]::PrintWindow($target, $hdc, 2)
$g.ReleaseHdc($hdc)
$g.Dispose()
$bmp.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
Write-Output "SAVED $Out ${w}x${ht}"

Get-Process -Id $proc.Id -ErrorAction SilentlyContinue | ForEach-Object {
    try { Stop-Process -Id $_.Id -Force } catch {}
}
# Solo se cierran los procesos lanzados por este script: no se toca ningun otro
# instalador que pueda estar corriendo en paralelo en la misma sesion.
$ownedPids | ForEach-Object {
    Get-Process -Id $_ -ErrorAction SilentlyContinue | ForEach-Object {
        try { Stop-Process -Id $_.Id -Force } catch {}
    }
}
