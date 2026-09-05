# Docker como mecanismo de deployment

O backend (Kestrel servindo API + Flutter web embutido num único processo) passa a rodar num container Linux gerido por Docker Desktop no PC da loja, substituindo o Windows Service criado por `scripts\install-service.ps1`. A motivação é eliminar a dependência do estado do host (SDK .NET/Flutter instalados, versões certas) e tornar dev e prod idênticos — `docker compose up -d --build` quando muda código, e o ambiente dentro do container é o mesmo em qualquer máquina. O arranjo Windows Service permanece no repo como script de recuperação (não apagado, não coexistente — ver "Scripts antigos" adiante).

## Decisões que questa ADR engloba

A migração pra Docker envolveu várias decisões dependentes; estão consolidadas aqui pra evitar fragmentar a narrativa em múltiplos ADRs pequenos. Cada uma era um trade-off real com alternativas consideradas e rejeitadas.

### Topologia: um container só

Um único container (`api`) com o Kestrel servindo `/api/*` e o Flutter web (em `wwwroot/`), como hoje. Rejeitada a separação frontend (nginx/Caddy) + backend em dois containers — a separação exigiria re-implementar as regras dos ADRs 0008 (SPA fallback `.AllowAnonymous`) e 0009 (alias `/assets/*` → `assets/assets/`) como config de nginx, sem ganho funcional para um único usuário numa única loja num único PC. O argumento "separar pra poder migrar do SQLite pro Postgres depois" não se sustenta: a migração de banco adicionaria um **segundo** container (o de banco), independente de como o frontend é servido — separar o frontend hoje seria trabalho retrabalhado amanhã.

A migração SQLite → Postgres queda como decisão futura em aberto, sem的东西 que dirija a arquitetura atual (não há prazo nem gatilho concreto); quando se tornar concreta, vira ADR própria e um serviço `db` entra no compose sem retrabalhar a topologia.

### Dockerfile: multi-stage único

Um `Dockerfile` multi-stage: (1) stage Flutter builda `flutter build web --release`, (2) stage .NET SDK copia o output do Flutter pro `wwwroot/` e roda `dotnet publish`, (3) stage runtime copia só o `publish/`. Rejeitada a alternativa "build externo do Flutter no host + Dockerfile enxuto" porque ela reintroduz a dependência de versão de Flutter no host — justamente o que motivou a migração. Imagem de base do stage final é `mcr.microsoft.com/dotnet/aspnet:10.0` (Debian/Ubuntu), não Alpine: SQLite via `Microsoft.Data.Sqlite` une `e_sqlite3` nativa, e a combinação musl/Alpine já teve edge cases históricos de carregamento da lib nativa; 100 MB de economia de imagem não paga o risco de debuggar isso num PC de mercadinho. Stage do Flutter usa `ghcr.io/cirruslabs/flutter:3.x.x` (Ubuntu base); é descartado no final, então o tamanho desse stage não afeta a imagem publicada.

Arquitetura **amd64** (PC Windows host via Docker Desktop/WSL2). ARM só entraria numa eventual migração de hardware (mini-PC ARM/Pi), e nesse dia é `docker buildx build --platform linux/arm64`.

### Container não-root

O container roda como o usuário `app` (presente por default nas imagens `aspnet` da Microsoft). Não há binário que precise root, não há bind de portas <1024.

### Persistência: bind mount `./data` → `/data`

