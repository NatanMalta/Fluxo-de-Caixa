#!/usr/bin/env pwsh
# Cria (ou remove) o servico Windows do FluxoCaixa.Api. O binario
# precisa estar publicado em backend\FluxoCaixa.Api\publish\FluxoCaixa.Api.exe
# — rode scripts\deploy-frontend.ps1 antes.
#
# Uso (executar como Administrador):
#   .\scripts\install-service.ps1                    # cria o servico
#   .\scripts\install-service.ps1 -ServiceName Outro  # com nome custom
#   .\scripts\install-service.ps1 -Remove             # remove
#
# O que ele faz na criacao:
#   1. sc.exe create  -> servico auto-start no boot
#   2. sc.exe failure -> restart em 5s, ate 3 tentativas, reset apos 60s
#   3. sc.exe start   -> sobe o servico imediatamente

[CmdletBinding()]
param(
    [string]$ServiceName = 'FluxoCaixa',
    [string]$DisplayName = 'Fluxo de Caixa - API + Frontend',
    [switch]$Remove
)

$ErrorActionPreference = 'Stop'

$repoRoot   = Resolve-Path (Join-Path $PSScriptRoot '..')
$publishDir = Join-Path $repoRoot 'backend\FluxoCaixa.Api\publish'
$exe        = Join-Path $publishDir 'FluxoCaixa.Api.exe'

# --- Remove -------------------------------------------------------------------
if ($Remove) {
    Write-Host "Removendo servico '$ServiceName'..." -ForegroundColor Yellow
    & sc.exe stop   $ServiceName 2>$null | Out-Null
    Start-Sleep -Seconds 2
    & sc.exe delete $ServiceName
    if ($LASTEXITCODE -ne 0) { throw "sc.exe delete falhou (exit $LASTEXITCODE)" }
    Write-Host 'OK.' -ForegroundColor Green
    exit 0
}

# --- Sanidades pre-create -----------------------------------------------------
# 1. Binario existe
if (-not (Test-Path $exe)) {
    throw "Binario nao encontrado: $exe`nRode scripts\deploy-frontend.ps1 primeiro."
}

# 2. Privilegio de administrador (sc.exe create exige)
$principal = New-Object Security.Principal.WindowsPrincipal(
    [Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw "Precisa rodar como Administrador. Clique direito no PowerShell -> Executar como administrador."
}

# 3. Nao sobrescreve servico existente
$existing = & sc.exe query $ServiceName 2>&1
if ($LASTEXITCODE -eq 0) {
    throw "Servico '$ServiceName' ja existe. Para recriar:`n  .\scripts\install-service.ps1 -Remove`n  .\scripts\install-service.ps1"
}

# --- Create -------------------------------------------------------------------
Write-Host "Criando servico '$ServiceName'..." -ForegroundColor Cyan
& sc.exe create $ServiceName `
    binPath=     "`"$exe`"" `
    DisplayName= $DisplayName `
    start=       auto
if ($LASTEXITCODE -ne 0) { throw "sc.exe create falhou (exit $LASTEXITCODE)" }

# --- Recovery -----------------------------------------------------------------
Write-Host 'Configurando recovery (restart x3 em 5s, reset em 60s)...' -ForegroundColor Cyan
& sc.exe failure $ServiceName reset= 60 actions= restart/5000/restart/5000/restart/5000
if ($LASTEXITCODE -ne 0) { throw "sc.exe failure falhou (exit $LASTEXITCODE)" }

# --- Start --------------------------------------------------------------------
Write-Host 'Iniciando servico...' -ForegroundColor Cyan
& sc.exe start $ServiceName
if ($LASTEXITCODE -ne 0) { throw "sc.exe start falhou (exit $LASTEXITCODE)" }
Start-Sleep -Seconds 2
& sc.exe query $ServiceName

Write-Host ''
Write-Host 'OK.' -ForegroundColor Green
Write-Host "Acesse http://<IP-DA-LOJA>:5000/ de qualquer dispositivo na LAN."
Write-Host "Para desinstalar depois:  .\scripts\install-service.ps1 -Remove"
Write-Host ""
Write-Host "Para acompanhar os logs em tempo real:"
Write-Host "  PowerShell:  Get-Content '$publishDir\logs\fluxo-caixa.log' -Wait"
Write-Host "  Git Bash:    tail -F '$($publishDir -replace '\\','/' )/logs/fluxo-caixa.log'"
