<#
.SYNOPSIS
    Empaqueta MouziFlow para Windows usando Inno Setup 6.

.DESCRIPTION
    Reemplaza el instalador NSIS que generaba Tauri v2. Pasos:
      1. Resuelve la version real y reescribe packaging\windows\version.iss.
      2. Copia el icono real de la app al folder de packaging.
      3. Compila la app con Tauri (salvo que se use -SkipBuild).
      4. Prepara una carpeta de staging con el ejecutable y los recursos.
      5. Invoca ISCC.exe y deja el instalador .exe en la carpeta release\.

    Antes de invocar ISCC.exe el builder sincroniza la plantilla visual
    compartida y pasa el validador de invariantes de empaquetado
    (Scripts\tools\inno\Check-Packaging.ps1), que aborta la compilacion si el
    arranque post-instalacion vuelve a lanzar la app directamente desde el
    instalador (fallo 0xc00004bc), si el nombre de salida lleva el sufijo
    obsoleto _x64 o si la plantilla visual diverge de la compartida.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\scripts\packaging\Build-Installer.ps1

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\scripts\packaging\Build-Installer.ps1 -SkipBuild
#>
param(
    [string]$Version,
    [switch]$SkipBuild,
    [switch]$LightTheme,
    # Empaqueta aunque el ejecutable sea mas viejo que las fuentes. Solo para
    # depurar: publicar asi reintroduce el binario obsoleto.
    [switch]$ForceStale,
    [string]$IsccPath = ""
)

$ErrorActionPreference = "Stop"

$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$packagingDir = Join-Path $root "packaging\windows"
$releaseDir = Join-Path $root "release"
$targetRelease = Join-Path $root "src-tauri\target\release"
$lightOutputDir = Join-Path $packagingDir "Output-light"
$stageAppDir = Join-Path $packagingDir "app"
$appExeName = "mouzi.exe"

. (Join-Path $root "scripts\release\ReleaseTools.ps1")

function Write-Step {
    param([string]$Message)
    Write-Host "  -> $Message" -ForegroundColor DarkGray
}

function Write-Fail {
    param([string]$Text)
    Write-Host "ERROR: $Text" -ForegroundColor Red
    throw $Text
}

# --- Puerta de calidad de empaquetado (validador compartido) -----------------
# La plantilla visual y el arranque post-instalacion son fuente unica del
# workspace. Un [Run] editado a mano que lance la app directamente desde el
# instalador hace que el proceso herede su contexto y muera con 0xc00004bc
# (STATUS_REDIRECTION_TRUST_FAILURE), asi que el validador compartido aborta
# la compilacion antes de invocar ISCC.exe.
function Resolve-SharedInno {
    $dir = $PSScriptRoot
    for ($i = 0; $i -lt 8; $i++) {
        $candidate = Join-Path $dir 'Scripts\tools\inno'
        if (Test-Path -LiteralPath $candidate) { return $candidate }
        $parent = Split-Path -Parent $dir
        if (-not $parent -or $parent -eq $dir) { break }
        $dir = $parent
    }
    return $null
}

function Sync-SharedTemplate {
    param([string]$SharedDir, [string]$PackagingDir)
    if (-not $SharedDir) { return }
    $src = Join-Path $SharedDir 'BiglexModernUI.iss'
    $dst = Join-Path $PackagingDir 'BiglexModernUI.iss'
    if ((Test-Path -LiteralPath $src) -and (Test-Path -LiteralPath $PackagingDir)) {
        Copy-Item -LiteralPath $src -Destination $dst -Force
        Write-Step "Plantilla visual sincronizada con la copia compartida del workspace."
    }
}

