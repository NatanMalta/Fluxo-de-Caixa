# Handoff — Fluxo de Caixa do Mercadinho

## TL;DR for the next agent

You are picking up a brand-new cash-flow app for a small Brazilian grocery store ("mercadinho"). The project lives at `C:/Users/natan/Documents/Projetos/Fluxo de caixa/`. The domain has been fully grilled and the design is locked. The backend (ASP.NET 10 + EF Core + SQLite) and the Flutter client skeleton are in place and compile clean, but **two of the four Flutter screens are still placeholders**. Implementing those is the natural next step.

## What this project is

A local, single-user, single-store cash-flow tracker. The user retypes the day's totals (entradas, saídas) because they have observed the legacy POS give wrong cash-drawer totals — so the new app is intentionally independent from the POS in v1. See `docs/adr/0001-manual-entry-as-source-of-truth.md`.

## Critical artifacts (read these first — do NOT re-derive)

- **`C:/Users/natan/Documents/Projetos/Fluxo de caixa/CONTEXT.md`** — domain glossary. 11 terms. Defines `Conta`, `Lançamento` (with 3 subtypes: Comum, Ajuste, Transferência), `Categoria`, `Saldo`, `Ajuste`, `Transferência`, etc. Read this before designing new features; the canonical name for each concept is in there.
- **`C:/Users/natan/Documents/Projetos/Fluxo de caixa/docs/adr/`** — three ADRs:
  - `0001-manual-entry-as-source-of-truth.md` — PDV is independent in v1, no integration
  - `0002-local-server-no-cloud.md` — local server in the store, no cloud, no internet
  - `0003-daily-summary-granularity.md` — one Lançamento per (date, conta, categoria), not per sale
- **`C:/Users/natan/Documents/Projetos/Fluxo de caixa/db/schema.sql`** — canonical SQLite schema. Includes triggers that enforce per-type field constraints (a `comum` cannot have `conta_origem_id`, etc.). This is the source of truth; EF Core entities map to it.
- **`C:/Users/natan/Documents/Projetos/Fluxo de caixa/AGENTS.md`** — conventions, file layout, "how to add a field to Lançamento" recipe.
- **`C:/Users/natan/Documents/Projetos/Fluxo de caixa/README.md`** — how to run the backend and frontend.

## Current state of the code

### Backend — `backend/FluxoCaixa.Api/` — DONE, builds clean

- `Models/` — `Conta`, `Categoria`, `Lancamento`, `Enums.cs` (4 enums: `TipoConta`, `TipoCategoria`, `TipoLancamento`, `SentidoLancamento`)
- `Data/AppDbContext.cs` — EF Core DbContext; manages `criado_em` / `atualizado_em` automatically
- `Data/DatabaseInitializer.cs` — applies `db/schema.sql` at startup (idempotent, `IF NOT EXISTS` everywhere)
- `Services/SaldoCalculator.cs` — computes the current balance of a Conta (derives from `saldo_inicial` + sum of lançamentos)
- `Dtos/` — record types for create/update/response
- `Controllers/ContasController.cs` — full CRUD (delete is soft delete: sets `ativo = false`)
- `Controllers/CategoriasController.cs` — full CRUD (soft delete on `ativo`)
- `Controllers/LancamentosController.cs` — full CRUD; **catch trigger errors and return 400 with the trigger's Portuguese message**
- `Controllers/BalancoController.cs` — `GET /api/Balanco?inicio=&fim=` returns totalEntradas, totalSaidas, resultado, saldosPorConta, entradasPorCategoria, saidasPorCategoria. Ajustes ARE included in totals (their `sentido` puts them on the right side); Transferências are NOT.
- `Program.cs` — registers DbContext, scoped `SaldoCalculator`, open CORS, binds to `http://0.0.0.0:5000`, maps OpenAPI in dev. **Bootstrap calls `DatabaseInitializer.InitializeAsync(app)` before `app.Run()`.**

