# Fluxo de Caixa — Agent Guide

## Project Overview

- **Type**: Two-tier local app — Flutter (web + Android) frontend + ASP.NET 10 Web API backend
- **Persistence**: SQLite (single file: `backend/FluxoCaixa.Api/fluxo_caixa.db`)
- **Deployment**: Local server (PC) inside the store, accessed via Wi-Fi. No cloud, no internet.
- **Users**: Single user (the store owner). No auth, no roles.

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

## Frontend Conventions

- **Flutter stable**, Material 3, `intl` for BRL currency formatting
- **State management**: `setState` for v1 (no Provider/Riverpod yet). Add a state lib if screens start prop-drilling heavily.
- **Cross-tab coordination**: `HomeScreen` holds `GlobalKey<DashboardScreenState>` and `GlobalKey<LancarScreenState>` to call public methods on the children (`editar`, `atualizar`). Children stay mounted via `IndexedStack`. See ADR 0004.
- **API base URL**: hardcoded in `lib/services/api_client.dart`. Three common values:
  - Web on the same PC: `http://localhost:5000`
  - Android emulator: `http://10.0.2.2:5000`
  - Android device on Wi-Fi: `http://<PC_IP>:5000`
- **No tests** in v1. Add `test/` files as the project grows.

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

## PDV Legado (Ponto-de-Venda/)

The `Ponto-de-Venda/` subdirectory is a **read-only reference** of the existing .NET 9 WinForms POS. Do NOT modify it. The new app is intentionally independent from the PDV (see `docs/adr/0001-manual-entry-as-source-of-truth.md`).
