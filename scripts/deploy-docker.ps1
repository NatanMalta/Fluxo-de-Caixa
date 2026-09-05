#!/usr/bin/env pwsh
# Deploy do Fluxo de Caixa via Docker (ADR 0010).
#
# O que este script faz:
#   1. Detecta o IP atual da LAN do host
#   2. Gera frontend/assets/config.json com apiBaseUrl = http://<IP>:5000
#   3. Garante que C:\FluxoCaixa\ existe com appsettings.json (PIN + JWT secret)
#   4. Copia Dockerfile + docker-compose.yml do repo pra C:\FluxoCaixa\
#   5. Cria docker-compose.override.yml apontando build.context pro repo
#   6. Roda `docker compose up -d --build` a partir de C:\FluxoCaixa\
#
# Uso (executar de dentro do clone do repo):
#   .\scripts\deploy-docker.ps1
#
# Pré-requisitos:
#   - Docker Desktop instalado e rodando
#   - C:\FluxoCaixa\appsettings.json já existe (com PIN, JWT secret,
#     e ConnectionStrings:DefaultConnection apontando pra /data/fluxo_caixa.db).
#     Na primeira instalação, copie do PC da loja ou de um backup.

[CmdletBinding()]
param(
    [string]$DeployDir = 'C:\FluxoCaixa'
)

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')

# --- 1. Detectar IP da LAN ----------------------------------------------------
Write-Host '==> 1/6  Detectando IP da LAN...' -ForegroundColor Cyan

$lAN_IPs = Get-NetIPAddress -AddressFamily IPv4 |
    Where-Object {
        $_.IPAddress -notlike '127.*' -and
        $_.IPAddress -notlike '169.254.*' -and
        $_.IPAddress -notlike '172.*' -and
        $_.IPAddress -notlike '10.*'  # descarta Tailscale 100.x e Docker 172.x; mantém 192.168.x
    } |
    Select-Object -ExpandProperty IPAddress -Unique

# Prefere 192.168.x.x (LAN típica de mercadinho)
$lanIP = ($lAN_IPs | Where-Object { $_ -like '192.168.*' } | Select-Object -First 1)
if (-not $lanIP) {
    # Fallback: qualquer IP que não seja das faixas filtradas acima
    $lanIP = $lAN_IPs | Select-Object -First 1
}
if (-not $lanIP) {
    throw "Não foi possível detectar o IP da LAN. Verifique a conexão de rede e rode novamente."
}
Write-Host "    IP detectado: $lanIP"

# --- 2. Gerar frontend/assets/config.json ------------------------------------
Write-Host '==> 2/6  Gerando frontend/assets/config.json...' -ForegroundColor Cyan

$configExample = Join-Path $repoRoot 'frontend\assets\config.example.json'
$configJson     = Join-Path $repoRoot 'frontend\assets\config.json'

if (-not (Test-Path $configExample)) {
    throw "config.example.json não encontrado: $configExample"
}

$config = Get-Content $configExample -Raw | ConvertFrom-Json
$config.apiBaseUrl = "http://${lanIP}:5000"
$config | ConvertTo-Json -Depth 10 | Set-Content -Path $configJson -Encoding UTF8
Write-Host "    apiBaseUrl = http://${lanIP}:5000"

# --- 3. Garantir que C:\FluxoCaixa\ existe com appsettings.json -------------
Write-Host "==> 3/6  Verificando $DeployDir..." -ForegroundColor Cyan

if (-not (Test-Path $DeployDir)) {
    New-Item -ItemType Directory -Path $DeployDir -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $DeployDir 'data') -Force | Out-Null
    Write-Host "    Criado $DeployDir e $DeployDir\data\"
}

$deployAppsettings = Join-Path $DeployDir 'appsettings.json'
if (-not (Test-Path $deployAppsettings)) {
    # Tenta copiar da appsettings.json do backend (dev) — tem PIN/JWT secret
    $backendAppsettings = Join-Path $repoRoot 'backend\FluxoCaixa.Api\appsettings.json'
    if (Test-Path $backendAppsettings) {
        # Precisa ajustar a connection string pra apontar pra /data/fluxo_caixa.db
        $appsettings = Get-Content $backendAppsettings -Raw | ConvertFrom-Json
        $appsettings.ConnectionStrings.DefaultConnection = 'Data Source=/data/fluxo_caixa.db'
        $appsettings | ConvertTo-Json -Depth 10 | Set-Content -Path $deployAppsettings -Encoding UTF8
        Write-Host "    Copiado appsettings.json do backend (connection string ajustada pra /data/fluxo_caixa.db)"
    } else {
        throw @"
appsettings.json não encontrado em $deployAppsettings.

Na primeira instalação, copie o appsettings.json do PC da loja ou de um backup
para $DeployDir\appsettings.json. Ele precisa conter:
  - Auth:Pin (PIN numérico em texto puro)
  - Jwt:Secret (pelo menos 32 caracteres)
  - ConnectionStrings:DefaultConnection = 'Data Source=/data/fluxo_caixa.db'

Gere um JWT secret com:  openssl rand -base64 48
"@
    }
} else {
    Write-Host "    appsettings.json já existe em $DeployDir"
}

# --- 4. Copiar Dockerfile + docker-compose.yml do repo ----------------------
Write-Host '==> 4/6  Copiando Dockerfile e docker-compose.yml...' -ForegroundColor Cyan

Copy-Item -Path (Join-Path $repoRoot 'Dockerfile') -Destination $DeployDir -Force
Copy-Item -Path (Join-Path $repoRoot 'docker-compose.yml') -Destination $DeployDir -Force
Write-Host "    Copiado para $DeployDir"

# --- 5. Criar docker-compose.override.yml apontando context pro repo ---------
Write-Host '==> 5/6  Criando docker-compose.override.yml...' -ForegroundColor Cyan

# O docker-compose.yml versionado tem `context: .` (relativo a si mesmo,
# i.e., C:\FluxoCaixa\). Mas o código do repo vive no clone, não em
# C:\FluxoCaixa\. O override redireciona o build context para o repo.
# Este arquivo é local da loja (não versionado).
$overridePath = Join-Path $DeployDir 'docker-compose.override.yml'
$overrideContent = @"
# Gerado automaticamente por scripts/deploy-docker.ps1 — não versionar.
# Redireciona o build context do docker-compose.yml para o clone do repo.
services:
  api:
    build:
      context: $($repoRoot.Path -replace '\\','\\')
"@
Set-Content -Path $overridePath -Value $overrideContent -Encoding UTF8
Write-Host "    override context = $($repoRoot.Path)"

# --- 6. docker compose up -d --build ----------------------------------------
Write-Host '==> 6/6  docker compose up -d --build' -ForegroundColor Cyan

Push-Location $DeployDir
try {
    docker compose up -d --build
    if ($LASTEXITCODE -ne 0) { throw "docker compose up falhou (exit $LASTEXITCODE)" }
} finally {
    Pop-Location
}

Write-Host ''
Write-Host 'OK.' -ForegroundColor Green
Write-Host "Fluxo de Caixa rodando em http://${lanIP}:5000/" -ForegroundColor Green
Write-Host ''
Write-Host 'Logs:        docker logs fluxo-caixa -f'
Write-Host 'Parar:       docker compose down  (em $DeployDir)"
Write-Host 'Reiniciar:   .\scripts\deploy-docker.ps1'
Write-Host ''
Write-Host 'Backup: copiar a pasta C:\FluxoCaixa\data\ para um HD externo/pendrive.'
Write-Host '         (copiar a pasta inteira, não só o .db — ver ADR 0002 sobre WAL mode)'