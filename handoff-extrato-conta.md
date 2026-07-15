# Handoff — Extrato da Conta (feature)

## TL;DR for the next agent

You are picking up a **single, well-scoped feature** on the Fluxo de Caixa app at `C:/Users/natan/Documents/Projetos/Fluxo de caixa/`: a new "Extrato da Conta" sub-screen. The design has been fully grilled and is **locked** — do not re-derive the design decisions, do not propose alternative navigation patterns, do not add a backend endpoint. Implement exactly what's described below.

If the project-wide handoff `handoff-fluxo-caixa.md` is also present, read it first for project context. The rest of this document is self-contained for this feature.

## What this feature is

A new screen, **Extrato da Conta**, that lists chronologically all the Lançamentos affecting a single Conta (Comum, Ajuste, and Transferência — the last one with a derived `sentido`). It has two filters (date range, sentido) and shows the totals for the filtered range at the bottom.

It is **not** a new tab in the bottom `NavigationBar`. It is a **sub-screen pushed via `Navigator.push`** when the user taps a `Conta` in the Dashboard's `_ContaTile`. The list of Contas in the Dashboard is the natural index to pick the Conta; the Extrato itself does not need an in-screen account picker.

## Design decisions (locked)

| # | Theme | Decision |
|---|-------|----------|
| 1 | **Name** | "Extrato da Conta" — entry already added to `CONTEXT.md` (between Balanço and Loja). `transação` stays in `Avoid`. |
| 2 | **Position** | Sub-screen via `Navigator.push` from a tap on a `Conta` in the Dashboard. **Not** a 5th tab. |
| 3 | **Content** | All 3 Lançamento types. `Transferência` gets a derived `sentido` (entrada if `ContaDestinoId == estaConta`, saída if `ContaOrigemId == estaConta`). |
| 4 | **Date filter** | Two `showDatePicker` buttons in the sticky header (De / Até). Default: "este mês" = day 1 of current month → today. |
| 5 | **Sentido filter** | 3 `ChoiceChip`s in a second row of the sticky header: "Todas" / "Entradas" / "Saídas". Default: "Todas". **Applied client-side** (no backend change). |
| 6 | **Header** | Title "Extrato — {Conta.nome}" + the **current** `saldoAtual` of the Conta (no extra backend call — `Conta` is passed in as a constructor argument; `widget.conta.saldoAtual`). |
| 7 | **Row layout** | Bank-statement style: date in a fixed left column (`dd/MM` + weekday), then icon + description + signed amount on the right. Icon, color, sign and title follow the same pattern as the existing `_RecenteTile` in `dashboard_screen.dart` (lines 339-370). |
| 8 | **Tap on a row** | Reuses the `RecenteTile` channel (ADR 0004): `Navigator.pop(context)` then invoke the `onTapLancamento` callback (provided by `HomeScreen`). The callback already handles switching to the Lançar tab and calling `editar(l)`. **No new tab-switching logic.** |
| 9 | **No text search** | v1 keeps only the 2 filters the user asked for. Reconsider if real usage calls for it. |
| 10 | **Footer** | After the last Lançamento, a `Card` showing "Entradas: R$ X │ Saídas: R$ Y" for the filtered range. Sums computed client-side from the loaded list (same `sentido` rule as the filter). |
| 11 | **Dashboard affordance** | Add `onTap` to the `_ContaTile`'s `ListTile`. The Material ripple is the only signal — no chevron, no subtitle hint. |
| 12 | **`DataInvalidator`** | Listen to `DataInvalidator.lancamentos` and `DataInvalidator.contas` (wrap the `FutureBuilder` in two nested `ListenableBuilder`s, or use `Listenable.merge`). **Do not add a new notifier** and **do not modify any mutator** — they already bump the right counters. |
| 13 | **Loading/erro/vazio** | Reuse existing patterns. Loading: `CircularProgressIndicator` in `Center`. Error: copy `_ErroView` from `balanco_screen.dart` (line 456) for now; extract to a shared widget only when 3+ screens need it. Empty: simple centered text "Nenhum lançamento nesta conta neste período." |
| 14 | **Pagination** | None. Volume realistic: <1k rows in the default range, <10k in "all time". `ListView.builder` with `itemCount = list.length`. |
| 15 | **Backend** | **Zero changes.** Reuse `GET /api/Lancamentos?contaId=X&inicio=YYYY-MM-DD&fim=YYYY-MM-DD` (already exists, already filters by all three Lançamento types for a given Conta, already orders by `Data DESC, Id DESC`). |
| 16 | **`AGENTS.md`** | **No change.** No new build/deploy/test convention introduced. The "Lançar is the only place of mutation" rule is preserved (the Extrato is read-only, taps just navigate to Lançar). |