O SQLite vive num bind mount `./data:/data` no host (visível no Explorer, copiável pro HD externo), não em volume nomeado. Rejeitado volume nomeado porque o ADR 0002 ritualiza o backup como "copiar o arquivo SQLite pro HD externo"; um volume nomeado forçaria o operador a aprender `docker run --rm -v fluxo-caixa-data:/data alpine cp ...` — comando hostil pra um dono de mercadinho. Com bind mount, o ritual não muda: arrasta `data\` pro pendrive. O `ConnectionStrings:DefaultConnection` em `appsettings.json` aponta pra `/data/fluxo_caixa.db` (caminho **dentro** do container); o fallback `Data Source=fluxo_caixa.db` do `Program.cs` não é alcançado em produção porque a connection string está sempre explicita na config montada.

### Secrets: `appsettings.json` montado, não baked na imagem

A imagem não tem `COPY appsettings.json` — esse arquivo contém PIN em texto puro e JWT secret (ADR 0007). É montado via bind mount `./appsettings.json:/app/appsettings.json:ro` no `docker-compose.yml`. Rejeitadas as alternativas: (a) variáveis de ambiente em `.env` via `environment:` no compose — separaria config de secret mas espalharia chaves e exigiria que o operador entendesse `.env`; (b) `appsettings.Production.json` versionado (só config) + `appsettings.json` montado (só secret) — adicionaria um arquivo novo sem benefício real. A escolha (bind mount do `appsettings.json` inteiro) preserva a mecânica mental que já existe (um arquivo único com secrets, mantido fora do git) e garante que o secret **nunca entra na imagem Docker** — que é o único requisito de segurança realmente novo que o Docker introduz.

### Boot: `restart: always` + Docker Desktop autostart + login automático

`restart: always` no compose faz o daemon recriar o container se ele morrer. **Mas `restart: always` só vale alguma coisa se o daemon estiver rodando**, e no Windows host isso significa Docker Desktop precisa estar ativo. O autostart "Start Docker Desktop when you sign in" deve estar ligado, e o PC da loja precisa fazer login automático de uma conta de usuário (já configurado). Sem login autônomo, o daemon não sobe no boot e o `restart: always` é inútil. Em host Linux seria `systemd` cuidando do `dockerd` (não dependente de login), mas o host é Windows. `unless-stopped` foi rejeitado porque em `docker compose stop` (pra backup manual) o container **não** voltaria no próximo reboot — propriedade indesejada pra um serviço que deve voltar sempre. `always` garante volta no boot independente de estado anterior; pra realmente parar, é `docker compose down` (que remove o container e deixa de aplicar a policy).

### Logs: stdout/stderr como canal canônico em container

O `FileLoggerProvider` custom (`Program.cs`) só é instanciado quando `OperatingSystem.IsWindows()` é verdadeiro. Em container Linux, só o Console provider fica ativo, e `docker logs fluxo-caixa -f` é o equivalente direto de `tail -F logs/fluxo-caixa.log`. Rejeitado manter o FileLogger no container (com bind mount `./logs:/app/logs`) porque (a) adicionaria um bind mount sem benefício — `docker logs` já cobre, (b) o arquivo cresceria indefinidamente sem rotação (problema que já existe no arranjo Windows Service e não vale a pena reproduzir), (c) quebra o padrão Docker canônico de logs em stdout. A condicional é `IsWindows()`, não "IsWindowsService" — porque num host Windows rodando `dotnet run` em dev o FileLogger continua útil, e `UseWindowsService()` é no-op em Linux mas relevante em Windows.


### Rede: port mapping, não `network_mode: host`

`ports: "5000:5000"` no compose faz o Docker bind de `0.0.0.0:5000` no host e encaminha pro `5000` do container. `network_mode: host` foi rejeitado porque **não funciona de forma confiável em Docker Desktop Windows** (o "host" do `network_mode` é o WSL2, não o Windows host; a configuração confunde o proxy vpnkit do Docker Desktop). `Program.cs` não muda por causa de rede — `UseUrls("http://0.0.0.0:5000")` já está correto dentro do container; o `ports:` expõe pro host. O bloco que enumera interfaces IPv4 e loga `http://<IP>:5000/` em startup (linhas 168–190 do `Program.cs`) é suprimido em container Linux (`if (OperatingSystem.IsWindows())`) — o container enxergaria só a interface virtual do Docker (`eth0`, IP `172.x`), informações inúteis pro dono; o IP real da LAN é o do host do Docker.

Pode ser necessária regra de firewall inbound permitindo `TCP/5000` no Windows host (responsabilidade do operador, documentada no `README.md`, não no ADR). Meta paralela: **reserva DHCP no roteador** garantindo que o IP do PC da loja não mude — se mudar, o Flutter não conecta (`apiBaseUrl` é baked no bundle em build time, ver abaixo) e o ritual é re-rodar `scripts\deploy-docker.ps1`.

### `apiBaseUrl` do Flutter: pré-populado no host antes do build

O `frontend/assets/config.json` (gitignored) traz `apiBaseUrl` com o IP da LAN da loja; o Flutter o bundleia em `flutter build web` (baked no JS, não configurável em runtime sem rebuild — ver AGENTS.md). Em Docker, o stage de build do Flutter roda numa sandbox sem acesso ao filesystem do host, então `config.json` precisa existir fisicamente no checkout local **antes** de `docker compose build`. O `scripts\deploy-docker.ps1` assume essa responsabilidade: detecta o IP atual do host (`Get-NetIPAddress`), lê `frontend/assets/config.example.json` como template, sobrescreve `apiBaseUrl` com `http://<IP>:5000`, e escreve `frontend/assets/config.json`. Rejeitada a alternativa de `--build-arg API_BASE_URL=...` no compose porque ela duplicaria o mecanismo existente (introduziria um canal de config novo sem matar o velho) em vez de reaproveitar o ritual e o `config.json` que já é o ponto único de verdade pra `apiBaseUrl`. Migrar `apiBaseUrl` pra runtime-injetável é uma decisão arquitetural ortogonal (quebraria o AGENTS.md atual) e está fora do escopo desta migração.

