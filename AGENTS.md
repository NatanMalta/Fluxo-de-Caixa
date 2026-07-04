# Fluxo de Caixa — Agent Guide

## Project Overview

- **Type**: Two-tier local app — Flutter (web + Android) frontend + ASP.NET 10 Web API backend
- **Persistence**: SQLite (single file: `backend/FluxoCaixa.Api/fluxo_caixa.db`)
- **Deployment**: Local server (PC) inside the store, accessed via Wi-Fi. No cloud, no internet.
- **Users**: Single user (the store owner). No roles. Auth via single PIN — see ADR 0007.

## Key Directories

| Path | Purpose |
|------|---------|
| `CONTEXT.md` | Domain glossary (Conta, Lançamento, Categoria, etc.) — read before designing new features |
| `docs/adr/` | Architecture Decision Records — read before making changes that touch the listed decisions |
| `db/schema.sql` | Canonical SQLite schema (canonical source of truth) — edit here, then trigger re-init by deleting `fluxo_caixa.db` |
| `backend/` | ASP.NET 10 Web API with EF Core 10 + SQLite |
| `frontend/` | Flutter app (Material 3, web + Android) |

## Domain Rules (enforce these)

- **Three types of Lançamento** in one table (discriminator `tipo`):
  - `comum` — entrada/saída normal, has `conta_id`, `categoria_id`, `sentido`
  - `ajuste` — correction to a Conta, has `conta_id`, `sentido`, `descricao`. Does NOT have Categoria.
  - `transferencia` — between two Contas, has `conta_origem_id`, `conta_destino_id`. Does NOT count toward business Entradas/Saídas totals.
- **Saldo** of a Conta is `saldo_inicial + Σ(entradas) − Σ(saídas) ± Σ(ajustes) − Σ(transf_saindo) + Σ(transf_entrando)`. Derived, never stored.
- **Categorias** are user-defined (no defaults). Two `tipo`s: `entrada` and `saida`.
- **Periodicidade**: daily summary (one Lançamento per (date, conta, categoria) for Comum).

## Database Schema

- **Source of truth**: `db/schema.sql`. Edit there.
- **Triggers** enforce that Lançamentos have the right fields for their `tipo` (e.g., a `comum` cannot have `conta_origem_id`).
- The schema is **applied at startup** by `backend/FluxoCaixa.Api/Data/DatabaseInitializer.cs` (idempotent via `IF NOT EXISTS`).
- EF Core entities in `Models/` and `Dtos/` map to this schema — they must stay in sync.

## Backend Conventions

- **.NET 10** (SDK pinned via `<TargetFramework>net10.0</TargetFramework>`)
- **Controllers** for each entity; `BalancoController` for the read-only aggregate view
- **`SaldoCalculator`** service computes the current balance of a Conta (read-only; no caching for v1)
- **`AppDbContext`** manages `criado_em` / `atualizado_em` automatically in `SaveChanges`
- **CORS** is open to any origin (local app, no security boundary)
- **URL** is fixed to `http://0.0.0.0:5000` in `Program.cs` so LAN clients can connect
- **Auth** (see ADR 0007): single-PIN scheme. All controllers require `[Authorize]` (or a global `RequireAuthenticatedUser()` policy). `POST /api/auth/login` accepts the PIN and returns a 30-day JWT signed with a secret from `appsettings.json`. Brute force on `/api/auth/login` is mitigated with a fixed rate limit (5 attempts/min/IP) via `Microsoft.AspNetCore.RateLimiting`.

## Frontend Conventions

- **Flutter stable**, Material 3, `intl` for BRL currency formatting
- **State management**: `setState` for v1 (no Provider/Riverpod yet). Add a state lib if screens start prop-drilling heavily.
- **Cross-tab coordination**:
  - **Propagação de mutações** usa o barramento `DataInvalidator` (`lib/services/data_invalidator.dart`): 4 `ValueNotifier<int>` estáticos que as telas escutam via `ListenableBuilder` envolvendo o `FutureBuilder`. Mutações chamam `value++` no notifier apropriado **depois** do `await` da chamada HTTP. Ver ADR 0006.
  - **Saltar para a aba Lançar com o form pré-preenchido** ainda usa `GlobalKey<LancarScreenState>` no `HomeScreen` chamando `editar(l)`. Esse canal cuida de uma direção diferente da propagação de dados. Ver ADR 0004.
  - Children stay mounted via `IndexedStack`.
- **API base URL**: configured via `frontend/assets/config.json` (key `apiBaseUrl`). `ApiClient.init()` loads it at startup, with `http://localhost:5000` as fallback. The real `config.json` is gitignored; `config.example.json` is the versioned template. Copy it to `config.json` and edit with the server's LAN IP. Common values:
  - Web on the same PC: `http://localhost:5000`
  - Android emulator: `http://10.0.2.2:5000`
  - Web/Android on LAN: `http://<PC_IP>:5000`
- **No tests** in v1. Add `test/` files as the project grows.
- **Auth** (see ADR 0007): PIN lock screen on app open, JWT in memory in `ApiClient`, PIN re-prompted on 401. The JWT is never written to `localStorage`/`SharedPreferences` because Flutter web's `flutter_secure_storage` is encrypted with a JS-only key — the only honest storage is memory + re-prompt on reopen.