## Files to create / modify

### Create

- **`frontend/lib/screens/extrato_conta_screen.dart`** — the new screen. Constructor takes `Conta conta` and `ValueChanged<Lancamento>? onTapLancamento`. Internal state: `DateTime _de`, `DateTime _ate`, `String _sentidoFiltro` (`"todas" | "entrada" | "saida"`). On any change, bump `DataInvalidator.lancamentos` and `DataInvalidator.contas` would NOT re-trigger a refetch — wait, the bumps are **external** (from mutators). Internally, `setState` is enough; the bump notifiers are the trigger for cross-tab refresh.

  Skeleton (high-level, not full code):
  ```dart
  class ExtratoContaScreen extends StatefulWidget {
    final Conta conta;
    final ValueChanged<Lancamento>? onTapLancamento;
    const ExtratoContaScreen({super.key, required this.conta, this.onTapLancamento});
    @override
    State<ExtratoContaScreen> createState() => _ExtratoContaScreenState();
  }

  class _ExtratoContaScreenState extends State<ExtratoContaScreen> {
    late DateTime _de;
    late DateTime _ate;
    String _sentido = 'todas';

    @override
    void initState() {
      super.initState();
      final now = DateTime.now();
      _de = DateTime(now.year, now.month, 1);
      _ate = now;
    }

    // The FutureBuilder re-fires on:
    //   (a) setState (filter change) — wrap inside AnimatedBuilder or rebuild inline
    //   (b) DataInvalidator.lancamentos / .contas bumps (mutations elsewhere)
    // Build with a ValueListenable on the filtered params, or just call setState
    // when filters change + wrap the FutureBuilder in ListenableBuilder for the
    // notifiers.

    // Helper: derive sentido for a Lancamento relative to widget.conta
    String? _sentidoRelativo(Lancamento l) {
      if (l.isComum || l.isAjuste) return l.sentido; // 'entrada' | 'saida'
      // Transferência
      if (l.contaDestinoId == widget.conta.id) return 'entrada';
      if (l.contaOrigemId == widget.conta.id) return 'saida';
      return null; // shouldn't happen if the backend filtered correctly
    }

    // Footer totals: sum entries / exits from the already-loaded list, after
    // the same sentido filter (defensive — if the filter were ever skipped,
    // footer still respects it).
  }
  ```

### Modify

- **`frontend/lib/screens/home_screen.dart`** — add a `_onContaTap(Conta c)` method:
  ```dart
  void _onContaTap(Conta c) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExtratoContaScreen(
          conta: c,
          onTapLancamento: _onTapLancamento, // existing — already wired to Lancar
        ),
      ),
    );
  }
  ```
  Pass `_onContaTap` to `DashboardScreen` as a new optional `onContaTap` callback (matches the existing `onTapLancamento` pattern).

- **`frontend/lib/screens/dashboard_screen.dart`** — accept the `onContaTap` callback, forward it to `_ContasList` → `_ContaTile`, and add `onTap: widget.onContaTap` on the `_ContaTile`'s `ListTile`. No other change (the trailing saldo, leading icon, etc. stay as-is).

### Do NOT touch

- `CONTEXT.md` — already updated.
- `db/schema.sql`, `backend/FluxoCaixa.Api/**` — zero backend changes.
- `frontend/lib/services/api_client.dart` — `listarLancamentos({contaId, inicio, fim, tipo})` already supports everything.
- `frontend/lib/services/data_invalidator.dart` — no new notifier.
- Any mutator (`lancar_screen.dart`, `config_screen.dart`) — they already bump the right notifiers.
- `docs/adr/` — no new ADR (the "why sub-screen vs 5th tab" rationale lives inline in the new `CONTEXT.md` entry).
- `AGENTS.md` — no new build/deploy convention.