function Assert-PackagingInvariants {
    param([string]$SharedDir, [string[]]$SetupFiles)
    if (-not $SharedDir) {
        Write-Host 'AVISO: no se encontro la carpeta compartida Scripts\tools\inno.' -ForegroundColor Yellow
        Write-Host '       Se omite la validacion de invariantes de empaquetado.' -ForegroundColor Yellow
        return
    }
    $checker = Join-Path $SharedDir 'Check-Packaging.ps1'
    if (-not (Test-Path -LiteralPath $checker)) {
        Write-Host "AVISO: no se encontro $checker. Se omite la validacion." -ForegroundColor Yellow
        return
    }
    # Get-Command puede devolver varias rutas (alias de Store y MSIX): se toma
    # la primera que exista de verdad.
    $shellExe = $null
    foreach ($name in @('pwsh', 'powershell')) {
        foreach ($candidate in @(Get-Command $name -CommandType Application -ErrorAction SilentlyContinue)) {
            if ($candidate.Source -and (Test-Path -LiteralPath $candidate.Source)) {
                $shellExe = $candidate.Source
                break
            }
        }
        if ($shellExe) { break }
    }
    if (-not $shellExe) {
        Write-Host 'AVISO: no se encontro pwsh ni powershell: se omite la validacion.' -ForegroundColor Yellow
        return
    }
    foreach ($setup in $SetupFiles) {
        & $shellExe -NoProfile -ExecutionPolicy Bypass -File $checker -SetupIss $setup
        if ($LASTEXITCODE -ne 0) {
            Write-Host "ERROR: las invariantes de empaquetado fallan para $setup." -ForegroundColor Red
            Write-Host '       No se compila el instalador. Corrige lo anterior.' -ForegroundColor Red
            exit 1
        }
    }
}

# --- Candado anti-binario-obsoleto ------------------------------------------
# Tauri incrusta dist/ DENTRO del ejecutable. Si el .exe es mas viejo que el
# codigo fuente o que dist/, el instalador empaqueta un binario obsoleto aunque
# se compile "recien" y aunque dist/ este al dia. Regla de Core:
# Docs/global/architecture/command-scripts-standard.md, principio 2.
# Get-Sha256Hex vive en scripts\release\ReleaseTools.ps1 (API de .NET en lugar
# de Get-FileHash: ese cmdlet no esta disponible en el modulo
# Microsoft.PowerShell.Utility cuando `powershell` se invoca con -NoProfile,
# que es como lo llama el pipeline de release).

function Get-NewestWriteTime {
    param([string[]]$Paths)
    $best = $null
    $bestPath = $null
    foreach ($path in $Paths) {
        if (-not (Test-Path -LiteralPath $path)) { continue }
        $item = if (Test-Path -LiteralPath $path -PathType Container) {
            Get-ChildItem -LiteralPath $path -Recurse -File -Force -ErrorAction SilentlyContinue |
                Sort-Object LastWriteTime -Descending | Select-Object -First 1
        }
        else {
            Get-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
        }
        if ($item -and (-not $best -or $item.LastWriteTime -gt $best)) {
            $best = $item.LastWriteTime
            $bestPath = $item.FullName
        }
    }
    return [pscustomobject]@{ Time = $best; Path = $bestPath }
}

