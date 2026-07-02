import 'package:flutter/material.dart';

import '../models/lancamento.dart';
import 'dashboard_screen.dart';
import 'lancar_screen.dart';
import 'balanco_screen.dart';
import 'config_screen.dart';

/// Shell da aplicação. Mantém as quatro tabs como filhas irmãs que ficam
/// montadas durante a troca de abas (ver ADR 0004). A coordenação entre tabs
/// (Dashboard ↔ Lançar) é feita por `GlobalKey<State>` e dois canais:
///   - `onTapLancamento` (Dashboard → Lançar): editar um lançamento
///     selecionado no widget de últimos lançamentos.
///   - Observador de troca de tab (Lançar → Início): recarrega o Dashboard
///     para refletir mutações feitas no Lançar.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _indice = 0;

  // GlobalKeys para acessar os State públicos das filhas (ver ADR 0004).
  final _dashboardKey = GlobalKey<DashboardScreenState>();
  final _lancarKey = GlobalKey<LancarScreenState>();

  /// Handler do `onTapLancamento` do Dashboard:
  /// chama `editar` no Lançar e em seguida troca para a aba Lançar.
  void _onTapLancamento(Lancamento l) {
    _lancarKey.currentState?.editar(l);
    setState(() => _indice = 1);
  }

  /// Chamado em toda troca de aba. Se o usuário saiu de Lançar (1) e voltou
  /// para o Início (0), recarregamos o Dashboard para refletir mutações
  /// feitas no Lançar (criar, editar, excluir).
  void _aoTrocarAba(int novo) {
    if (_indice == 1 && novo == 0) {
      _dashboardKey.currentState?.atualizar();
    }
    setState(() => _indice = novo);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _indice,
        children: [
          DashboardScreen(
            key: _dashboardKey,
            onTapLancamento: _onTapLancamento,
          ),
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