## Manual test checklist for `DataInvalidator` bumps (ADR 0006)

O ônus do `DataInvalidator` é "esqueci o bump = tela stale silenciosamente". Para cada mutação abaixo, abra a tela de origem, faça a mutação, depois abra cada tela-alvo e confirme que o dado mudou sem refresh manual:

| # | Mutação (origem) | Confirmar em... |
|---|------------------|-----------------|
| 1 | Criar Conta (Config)        | Início (lista de contas + saldo total), Lançar (dropdown de conta), Balanço (saldosPorConta) |
| 2 | Editar Conta (Config)       | Início, Lançar, Balanço |
| 3 | Inativar Conta (Config)     | Início (some da lista), Lançar (some do dropdown), Balanço (saldosPorConta) |
| 4 | Criar Categoria (Config)    | Lançar (dropdown de categoria), Balanço (quebra por categoria) |
| 5 | Editar Categoria (Config)   | Lançar, Balanço, Início (categoriaNome joinado nos últimos lançamentos) |
| 6 | Inativar Categoria (Config) | Lançar (some do dropdown), Balanço (quebra por categoria), Início |
| 7 | Criar Lançamento (Lançar)   | Lançar (lista "Lançamentos de hoje"), Início (saldo total + últimos), Balanço (totais + saldo de período) |
| 8 | Editar Lançamento (Lançar)  | Lançar, Início, Balanço |
| 9 | Excluir Lançamento (Lançar) | Lançar, Início, Balanço |

## Style

- **Tabs** for C# (project default in `dotnet new webapi`)
- **Tabs or 2 spaces** for Dart (project default in `flutter create`)
- **No emojis** in code or docs

## Build & Run

```bash
# Backend
cd backend/FluxoCaixa.Api
dotnet run

# Frontend (web)
cd frontend
flutter run -d chrome

# Frontend (Android)
flutter run -d android
```

## Adding a new field to Lançamento

1. Add the column to `db/schema.sql`
2. Add the property to `Models/Lancamento.cs`
3. Map the column in `AppDbContext.OnModelCreating`
4. Add the property to `Dtos/LancamentoDtos.cs`
5. Use it in `Controllers/LancamentosController.cs` (and `BalancoController.cs` if it affects aggregates)
6. Mirror in the Flutter side: `lib/models/lancamento.dart` and any UI that reads the field
7. If the new field is required for a `tipo`, update the trigger in `db/schema.sql`

## Auth (ADR 0007)

Configuração vive em `appsettings.json` sob `Auth:Pin` e `Jwt:*`. Sem `Auth:Pin` ou `Jwt:Secret` o backend **falha no startup** com mensagem clara — não sobe com config parcial.

- **PIN em texto puro** em `Auth:Pin`. `TokenService` (singleton) hasheia com BCrypt em memória no startup e descarta a string em claro. O `AuthOptions.Pin` é zerado após o bootstrap. Trocar o PIN = editar o `appsettings.json` e reiniciar o backend.
- **JWT secret** em `Jwt:Secret` precisa ter **pelo menos 32 caracteres**. Para produção, gere com `openssl rand -base64 48`. O template versionado tem um placeholder obviamente falso.
- **Validade** do JWT: `Jwt:ExpiryDays` (default 30). Sem refresh token — o app re-prompt o PIN na próxima abertura quando o token expira.
- **Rate limit** em `/api/auth/login`: 5 req/min/IP (fixed window, sem persistência). Acima disso, responde 429. Configurado em `Program.cs` na policy `login`. Apenas o endpoint de login é limitado; os demais endpoints não têm rate limit (single user na LAN).
- **Autorização global**: `Program.cs` define `options.FallbackPolicy = RequireAuthenticatedUser()`. Toda action exige JWT válido **exceto** se marcada com `[AllowAnonymous]`. Hoje só `AuthController.Login` é anônima.
- **Limitação aceita**: trocar o PIN não invalida JWTs já emitidos dentro da janela de 30 dias. Trade-off documentado no ADR 0007; mitigação futura seria um claim `pinVersion`.

Flutter (`lib/services/api_client.dart`):

- `ApiClient.token` é `null` antes do login. O `MaterialApp` raiz troca entre `HomeScreen` e `PinLockScreen` via `ValueListenableBuilder` escutando `ApiClient.tokenNotifier`.
- Todo request HTTP (exceto `/api/auth/login`) adiciona `Authorization: Bearer <jwt>` automaticamente.
- Em 401 (exceto no próprio login), `ApiClient` chama `clearToken()` — o `MaterialApp` reage e re-exibe a `PinLockScreen`.
- O JWT **nunca** é persistido em disco (web descartaria no DevTools mesmo). Em web, fechar a aba = pedir o PIN de novo.

Quando adicionar um novo controller, **não precisa** de `[Authorize]` explícito — a política global já cobre. Use `[AllowAnonymous]` apenas em endpoints que devem ser públicos.

## PDV Legado (Ponto-de-Venda/)

The `Ponto-de-Venda/` subdirectory is a **read-only reference** of the existing .NET 9 WinForms POS. Do NOT modify it. The new app is intentionally independent from the PDV (see `docs/adr/0001-manual-entry-as-source-of-truth.md`).
