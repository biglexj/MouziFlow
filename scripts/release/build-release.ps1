param(
    [string]$Version,
    [string]$ReleaseNotes,
    [switch]$LocalOnly,
    [switch]$SkipBuild,
    [switch]$SkipAuroraUpload
)

$ErrorActionPreference = "Stop"

$root = if (Test-Path (Join-Path $PSScriptRoot "package.json")) {
    $PSScriptRoot
} else {
    (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
}

. (Join-Path $root "scripts\release\ReleaseTools.ps1")

$releaseDir = Join-Path $root "release"
$packageFile = Join-Path $root "package.json"
$repository = "biglexj/MouziFlow"
$appName = "MouziFlow"

# 1. Determinar versión
if (-not $Version) {
    $packageJson = Get-Content $packageFile -Raw -Encoding UTF8 | ConvertFrom-Json
    $Version = $packageJson.version
    if (-not $Version) {
        throw "No se pudo determinar la versión en package.json"
    }
}
Assert-SemanticVersion $Version

Write-Host ""
Write-Host "══════════════════════════════════════════" -ForegroundColor Magenta
Write-Host "  MouziFlow — Release v$Version" -ForegroundColor Magenta
Write-Host "══════════════════════════════════════════" -ForegroundColor Magenta
Write-Host ""

# 2. Compilar Aplicación (Tauri v2 + NSIS)
if (-not $SkipBuild) {
    Write-Host "[1/4] Compilando instalador de MouziFlow (Tauri v2)..." -ForegroundColor Yellow
    Push-Location $root
    try {
        if (Get-Command bun -ErrorAction SilentlyContinue) {
            bun run tauri build
            if ($LASTEXITCODE -ne 0) { throw "La compilación de Tauri falló con código $LASTEXITCODE" }
            bun scripts/copy-build-releases.ts
        } else {
            npm run tauri build
            if ($LASTEXITCODE -ne 0) { throw "La compilación de Tauri falló con código $LASTEXITCODE" }
            node scripts/copy-build-releases.ts
        }
    } finally {
        Pop-Location
    }
} else {
    Write-Host "[1/4] Compilación omitida (-SkipBuild)..." -ForegroundColor DarkGray
}

if (-not (Test-Path $releaseDir)) {
    New-Item -ItemType Directory -Force -Path $releaseDir | Out-Null
}

$installerTarget = Join-Path $releaseDir "MouziFlow_${Version}_x64-setup.exe"
if (-not (Test-Path $installerTarget)) {
    # Intentar buscar en bundle nativo si no se copió
    $bundleSource = Join-Path $root "src-tauri\target\release\bundle\nsis\MouziFlow_${Version}_x64-setup.exe"
    if (Test-Path $bundleSource) {
        Copy-Item $bundleSource $installerTarget -Force
    } else {
        # Fallback a nombre anterior si existiera
        $legacyInstaller = Join-Path $releaseDir "Mouzi_${Version}_x64-setup.exe"
        if (Test-Path $legacyInstaller) {
            $installerTarget = $legacyInstaller
        } else {
            throw "No se encontró el instalador generado en: $installerTarget"
        }
    }
}

# Generar o verificar SHA256SUMS.txt
$hashFile = Join-Path $releaseDir "SHA256SUMS.txt"
$sha256 = (Get-FileHash -LiteralPath $installerTarget -Algorithm SHA256).Hash.ToLowerInvariant()
"{0}  {1}" -f $sha256, (Split-Path $installerTarget -Leaf) | Set-Content -LiteralPath $hashFile -Encoding UTF8

Write-Host "Instalador empaquetado en: $installerTarget" -ForegroundColor Green
Write-Host "Checksum SHA-256: $sha256" -ForegroundColor Cyan

if ($LocalOnly) {
    Write-Host "Build local completado (-LocalOnly)." -ForegroundColor Green
    exit 0
}

# 3. Git commit & tag
Write-Host "[2/4] Registrando en Git..." -ForegroundColor Yellow
$branchOut = (& git branch --show-current)
$currentBranch = if ($branchOut) { "$branchOut".Trim() } else { "main" }
if (-not $currentBranch) { $currentBranch = "main" }

git add -A
$hasStagedChanges = (& git status --porcelain)
if ($hasStagedChanges) {
    git commit -m "release: v$Version - Publicación oficial MouziFlow"
}

$tag = "v$Version"
$tagOut = (& git tag -l $tag)
$hasTag = if ($tagOut) { "$tagOut".Trim() } else { "" }
if (-not $hasTag) {
    git tag -a $tag -m "Release $tag"
}

$hasRemote = (& git remote)
if (-not $hasRemote) {
    Write-Host "ℹ️ No hay remoto configurado. Verificando repositorio en GitHub..." -ForegroundColor Cyan
    $repoExists = $false
    try {
        & gh repo view $repository --json name *> $null
        if ($LASTEXITCODE -eq 0) { $repoExists = $true }
    } catch {}

    if (-not $repoExists) {
        Write-Host "Creando repositorio remoto $repository en GitHub..." -ForegroundColor Yellow
        gh repo create $repository --public --source=. --remote=origin --description "Organizador automático y visor de descargas inteligente con reglas y filtros en tiempo real."
    } else {
        git remote add origin "https://github.com/$repository.git"
    }
}

# Push a origin
git push origin "$currentBranch" --tags

# 4. GitHub Release
Write-Host "[3/4] Publicando GitHub Release $tag..." -ForegroundColor Yellow
$releaseNotesFile = Join-Path $root "RELEASE_MESSAGE.md"

$assetsToUpload = @($installerTarget, $hashFile)

if (-not $ReleaseNotes) {
    if (Test-Path $releaseNotesFile) {
        gh release create $tag $assetsToUpload --repo $repository --title "MouziFlow $tag" -F $releaseNotesFile
    } else {
        gh release create $tag $assetsToUpload --repo $repository --title "MouziFlow $tag" --notes "Lanzamiento oficial de MouziFlow $tag"
    }
} else {
    gh release create $tag $assetsToUpload --repo $repository --title "MouziFlow $tag" --notes $ReleaseNotes
}

$githubTagUrl = "https://github.com/$repository/releases/tag/$tag"
$assetFileName = Split-Path $installerTarget -Leaf
$githubAssetUrl = "https://github.com/$repository/releases/download/$tag/$assetFileName"

Write-Host ""
Write-Host "══════════════════════════════════════════" -ForegroundColor Green
Write-Host "  ¡Release $tag publicado en GitHub con éxito!" -ForegroundColor Green
Write-Host "══════════════════════════════════════════" -ForegroundColor Green
Write-Host "  $githubTagUrl" -ForegroundColor Cyan

# 5. Notificar a Aurora Blog (biglexj.com) — SOLO METADATA
if ($SkipAuroraUpload) {
    Write-Host "[4/4] Notificación a Aurora omitida (-SkipAuroraUpload)." -ForegroundColor DarkGray
} else {
    Write-Host "[4/4] Notificando release metadata a Aurora (biglexj.com)..." -ForegroundColor Yellow

    $auroraEnvPath = "D:\Proyectos\biglexj\Aurora---Blog\frontend\.env"
    if (Test-Path $auroraEnvPath) {
        $auroraEnv = Get-Content $auroraEnvPath -Raw -Encoding UTF8
        $serviceKey = [regex]::Match($auroraEnv, '(?m)^SUPABASE_SERVICE_ROLE_KEY=(.+)$').Groups[1].Value.Trim()

        if ($serviceKey) {
            $baseUrl = "https://www.biglexj.com"
            $slug = "mouziflow"

            $releaseMsg = if (Test-Path $releaseNotesFile) {
                [System.IO.File]::ReadAllText($releaseNotesFile, [System.Text.Encoding]::UTF8)
            } else { "MouziFlow $tag" }

            try {
                $vParts = $Version.Split('.')
                $calcVersionCode = if ($vParts.Length -ge 3) {
                    [int]$vParts[0] * 10000 + [int]$vParts[1] * 100 + [int]$vParts[2]
                } else { 10 }

                $releaseBody = @{
                    slug           = $slug
                    downloadUrl    = $githubAssetUrl
                    versionName    = $Version
                    versionCode    = $calcVersionCode
                    releaseNotes   = $releaseMsg
                    sha256Checksum = $sha256
                } | ConvertTo-Json -Depth 5

                Invoke-RestMethod -Uri "$baseUrl/api/admin/developer-apps" -Method PUT `
                    -Headers @{
                        "Content-Type" = "application/json"
                        Authorization  = "Bearer $serviceKey"
                    } `
                    -Body $releaseBody | Out-Null

                Write-Host ""
                Write-Host "══════════════════════════════════════════" -ForegroundColor Cyan
                Write-Host "  ✅ MouziFlow $tag notificado a biglexj.com" -ForegroundColor Cyan
                Write-Host "  Binario (GitHub): $githubAssetUrl" -ForegroundColor Cyan
                Write-Host "══════════════════════════════════════════" -ForegroundColor Cyan
            } catch {
                Write-Host "  ⚠️ Error durante la notificación a biglexj.com: $_" -ForegroundColor DarkYellow
            }
        } else {
            Write-Host "  ⚠️ No se encontró SUPABASE_SERVICE_ROLE_KEY en $auroraEnvPath" -ForegroundColor DarkGray
        }
    } else {
        Write-Host "  ⚠️ No se encontró $auroraEnvPath" -ForegroundColor DarkGray
    }
}
