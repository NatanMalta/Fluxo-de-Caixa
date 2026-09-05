# Dockerfile do Fluxo de Caixa — multi-stage único (ADR 0010).
#
# Stage 1: builda o Flutter web (assets/config.json já deve existir
#          no checkout — ver scripts/deploy-docker.ps1).
# Stage 2: copia o output do Flutter pro wwwroot/ e roda dotnet publish.
# Stage 3: runtime enxuto com o aspnet:10.0 (Debian/Ubuntu, não Alpine —
#          e_sqlite3 nativa em musl tem edge cases históricos).
#
# Arquitetura: amd64 (Docker Desktop/WSL2 no Windows host).
# Para ARM: docker buildx build --platform linux/arm64.

# ---------------------------------------------------------------------------
# Stage 1 — Flutter web build
# ---------------------------------------------------------------------------
FROM ghcr.io/cirruslabs/flutter:stable AS flutter-build

WORKDIR /app/frontend

# Copia só o necessário. O .dockerignore exclui build/, .dart_tool/, etc.
COPY frontend/ ./

RUN flutter pub get
RUN flutter build web --release

# ---------------------------------------------------------------------------
# Stage 2 — .NET SDK: copia o Flutter pro wwwroot/ e publica
# ---------------------------------------------------------------------------
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS dotnet-publish

WORKDIR /repo

# Preserva a estrutura de diretórios do repo para que o caminho
# ../../db/schema.sql referenciado pelo csproj resolva corretamente.
COPY backend/FluxoCaixa.Api/ ./backend/FluxoCaixa.Api/
COPY db/ ./db/

# Materializa o Flutter web build no wwwroot/ que o Kestrel vai servir.
# (No arranjo Windows Service isso era feito por scripts/deploy-frontend.ps1.)
COPY --from=flutter-build /app/frontend/build/web ./backend/FluxoCaixa.Api/wwwroot/

WORKDIR /repo/backend/FluxoCaixa.Api
RUN dotnet restore
RUN dotnet publish -c Release -o /app/publish

# ---------------------------------------------------------------------------
# Stage 3 — Runtime
# ---------------------------------------------------------------------------
FROM mcr.microsoft.com/dotnet/aspnet:10.0

WORKDIR /app

# Copia só o publish (sem SDK, sem intermediários de build).
COPY --from=dotnet-publish /app/publish ./

# Usuário não-root: presente por default nas imagens aspnet da Microsoft.
# Não há binário que precise root, não há bind de portas <1024.
USER app

EXPOSE 5000

ENTRYPOINT ["dotnet", "FluxoCaixa.Api.dll"]