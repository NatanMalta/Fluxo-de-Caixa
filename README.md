# Fluxo de Caixa do Mercadinho

Aplicativo web/mobile em Flutter + backend ASP.NET (C#) para registro manual do fluxo de caixa de um mercadinho. Roda em servidor local na loja, acessado pelo dono via Wi-Fi. Sem dependência de internet, sem cloud.

> Veja `CONTEXT.md` para o glossário do domínio e `docs/adr/` para as decisões arquiteturais.

## Estrutura

```
.
├── CONTEXT.md                 # Glossário do domínio
├── docs/adr/                  # Decisões arquiteturais (ADR)
├── db/schema.sql              # Schema SQLite (fonte canônica)
├── backend/                   # API ASP.NET 10 + EF Core + SQLite
│   └── FluxoCaixa.Api/
└── frontend/                  # App Flutter (web + Android)
    └── lib/
```

## Pré-requisitos

- **.NET SDK 10.0+** (inclui EF Core CLI)
- **Flutter 3.x stable** com suporte a web e Android
- **Android SDK** (para build/run no Android)
- **Docker Desktop** (para deployment na loja — ver seção Deploy abaixo)
- **Visual Studio Code** ou outra IDE (recomendado)

## Como rodar

### 1. Backend

```bash
cd backend/FluxoCaixa.Api
dotnet restore
dotnet run
```

O servidor sobe em `http://0.0.0.0:5000` (acessível pelo IP da máquina na rede local).
Na primeira execução, o `db/schema.sql` é aplicado automaticamente e o arquivo `fluxo_caixa.db` é criado.

A especificação OpenAPI fica disponível em `http://localhost:5000/openapi/v1.json` (apenas em modo Development).

### 2. Frontend (Web)

```bash
cd frontend
flutter pub get
flutter run -d chrome
```

O app abre no navegador apontando para `http://localhost:5000`.

### 3. Frontend (Android via Wi-Fi)

```bash
cd frontend
flutter pub get
flutter run -d android
```

Para o app encontrar o backend no Android, edite `lib/services/api_client.dart` e troque:

```dart
static String baseUrl = 'http://localhost:5000';
```

por

```dart
static String baseUrl = 'http://<IP-DO-PC>:5000';
```

(substitua `<IP-DO-PC>` pelo IP local do PC, ex.: `192.168.0.10`).
Para descobrir o IP no Windows: `ipconfig` no cmd.

Para emulador Android, use `http://10.0.2.2:5000` (IP especial que aponta pro host).

## Endpoints da API

| Verbo | Rota                                  | Descrição                                      |
|-------|---------------------------------------|------------------------------------------------|
| GET   | `/api/Contas`                         | Lista contas                                   |
| POST  | `/api/Contas`                         | Cria conta                                     |
| GET   | `/api/Contas/{id}`                    | Obtém conta (com saldoAtual)                   |
| PUT   | `/api/Contas/{id}`                    | Atualiza conta                                 |
| DELETE| `/api/Contas/{id}`                    | Desativa conta (soft delete)                   |
| GET   | `/api/Categorias?tipo=entrada\|saida` | Lista categorias                               |
| POST  | `/api/Categorias`                     | Cria categoria                                 |
| PUT   | `/api/Categorias/{id}`                | Atualiza categoria                             |
| DELETE| `/api/Categorias/{id}`                | Desativa categoria                             |
| GET   | `/api/Lancamentos?inicio&fim&tipo&contaId` | Lista lançamentos                       |
| POST  | `/api/Lancamentos`                    | Cria lançamento (comum/ajuste/transferência)   |
| PUT   | `/api/Lancamentos/{id}`               | Atualiza lançamento                            |
| DELETE| `/api/Lancamentos/{id}`               | Exclui lançamento                              |
| GET   | `/api/Balanco?inicio&fim`             | Resumo do período (Entradas, Saídas, Resultado, saldos e breakdown) |

## Deploy (Docker)

O deployment oficial é via Docker (ADR 0010). O backend (Kestrel servindo API + Flutter web num único processo) roda num container Linux gerido por Docker Desktop no PC da loja.

### Pré-requisitos na loja

- **Docker Desktop** instalado e com autostart ligado ("Start Docker Desktop when you sign in")
- **Login automático** de uma conta de usuário no boot (o daemon do Docker Desktop depende de sessão ativa no Windows)
- **Reserva DHCP** no roteador garantindo que o IP do PC da loja não mude (o `apiBaseUrl` do Flutter é baked no JS em build time — se o IP mudar, é preciso re-rodar o deploy)
- **Regra de firewall inbound** permitindo `TCP/5000` no Windows host

### Deploy

A partir do clone do repo, num PowerShell:

```powershell
.\scripts\deploy-docker.ps1
```

O script:
1. Detecta o IP atual da LAN
2. Gera `frontend/assets/config.json` com `apiBaseUrl = http://<IP>:5000`
3. Garante que `C:\FluxoCaixa\` existe com `appsettings.json` (PIN + JWT secret + connection string apontando pra `/data/fluxo_caixa.db`)
4. Copia `Dockerfile` + `docker-compose.yml` do repo pra `C:\FluxoCaixa\`
5. Cria `docker-compose.override.yml` redirecionando o build context pro repo
6. Roda `docker compose up -d --build`

### Estrutura de `C:\FluxoCaixa\`

```
C:\FluxoCaixa\
├── docker-compose.yml          (copiado do repo)
├── docker-compose.override.yml (gerado pelo script — aponta pro repo)
├── appsettings.json            (gitignored, com PIN + JWT secret)
└── data\
    ├── fluxo_caixa.db
    ├── fluxo_caixa.db-wal
    └── fluxo_caixa.db-shm
```

### Logs

```bash
docker logs fluxo-caixa -f
```

### Parar / reiniciar

```bash
# Parar (remove o container — não volta no próximo reboot)
docker compose down

# Reiniciar após parar
.\scripts\deploy-docker.ps1
```

## Deploy (Windows Service — fallback)

Se o Docker Desktop não subir no host da loja (bugs de WSL2/vpnkit em updates do Windows), o arranjo Windows Service permanece como fallback de emergência:

```powershell
.\scripts\deploy-frontend.ps1    # builda Flutter + .NET
.\scripts\install-service.ps1    # cria e inicia o serviço (como Administrador)
```

Os scripts não são mantidos ativamente (não espelham mudanças de build), mas o caminho Windows Service funciona enquanto `builder.Host.UseWindowsService()` estiver no `Program.cs`.

## Backup

O banco é SQLite em modo WAL — além de `fluxo_caixa.db`, existem `fluxo_caixa.db-wal` e `fluxo_caixa.db-shm` ao lado dele. Copiar só o `.db` produz um backup inconsistente (Lançamentos recentes ainda no WAL ficam de fora).

**No arranjo Docker:** copiar a pasta `C:\FluxoCaixa\data\` inteira para um lugar seguro (HD externo, pen drive). Recomenda-se pelo menos uma vez por semana.

**No arranjo Windows Service:** copiar a pasta onde o banco vive (o caminho absoluto do `appsettings.json`).

## Próximos passos (v2)

- Integração de leitura com o PDV legado (`tb_boletos`, `tb_pendencia`) — só quando o usuário quiser
- Notificações/alertas (boleto vence amanhã, esqueceu de lançar o dia, etc.)
- Comparativo de meses no Balanço
- Exportação de relatórios (CSV, PDF)
