#!/usr/bin/env pwsh
# Builda o Flutter web, materializa no wwwroot/ do backend, republica
# o .NET, e reinicia o servico Windows. Uso:
#
#   .\scripts\deploy-frontend.ps1
#   .\scripts\deploy-frontend.ps1 -ServiceName MeuServico
#   .\scripts\deploy-frontend.ps1 -SkipServiceRestart
#
# Pre-requisito: o `flutter` precisa estar no PATH e a restauracao
# (`flutter pub get`) ja deve ter sido feita pelo menos uma vez.

[CmdletBinding()]
param(
    [string]$ServiceName = 'FluxoCaixa',
    [switch]$SkipServiceRestart
)

$ErrorActionPreference = 'Stop'

$repoRoot     = Resolve-Path (Join-Path $PSScriptRoot '..')
$frontendDir  = Join-Path $repoRoot 'frontend'
$backendDir   = Join-Path $repoRoot 'backend\FluxoCaixa.Api'
$wwwrootDir   = Join-Path $backendDir 'wwwroot'
$flutterBuild = Join-Path $frontendDir 'build\web'

# --- 1. flutter build web -----------------------------------------------------
Write-Host '==> 1/4  flutter build web --release' -ForegroundColor Cyan
Push-Location $frontendDir
try {
    flutter build web --release
    if ($LASTEXITCODE -ne 0) { throw "flutter build web falhou (exit $LASTEXITCODE)" }
} finally {
    Pop-Location
}
if (-not (Test-Path $flutterBuild)) {
    throw "flutter build web nao produziu $flutterBuild"
}

# --- 2. copia para wwwroot/ ---------------------------------------------------
Write-Host '==> 2/4  copiando build para wwwroot/' -ForegroundColor Cyan
if (Test-Path $wwwrootDir) {
    Remove-Item $wwwrootDir -Recurse -Force
}
New-Item -ItemType Directory -Path $wwwrootDir -Force | Out-Null
Copy-Item -Path (Join-Path $flutterBuild '*') -Destination $wwwrootDir -Recurse -Force

# --- 3. dotnet publish --------------------------------------------------------
Write-Host '==> 3/4  dotnet publish -c Release' -ForegroundColor Cyan
Push-Location $backendDir
try {
    dotnet publish -c Release -o .\publish
    if ($LASTEXITCODE -ne 0) { throw "dotnet publish falhou (exit $LASTEXITCODE)" }
} finally {
    Pop-Location
}

# --- 4. reinicia o servico Windows -------------------------------------------
if ($SkipServiceRestart) {
    Write-Host '==> 4/4  reinicio do servico pulado (-SkipServiceRestart)' -ForegroundColor Yellow
} else {
    Write-Host "==> 4/4  reiniciando servico '$ServiceName'" -ForegroundColor Cyan
    $state = & sc.exe query $ServiceName 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "    Servico '$ServiceName' nao esta instalado. Pulando restart." -ForegroundColor Yellow
        Write-Host "    Para criar: .\scripts\install-service.ps1" -ForegroundColor Yellow
    } else {
        & sc.exe stop  $ServiceName | Out-Null
        Start-Sleep -Seconds 2
        & sc.exe start $ServiceName | Out-Null
        & sc.exe query $ServiceName
    }
}

Write-Host ''
Write-Host 'OK. Frontend publicado em http://<IP-DA-LOJA>:5000/' -ForegroundColor Green