`dotnet build` → 0 errors. (Warnings are NuGet vulnerability advisories on `Microsoft.OpenApi` 2.0.0 and `SQLitePCLRaw.lib.e_sqlite3` 2.1.11 — non-blocking, but worth a `dotnet outdated` at some point.)

### Frontend — `frontend/` — analyzes clean, 2/4 screens done

- `lib/main.dart` — Material 3 theme, currency/date formatters, `FluxoCaixaApp` widget.
- `lib/services/api_client.dart` — single `ApiClient` class with static methods for every endpoint. `baseUrl` is a static `String` defaulting to `http://localhost:5000`. **For Android on a real device, this needs to be edited to the PC's LAN IP** (e.g. `http://192.168.x.x:5000`); the README documents the three common values.
- `lib/models/` — `conta.dart`, `categoria.dart`, `lancamento.dart`, `balanco.dart` (the last has `ContaSaldo` and `CategoriaTotal` inner records).
- `lib/screens/home_screen.dart` — `NavigationBar` with 4 destinations.
- `lib/screens/dashboard_screen.dart` — DONE. Calls `ApiClient.listarContas()`, shows a `Card` per conta with the `saldoAtual` from the backend, handles loading/empty/error states. Pull-to-refresh.
- `lib/screens/config_screen.dart` — DONE. CRUD for contas and categorias (both Entrada and Saída), with confirmation dialogs. Soft-delete UI: shows "INATIVA" tag for inactive items.
- `lib/screens/lancar_screen.dart` — **PLACEHOLDER**. Just a static icon + paragraph listing the 4 forms to build (Comum, Ajuste, Transferência, list-of-day with edit/excluir).
- `lib/screens/balanco_screen.dart` — **PLACEHOLDER**. Just a static icon + paragraph listing the period selector, total cards, saldos-por-conta, and breakdown-por-categoria.

`flutter analyze` → 0 errors, 2 info-level style nits (unnecessary underscores in `_ContaTile.separatorBuilder`, `<baseUrl>` angle brackets in a doc comment — both cosmetic).

## Decisions the next agent must respect

1. **Three types of Lançamento share one table** with discriminator `tipo` — the Flutter side mirrors this in a single `Lancamento` model. Do not propose separate tables or three distinct Dart classes.
2. **`Saldo` is derived**, never stored. The backend computes it on read. There is no `saldo` column anywhere.
3. **Ajustes and Transferências are special** — they don't use `Categoria`. Comum uses it.
4. **The user has no email/auth, no roles**. The app is single-user. Do not add a login screen.
5. **No cloud, no internet, no LAN access from outside the store**. The API binds to `0.0.0.0:5000` only because the user's phone needs to hit the PC over Wi-Fi. Do not change the binding to `localhost` only.
6. **No PDV integration in v1** (see ADR-0001). The PDV is at `Ponto-de-Venda/` and is **read-only reference** — do not touch it. The `tb_despesas` table mentioned in the legacy code has a `caixa` column with values `0`/`1`/`2` (some kind of "from the drawer" flag) — that ambiguity is a reason the user chose to re-type in the new app, not a bug to fix in the PDV.
7. **The Flutter `ApiClient.baseUrl` is hardcoded** and the user has not asked for a settings screen. Don't add one without asking.

## Concrete next steps (suggested order)

1. **Implement `lancar_screen.dart`**. You'll need:
   - A way to pick the type (Comum / Ajuste / Transferência) — three tabs or a segmented button.
   - A date picker (use `showDatePicker`).
   - A conta picker (`DropdownButtonFormField` populated from `ApiClient.listarContas()`).
   - A categoria picker for Comum (filtered by `tipo`).
   - A descricao field for Ajuste.
   - Two conta pickers for Transferência (origem ≠ destino).
   - A valor field (use `TextInputType.numberWithOptions(decimal: true)`).
   - A "Salvar" button that calls `ApiClient.criarLancamento({...})`. The DTO shape is in `lib/services/api_client.dart` and the backend's `LancamentoCreateDto` (in `Dtos/LancamentoDtos.cs`).
   - A small "Lançamentos de hoje" list at the bottom (or on a separate tab) so the user can edit/delete what they just entered.
