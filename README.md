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

## Backup

O banco é um único arquivo SQLite (`fluxo_caixa.db` na pasta do backend). Para fazer backup, basta copiar esse arquivo para um lugar seguro (HD externo, pen drive, etc.). Recomenda-se copiar pelo menos uma vez por semana.

## Próximos passos (v2)

- Integração de leitura com o PDV legado (`tb_boletos`, `tb_pendencia`) — só quando o usuário quiser
- Notificações/alertas (boleto vence amanhã, esqueceu de lançar o dia, etc.)
- Comparativo de meses no Balanço
- Exportação de relatórios (CSV, PDF)