## Reuse cheat sheet (copy from these)

- **Row tile pattern** (icon + color + sign + title + subtitle + trailing amount): `frontend/lib/screens/dashboard_screen.dart` lines 334-406 (`_RecenteTile`).
- **`_ErroView`**: `frontend/lib/screens/balanco_screen.dart` lines 456-490. Copy it into `extrato_conta_screen.dart` for now; extract when a 3rd caller appears.
- **`Lancamento` accessors** (`isComum`, `isAjuste`, `isTransferencia`, `sentido`, `categoriaNome`, `descricao`, `contaOrigemNome`, `contaDestinoNome`): `frontend/lib/models/lancamento.dart`. Same getters used by `_RecenteTile` apply.
- **Date formatting / currency formatting**: the `dateFormat` and `currencyFormat` globals from `frontend/lib/main.dart` (already imported by every other screen).

## Risks / things to watch

1. **Coordinating the `onTapLancamento` callback**: it has to be plumbed `HomeScreen → DashboardScreen → _ContasList → _ContaTile → Navigator.push → ExtratoContaScreen` — 5 levels of constructor forwarding. Keep it boring (constructor param at each step); do not introduce an `InheritedWidget` just for this.
2. **Transferência sentido**: the helper `_sentidoRelativo(Lancamento l)` must handle the case where `l.contaDestinoId == widget.conta.id` AND `l.contaOrigemId == widget.conta.id` (impossible in practice, but defensive). The backend's `LancamentosController.Listar` only returns Lançamentos where at least one of those matches, so the helper should never return `null` for a row in the list.
3. **Saldo no header**: always show `widget.conta.saldoAtual` (the "current" value). If the user filters to a past range, the displayed saldo does **not** match the end-of-range saldo. This is documented in `CONTEXT.md` and is the expected behavior for v1.
4. **Footer sums**: compute from the same list already in memory (after the sentido filter). Don't issue a second API call for totals — the totals are derivable from the data already on screen.
5. **`DataInvalidator` plumbing**: the user mutates a Lançamento on the Lançar tab. That mutator bumps `DataInvalidator.lancamentos`. The Extrato (if mounted) listens to that and re-fetches. If the user has the Extrato open on the screen and mutates something via `onTapLancamento`, the `Navigator.pop` happens **before** the `await` of the mutation completes (the `editar` is a "fill the form" action; the actual save is a separate user action in Lançar). The pop + tab-switch + future bump + future-listener-refetch sequence is the same pattern the existing `RecenteTile` relies on. No new edge case.
6. **No `git commit` / `git push` / `git reset`** unless the user explicitly asks. Same rule as the rest of the project.

## Suggested order of implementation

1. Create `extrato_conta_screen.dart` with the data flow (FutureBuilder + filtros + sticky header) **without** the footer. Verify it renders a list of Lançamentos for a Conta.
2. Add the footer ("Entradas / Saídas do range").
3. Wire the entry point: `HomeScreen._onContaTap` → push; `Dashboard` → `_ContasList` → `_ContaTile` → `onTap`.
4. Test the tap-to-edit flow: tap a row in the Extrato → app pops back to Dashboard, switches to Lançar tab, opens the form with the Lançamento loaded.
5. `flutter analyze` → 0 errors.

## What success looks like

- Dashboard shows the existing list of Contas. Tapping any one opens the new Extrato screen.
- The Extrato header shows the Conta name and its current `saldoAtual`.
- The default view shows this month's Lançamentos for the Conta, all 3 types, with date on the left and the signed amount on the right.
- Changing "De" / "Até" / "Sentido" updates the list in place.
- The footer shows the totals for the current filter.
- Tapping a row pops back to the Dashboard, switches to the Lançar tab, and opens the Lançamento in the form.
- Mutating a Lançamento elsewhere (in Lançar) and returning to the Extrato shows the updated data without a manual refresh.
- `flutter analyze` clean. Backend untouched.