2. **Implement `balanco_screen.dart`**:
   - A period selector (chips: Hoje / Este mês / Este ano / Custom).
   - Three `Card`s showing totalEntradas, totalSaidas, resultado (green if positivo, red if negativo).
   - A list of `ContaSaldo` from `saldosPorConta`.
   - Two sections ("Entradas por categoria", "Saídas por categoria") with `CategoriaTotal` rows.
3. **(Optional polish)** Fix the two `flutter analyze` info-level warnings.
4. **(Optional) Configurable API base URL**: a simple dialog or settings page that lets the user point the app at a different machine. The README mentions this gap explicitly.

## Things to NOT do

- Do not refactor `ApiClient` into a global singleton with state — it works fine as static methods, and adding `provider`/`riverpod` is out of scope for v1.
- Do not propose adding EF Core migrations. The schema is managed via `db/schema.sql` and applied by `DatabaseInitializer` at startup. Adding migrations would be a second source of truth.
- Do not propose adding a DTO for "list of lancamentos of a single day" — the existing `GET /api/Lancamentos?inicio=YYYY-MM-DD&fim=YYYY-MM-DD` already does that.
- Do not edit anything under `Ponto-de-Venda/`. The user was explicit about that.

## Tooling versions

- .NET SDK **10.0.300** (also .NET 9.0 was reported but the project targets `net10.0`).
- EF Core **10.0.9** (Sqlite + Design).
- Flutter **3.42.0** (May 2023) — quite old; if the user hits Dart-language friction, suggest `flutter upgrade` and re-run `flutter pub get`.
- `dotnet-ef` global tool **10.0.9** (installed via `dotnet tool install --global dotnet-ef`).

## Suggested skills for the next session

- **`design-an-interface`** — the Lançar form has 3 subtypes with overlapping but distinct fields, and the Balanço view aggregates 6 different pieces of data. Worth generating 2–3 radically different layouts for each before committing.
- **`tdd`** — once the Lançar/Balanço screens are sketched, the underlying value-calculation logic in `SaldoCalculator` and `BalancoController` is the kind of thing that should grow tests. The app currently has no test project at all; one of the first follow-ups would be to add `xunit` (backend) and the `test` package (Flutter).
- **`request-refactor-plan`** — only if the next session decides to tackle the configurable-API-URL / backup-script / state-management questions, which together could justify a multi-commit RFC.
- **`codebase-design`** — the `ApiClient` class is already 250+ lines with 14 static methods; before adding more endpoints, it's worth a pass to see if it can be tightened (e.g., a generic `request<T>` helper).

## Re-running the dev loop

```bash
# Terminal 1 — backend (port 5000, schema auto-applied on first run)
cd "C:/Users/natan/Documents/Projetos/Fluxo de caixa/backend/FluxoCaixa.Api"
dotnet run

# Terminal 2 — Flutter web (Chrome)
cd "C:/Users/natan/Documents/Projetos/Fluxo de caixa/frontend"
flutter run -d chrome

# Flutter Android (use the IP-edited ApiClient)
flutter run -d android
```

## Sensitive information redacted

- The PDV `appsettings.json` (at `Ponto-de-Venda/Ponto de Venda/appsettings.json`) contains a MySQL password in plain text. **Do not commit any change that includes it.** The new app does not use that connection string; do not add it to the new project's config.
- The user has a Portuguese-Brazilian context (currency `R$`, date format `dd/MM/yyyy`, Portuguese error messages from the SQLite triggers). All UI copy in the new app should be in Portuguese.