function Assert-BinaryFresh {
    param([string]$Exe, [string]$AppRoot, [switch]$Force)
    if (-not (Test-Path -LiteralPath $Exe)) {
        Write-Fail "No se encontro el ejecutable compilado: $Exe`n  Compila la app sin el flag de omision."
    }
    $exeItem = Get-Item -LiteralPath $Exe
    $newest = Get-NewestWriteTime -Paths @(
        (Join-Path $AppRoot 'src'),
        (Join-Path $AppRoot 'src-tauri\src'),
        (Join-Path $AppRoot 'dist'),
        (Join-Path $AppRoot 'src-tauri\Cargo.toml'),
        (Join-Path $AppRoot 'src-tauri\tauri.conf.json'),
        (Join-Path $AppRoot 'src-tauri\build.rs'),
        (Join-Path $AppRoot 'src-tauri\capabilities'),
        (Join-Path $AppRoot 'package.json')
    )
    if (-not $newest.Time) { return }
    if ($exeItem.LastWriteTime -ge $newest.Time) {
        Write-Step "Ejecutable al dia: $($exeItem.LastWriteTime.ToString('dd/MM HH:mm:ss'))"
        return
    }
    $rel = if ($newest.Path) { $newest.Path.Substring($AppRoot.Length).TrimStart('\') } else { '(desconocido)' }
    if ($Force) {
        Write-Host "AVISO: se empaqueta un binario OBSOLETO por -ForceStale." -ForegroundColor Yellow
        Write-Host "       exe $($exeItem.LastWriteTime.ToString('dd/MM HH:mm:ss')) < fuente $($newest.Time.ToString('dd/MM HH:mm:ss')) $rel" -ForegroundColor Yellow
        return
    }
    Write-Fail ("El ejecutable es MAS VIEJO que el codigo fuente:`n" +
                "  ejecutable : $($exeItem.LastWriteTime.ToString('dd/MM HH:mm:ss'))  $Exe`n" +
                "  fuente     : $($newest.Time.ToString('dd/MM HH:mm:ss'))  $rel`n`n" +
                "Tauri incrusta dist/ dentro del ejecutable, asi que un .exe viejo publica`n" +
                "tambien un frontend viejo aunque dist/ este al dia. Vuelve a compilar la app" +
                ", o usa -ForceStale solo para depurar.")
}

# Localiza ISCC.exe sin rutas absolutas: primero la copia del workspace,
# subiendo desde este script; despues el PATH del sistema.
function Resolve-Iscc {
    $dir = $PSScriptRoot
    for ($i = 0; $i -lt 8; $i++) {
        $candidate = Join-Path $dir 'Scripts\tools\InnoSetup\ISCC.exe'
        if (Test-Path -LiteralPath $candidate) { return $candidate }
        $parent = Split-Path -Parent $dir
        if (-not $parent -or $parent -eq $dir) { break }
        $dir = $parent
    }
    $onPath = Get-Command ISCC.exe -ErrorAction SilentlyContinue
    if ($onPath) { return $onPath.Source }
    return $null
}

Write-Host ""
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "  MouziFlow - Empaquetado Windows (Inno Setup 6)" -ForegroundColor Cyan
Write-Host "======================================================" -ForegroundColor Cyan

# --- 1. Version --------------------------------------------------------------
if (-not $Version) {
    $packageJson = Get-Content (Join-Path $root "package.json") -Raw -Encoding UTF8 | ConvertFrom-Json
    $Version = $packageJson.version
    if (-not $Version) {
        $tauriConf = Get-Content (Join-Path $root "src-tauri\tauri.conf.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $Version = $tauriConf.version
    }
    if (-not $Version) {
        throw "No se pudo determinar la version de la app."
    }
}
Assert-SemanticVersion $Version
$lightBaseName = "MouziFlow-Setup-$Version-light"
Write-Step "Version: $Version"

# --- 2. version.iss ----------------------------------------------------------
$versionIss = @"
; ---------------------------------------------------------------------------
; version.iss -.generado por scripts/packaging/Build-Installer.ps1 con la
; version real de la app. El script de build reescribe este archivo en cada
; release; no editar a mano.
;   #define MyAppVersion "$Version"
; ---------------------------------------------------------------------------
#define MyAppVersion "$Version"
"@
$versionIssPath = Join-Path $packagingDir "version.iss"
[System.IO.File]::WriteAllText(
    $versionIssPath,
    $versionIss,
    (New-Object System.Text.UTF8Encoding($false))
)
Write-Step "Generado $versionIssPath"

# --- 3. Icono real de la app -------------------------------------------------
$iconSource = Join-Path $root "src-tauri\icons\icon.ico"
if (-not (Test-Path -LiteralPath $iconSource)) {
    throw "No se encontro el icono de la app en: $iconSource"
}
Copy-Item -LiteralPath $iconSource -Destination (Join-Path $packagingDir "icon.ico") -Force
Write-Step "Icono actualizado desde src-tauri\icons\icon.ico"

# --- 4. Compilar la app con Tauri -------------------------------------------
if (-not $SkipBuild) {
    Write-Host "[1/4] Compilando la app con Tauri..." -ForegroundColor Yellow
    Push-Location $root
    try {
        if (Get-Command bun -ErrorAction SilentlyContinue) {
            bun run tauri build
        } else {
            npm run tauri build
        }
        if ($LASTEXITCODE -ne 0) {
            throw "La compilacion de Tauri fallo con codigo $LASTEXITCODE."
        }
    } finally {
        Pop-Location
    }
} else {
    Write-Host "[1/4] Compilacion omitida (-SkipBuild)." -ForegroundColor DarkGray
}

$builtExe = Join-Path $targetRelease $appExeName
Assert-BinaryFresh -Exe $builtExe -AppRoot $root -Force:$ForceStale
Write-Step "Ejecutable: $builtExe"

# --- 5. Staging --------------------------------------------------------------
Write-Host "[2/4] Preparando la carpeta de staging..." -ForegroundColor Yellow
if (Test-Path -LiteralPath $stageAppDir) {
    Remove-Item -LiteralPath $stageAppDir -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $stageAppDir | Out-Null
Copy-Item -LiteralPath $builtExe -Destination (Join-Path $stageAppDir $appExeName) -Force

# Recursos opcionales (no existen hoy, pero el payload queda completo).
$resourcesSource = Join-Path $root "src-tauri\resources"
if (Test-Path -LiteralPath $resourcesSource) {
    Copy-Item -LiteralPath $resourcesSource -Destination (Join-Path $stageAppDir "resources") -Recurse -Force
    Write-Step "Recursos copiados desde src-tauri\resources"
}
Write-Step "Staging: $stageAppDir"

# --- 6. Compilar el instalador ----------------------------------------------
Write-Host "[3/4] Compilando el instalador con ISCC..." -ForegroundColor Yellow
if (-not $IsccPath) { $IsccPath = Resolve-Iscc }
if (-not $IsccPath) { Write-Fail 'No se localizo ISCC.exe en Scripts\tools\InnoSetup ni en el PATH.' }
if (-not (Test-Path -LiteralPath $IsccPath)) {
    throw "No se encontro el compilador de Inno Setup en: $IsccPath"
}

# Limpiar instaladores previos de las carpetas de salida: si no, se arrastran
# artefactos de versiones o temas anteriores.
foreach ($outDir in @((Join-Path $packagingDir "Output"), $lightOutputDir)) {
    if (Test-Path -LiteralPath $outDir) {
        Get-ChildItem -LiteralPath $outDir -Filter "MouziFlow-Setup*.exe" -File -ErrorAction SilentlyContinue |
            ForEach-Object { Remove-Item -LiteralPath $_.FullName -Force }
    }
}

$setupIss = Join-Path $packagingDir "setup.iss"
$sharedInno = Resolve-SharedInno
Sync-SharedTemplate -SharedDir $sharedInno -PackagingDir $packagingDir
Assert-PackagingInvariants -SharedDir $sharedInno -SetupFiles @($setupIss)

Push-Location $packagingDir
try {
    & $IsccPath "setup.iss"
    if ($LASTEXITCODE -ne 0) {
        throw "ISCC fallo con codigo $LASTEXITCODE."
    }

    if ($LightTheme) {
        Write-Host "     Compilando la variante clara de verificacion..." -ForegroundColor Yellow
        # Mismo script, tema forzado por linea de comandos. identity.iss solo
        # define MyAppTheme si no viene definido, asi que /D tiene prioridad.
        & $IsccPath "setup.iss" "/DMyAppTheme=light" "/O$lightOutputDir" "/F$lightBaseName"
        if ($LASTEXITCODE -ne 0) {
            throw "ISCC fallo (variante clara) con codigo $LASTEXITCODE."
        }
    }
} finally {
    Pop-Location
}

$builtInstaller = Join-Path $packagingDir "Output\MouziFlow-Setup-$Version.exe"
if (-not (Test-Path -LiteralPath $builtInstaller)) {
    throw "ISCC no genero el instalador esperado: $builtInstaller"
}
# --- 7. Publicar en release\ ------------------------------------------------
Write-Host "[4/4] Publicando el instalador en release\..." -ForegroundColor Yellow
if (-not (Test-Path -LiteralPath $releaseDir)) {
    New-Item -ItemType Directory -Force -Path $releaseDir | Out-Null
}
$releaseInstaller = Join-Path $releaseDir "MouziFlow_${Version}-setup.exe"
Copy-Item -LiteralPath $builtInstaller -Destination $releaseInstaller -Force

# Sincronizar copia en '12. Releases'
$releasesGlobalDir = 'D:\Proyectos\biglexj\12. Releases'
if (Test-Path -LiteralPath $releasesGlobalDir) {
    $installerLeaf = Split-Path $releaseInstaller -Leaf
    Get-ChildItem -LiteralPath $releasesGlobalDir -Filter "MouziFlow_*-setup.exe" -File |
        Where-Object { $_.Name -ne $installerLeaf } |
        ForEach-Object { Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue }
    Copy-Item -LiteralPath $releaseInstaller -Destination (Join-Path $releasesGlobalDir $installerLeaf) -Force
    Write-Host "Copia sincronizada en 12. Releases\$installerLeaf" -ForegroundColor Green
}

$sha256 = (Get-Sha256Hex -LiteralPath $releaseInstaller).ToLowerInvariant()
("{0}  {1}" -f $sha256, (Split-Path $releaseInstaller -Leaf)) |
    Set-Content -LiteralPath (Join-Path $releaseDir "SHA256SUMS.txt") -Encoding UTF8

Write-Host ""
Write-Host "Instalador: $releaseInstaller" -ForegroundColor Green
Write-Host "SHA-256:    $sha256" -ForegroundColor Cyan
if ($LightTheme) {
    $lightInstaller = Join-Path $lightOutputDir "$lightBaseName.exe"
    Write-Host "Variante clara (prueba): $lightInstaller" -ForegroundColor Cyan
}
Write-Host ""
