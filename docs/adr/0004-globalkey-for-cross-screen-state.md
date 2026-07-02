# Home shell uses GlobalKey<State> for cross-screen coordination, not a state management library

The `HomeScreen` shell renders four tab children (`DashboardScreen`, `LancarScreen`, `BalancoScreen`, `ConfigScreen`) inside a single `Scaffold` with a `NavigationBar`. Switching tabs only mutates an `_indice` field; no `Navigator` push/pop happens. As a result, the children are siblings that stay mounted across tab switches, and there is no `Route` boundary for any "screen A tells screen B to do X" coordination.

The first feature that needed this coordination was the "últimos lançamentos" widget on the Dashboard: tapping a tile must trigger an edit in the `LancarScreen` (jump to that tab, pre-fill the form), and saving an edit on the `LancarScreen` must refresh the `DashboardScreen` (so the recents list, the Saldo total and the Contas tiles reflect the change). Both directions are required for the UX to feel "complete" — without the second, the user would edit a Lançamento and see stale data in the Dashboard until they pulled to refresh.

## Decision

The `_HomeScreenState` holds `GlobalKey<LancarScreenState>` and `GlobalKey<DashboardScreenState>`. Each child exposes the public methods the shell needs to call:

- `LancarScreen.editar(Lancamento l)` — pre-fills the form and scrolls it into view.
- `DashboardScreen.atualizar()` — re-fetches the Contas list and the recents list.

The `HomeScreen` orchestrates through two channels:

- A prop callback on the `DashboardScreen` (`onTapLancamento`) that the shell implements as: call `editar` on the Lancar key, then switch the tab to `Lancar`.
- A tab-change observer: when the previous tab is `Lancar` and the new tab is `Início`, call `atualizar()` on the Dashboard key. This catches any mutation made on the Lançar tab (create, edit, delete) without the Lançar screen having to know about the Dashboard at all.

We considered three alternatives:

- **Prop drilling through the shell.** Inverted the dependency in the wrong direction (children would have to call into the shell, then the shell would re-call into the other child), and added ceremony for a single event type.
- **Prop + `didUpdateWidget` on Lancar.** Required a "consumed / not consumed" protocol to avoid replaying the same intent, and did not help the reverse direction (Lançar → Dashboard refresh) at all.
- **A state management library (Provider, Riverpod, Bloc).** Solves the problem in a more general way, but violates the v1 "setState for v1" rule in `AGENTS.md` and is overkill for one event type and two consumers.

`GlobalKey<State>` is one of the sanctioned uses of `GlobalKey` in Flutter (cross-widget access to a `State`), and the use case here — a common parent calling public methods on a sibling — is exactly that case.

## Consequences

- **No new dependency.** Stays in the v1 `setState` envelope.
- **Coordination lives in one place.** All tab-to-tab wiring is in `_HomeScreenState`. The children only know about their own public methods.
- **Explicit data flow.** A reader can follow the chain "user tapped tile → `onTapLancamento` callback → `_lancarKey.currentState?.editar(l)` → `setState(() => _indice = 1)`" without indirection.
- **Tight coupling.** `_HomeScreenState` knows the public method names of the children (`editar`, `atualizar`). Acceptable for an app of this size (v1, single user, four screens), but the cost grows with the number of children.
- **Symmetric risk of staleness.** The tab-change observer fires on **any** tab switch from Lançar to Início, even if the user just opened the form and went back without saving. One extra HTTP round-trip is cheap, and the simplicity is worth it.

## When to revisit

- If `_HomeScreenState` ends up holding **three or more** `GlobalKey<State>`, the cost of "one GlobalKey per child" stops paying off. At that point, lifting the relevant state (e.g., a "data version" counter bumped on mutations) or adopting a small state lib becomes worth it.
- If a new feature requires **broadcasting** the same event to multiple children at once (e.g., "the user changed the active Categoria list — refresh Dashboard, Lancar, and Balanco"), a `ValueNotifier` or `ChangeNotifier` in the shell is the natural next step.
- If the home shell ever becomes a real `Navigator` (e.g., nested routes per tab), this ADR becomes obsolete — `RouteObserver` and the navigator stack take over.
