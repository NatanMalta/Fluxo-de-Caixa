import 'package:flutter/material.dart';

import '../models/lancamento.dart';
import 'dashboard_screen.dart';
import 'lancar_screen.dart';
import 'balanco_screen.dart';
import 'config_screen.dart';

/// Shell da aplicação. Mantém as quatro tabs como filhas irmãs que ficam
/// montadas durante a troca de abas (ver ADR 0004).
///
/// Coordenação entre tabs (ver ADR 0006 — `DataInvalidator`):
/// - `DataInvalidator` cuida da propagação de mutações: cada tela
///   escuta os notifiers relevantes via `ListenableBuilder` e as
///   mutações bumparam o notifier apropriado depois do `await`.
/// - O canal `onTapLancamento` (Dashboard → Lançar) ainda vale: ele
///   cuida de "saltar para a aba Lançar com o form pré-preenchido",
///   não de refresh.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _indice = 0;

  // Mantido: o `LancarScreen.editar(Lancamento)` é o canal da direção
  // Dashboard → Lançar (saltar para a aba com o form pré-preenchido).
  // Ver ADR 0004.
  final _lancarKey = GlobalKey<LancarScreenState>();

  /// Handler do `onTapLancamento` do Dashboard:
  /// chama `editar` no Lançar e em seguida troca para a aba Lançar.
  void _onTapLancamento(Lancamento l) {
    _lancarKey.currentState?.editar(l);
    setState(() => _indice = 1);
  }

  void _aoTrocarAba(int novo) {
    setState(() => _indice = novo);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _indice,
        children: [
          DashboardScreen(onTapLancamento: _onTapLancamento),
          LancarScreen(key: _lancarKey),
          const BalancoScreen(),
          const ConfigScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _indice,
        onDestinationSelected: _aoTrocarAba,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Início',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_circle_outline),
            selectedIcon: Icon(Icons.add_circle),
            label: 'Lançar',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Balanço',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Config',
          ),
        ],
      ),
    );
  }
}