### Scripts antigos: arquivados, não apagados

`scripts\install-service.ps1` e `scripts\deploy-frontend.ps1` permanecem no repo como runbook de recuperação pra se Docker Desktop quebrar no host da loja (histórico de bugs WSL2/vpnkit em updates do Windows). O `README.md` operacional documenta Docker como caminho oficial e Windows Service como "use se Docker não subir". Os scripts não são mantidos ativamente (não espelham mudanças de build), mas não são apagados — apagar retiraria o fallback de emergência instantaneamente. Se uma mudança de código futura quebrar a compatibilidade com Windows Service (ex.: remover `builder.Host.UseWindowsService()`), aí se decide entre apagar o caminho Windows Service de vez ou manter compat.

### Layout: deploy folder `C:\FluxoCaixa\` isolado do repo

O `docker-compose.yml` executado na loja vive em `C:\FluxoCaixa\`, não no clone do repo, com a estrutura:

```
C:\FluxoCaixa\
├── docker-compose.yml      (copiado do repo)
├── Dockerfile              (copiado do repo)
├── appsettings.json        (gitignored, com PIN + JWT secret + ConnectionStrings:DefaultConnection=/data/fluxo_caixa.db)
└── data\
    ├── fluxo_caixa.db
    ├── fluxo_caixa.db-wal
    └── fluxo_caixa.db-shm
```

Rejeitado "repo é deploy folder" porque mistura código em desenvolvimento com arquivos vitais runtime; um `git clean -fd` acidental ou branch experimental poderia bagunçar o `docker-compose.yml` enquanto a loja está rodando. `scripts\deploy-docker.ps1` (no repo) é invocado de dentro do clone e faz: copia `Dockerfile` + `docker-compose.yml` pra `C:\FluxoCaixa\`, garante `appsettings.json` existe (falha com mensagem clara se não), gera `frontend/assets/config.json` com IP atual, roda `docker compose up -d --build` a partir de `C:\FluxoCaixa\` (que referencia o repo como context do build).

## Considered Options

- **Manter Windows Service (status quo):** rejeitado porque não resolve a motivação (reprodutibilidade + dev/prod idênticos). Continuaria dependendo do estado do host.
- **Linux host sem Docker (systemd unit):** rejeitado porque host atual é Windows; migrar de SO seria uma bifurcação maior que a própria containerização. Docker permite manter o Windows host com as vantagens de isolamento de ambiente.
- **Topologia dois containers (frontend nginx + backend API):** rejeitada (ver acima).
- **Volume nomeado em vez de bind mount:** rejeitado (ver acima; ADR 0002 ritual de backup).
- **Env vars / `appsettings.Production.json` separado em vez de bind mount do `appsettings.json`:** rejeitado (ver acima; preserva mecânica mental e não espalha chaves).
- **Alpine runtime em vez de Debian:** rejeitado (ver acima; risco SQLite em musl).
- **Scheduled task detectando mudança de IP e re-buildando automaticamente:** rejeitado — over-engineering; reserva DHCP no roteador resolve na raiz.

## Consequences

- **Novo arquivo de infra versionado:** `Dockerfile`, `docker-compose.yml` (template), `.dockerignore` entram no repo.
- **Novo script de operação:** `scripts\deploy-docker.ps1`.
- **Duas pequenas mudanças no `Program.cs`:** `if (OperatingSystem.IsWindows())` em volta de `FileLoggerProvider` e do bloco de enumeração de interfaces de rede. Zero mudança de comportamento no arranjo Windows Service.
- **Docker Desktop vira dependência do host da loja:** ~1–2 GB de memória para a VM WSL2, mesmo com container parado. Aceitável para hardware commodity de mercadinho (PC desktop com 8+ GB).
- **Backup ritual muda de "copiar arquivo" pra "copiar pasta":** ver atualização do ADR 0002 sobre WAL mode.
- **Firewall inbound:** pode ser necessária regra `TCP/5000` no Windows host (igual no arranjo Windows Service, mas vale documentar).
- **ADR 0007 não muda:** PIN continua em `appsettings.json`, backend continua hasheando com BCrypt no startup, rate limit de 5/min/IP continua. Apenas o **transporte** do secret muda (não `COPY` na imagem, sim bind mount no runtime).
- **Migração SQLite → Postgres permanece fora do escopo.** Quando se tornar concreta (surgir concorrência de escrita ou outro motivo real), vira ADR própria, adiciona serviço `db` ao compose, e a topologia "um container" revisada na mesma decisão.