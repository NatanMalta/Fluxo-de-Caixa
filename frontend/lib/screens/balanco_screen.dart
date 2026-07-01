import 'package:flutter/material.dart';

import '../main.dart';
import '../models/balanco.dart';
import '../services/api_client.dart';
import '../services/periodo_calculator.dart';

class BalancoScreen extends StatefulWidget {
  const BalancoScreen({super.key});

  @override
  State<BalancoScreen> createState() => _BalancoScreenState();
}

class _BalancoScreenState extends State<BalancoScreen> {
  PeriodoBalanco _periodo = PeriodoBalanco.esteMes;
  DateTime? _customInicio;
  DateTime? _customFim;
  Future<Balanco>? _future;

  @override
  void initState() {
    super.initState();
    _recalcular();
  }

  void _recalcular() {
    final p = calcularPeriodo(
      _periodo,
      referencia: DateTime.now(),
      customInicio: _customInicio,
      customFim: _customFim,
    );
    setState(() {
      _future = ApiClient.obterBalanco(inicio: p.inicio, fim: p.fim);
    });
  }

  void _mudarPeriodo(PeriodoBalanco novo) async {
    if (novo == PeriodoBalanco.customizado) {
      final agora = DateTime.now();
      final picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
        initialDateRange: _customInicio != null && _customFim != null
            ? DateTimeRange(start: _customInicio!, end: _customFim!)
            : DateTimeRange(start: agora, end: agora),
      );
      if (picked == null) return; // usuário cancelou
      setState(() {
        _periodo = novo;
        _customInicio = picked.start;
        _customFim = picked.end;
      });
    } else {
      setState(() => _periodo = novo);
    }
    _recalcular();
  }

  String get _rotuloPeriodo {
    switch (_periodo) {
      case PeriodoBalanco.hoje:
        return 'Hoje';
      case PeriodoBalanco.esteMes:
        return 'Este mês';
      case PeriodoBalanco.esteAno:
        return 'Este ano';
      case PeriodoBalanco.customizado:
        if (_customInicio == null || _customFim == null) return 'Personalizado';
        return '${dateFormat.format(_customInicio!)} – ${dateFormat.format(_customFim!)}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Balanço'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _recalcular,
            tooltip: 'Atualizar',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: _PeriodoSelector(
            selecionado: _periodo,
            onChanged: _mudarPeriodo,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async => _recalcular(),
        child: FutureBuilder<Balanco>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return _ErroView(
                mensagem: snap.error.toString(),
                onRetry: _recalcular,
              );
            }
            final b = snap.data!;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    _rotuloPeriodo,
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ),
                const SizedBox(height: 8),
                _TotaisCards(balanco: b),
                const SizedBox(height: 16),
                _SecaoSaldosPorConta(saldos: b.saldosPorConta),
                const SizedBox(height: 16),
                _SecaoCategorias(
                  titulo: 'Entradas por categoria',
                  itens: b.entradasPorCategoria,
                  cor: Colors.green.shade700,
                  icone: Icons.arrow_upward,
                ),
                const SizedBox(height: 16),
                _SecaoCategorias(
                  titulo: 'Saídas por categoria',
                  itens: b.saidasPorCategoria,
                  cor: Colors.red.shade700,
                  icone: Icons.arrow_downward,
                ),
                const SizedBox(height: 24),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PeriodoSelector extends StatelessWidget {
  final PeriodoBalanco selecionado;
  final ValueChanged<PeriodoBalanco> onChanged;
  const _PeriodoSelector({required this.selecionado, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          for (final p in PeriodoBalanco.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(_rotuloCurto(p)),
                selected: selecionado == p,
                onSelected: (_) => onChanged(p),
              ),
            ),
        ],
      ),
    );
  }

  static String _rotuloCurto(PeriodoBalanco p) {
    switch (p) {
      case PeriodoBalanco.hoje:
        return 'Hoje';
      case PeriodoBalanco.esteMes:
        return 'Este mês';
      case PeriodoBalanco.esteAno:
        return 'Este ano';
      case PeriodoBalanco.customizado:
        return 'Personalizado';
    }
  }
}

class _TotaisCards extends StatelessWidget {
  final Balanco balanco;
  const _TotaisCards({required this.balanco});

  @override
  Widget build(BuildContext context) {
    final positivo = balanco.resultado >= 0;
    return Column(
      children: [
        _TotalCard(
          titulo: 'Entradas',
          valor: balanco.totalEntradas,
          cor: Colors.green.shade700,
          icone: Icons.arrow_upward,
        ),
        const SizedBox(height: 8),
        _TotalCard(
          titulo: 'Saídas',
          valor: balanco.totalSaidas,
          cor: Colors.red.shade700,
          icone: Icons.arrow_downward,
        ),
        const SizedBox(height: 8),
        _TotalCard(
          titulo: 'Resultado',
          valor: balanco.resultado,
          cor: positivo ? Colors.green.shade800 : Colors.red.shade800,
          icone: positivo ? Icons.trending_up : Icons.trending_down,
          destaque: true,
        ),
      ],
    );
  }
}

class _TotalCard extends StatelessWidget {
  final String titulo;
  final double valor;
  final Color cor;
  final IconData icone;
  final bool destaque;
  const _TotalCard({
    required this.titulo,
    required this.valor,
    required this.cor,
    required this.icone,
    this.destaque = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(destaque ? 18 : 14),
        child: Row(
          children: [
            Icon(icone, color: cor, size: destaque ? 32 : 24),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                titulo,
                style: TextStyle(
                  fontSize: destaque ? 19 : 16,
                  fontWeight: destaque ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
            Text(
              currencyFormat.format(valor),
              style: TextStyle(
                fontSize: destaque ? 24 : 18,
                fontWeight: FontWeight.bold,
                color: cor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SecaoSaldosPorConta extends StatelessWidget {
  final List<ContaSaldo> saldos;
  const _SecaoSaldosPorConta({required this.saldos});

  @override
  Widget build(BuildContext context) {
    return _SecaoWrapper(
      titulo: 'Saldos por conta',
      icone: Icons.account_balance_outlined,
      vazioMsg: 'Nenhuma conta ativa.',
      children: saldos.map((s) {
        final negativo = s.saldo < 0;
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            backgroundColor: Colors.blue.shade50,
            child: Icon(
              Icons.account_balance,
              color: Colors.blue.shade700,
              size: 20,
            ),
          ),
          title: Text(
            s.nome,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          trailing: Text(
            currencyFormat.format(s.saldo),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: negativo ? Colors.red.shade700 : Colors.green.shade800,
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _SecaoCategorias extends StatelessWidget {
  final String titulo;
  final List<CategoriaTotal> itens;
  final Color cor;
  final IconData icone;
  const _SecaoCategorias({
    required this.titulo,
    required this.itens,
    required this.cor,
    required this.icone,
  });

  @override
  Widget build(BuildContext context) {
    final total = itens.fold<double>(0, (acc, c) => acc + c.total);
    return _SecaoWrapper(
      titulo: titulo,
      icone: icone,
      vazioMsg: 'Nada no período.',
      children: [
        for (final c in itens) ...[
          _LinhaCategoria(categoria: c, cor: cor, totalGeral: total),
          const Divider(height: 1),
        ],
      ],
    );
  }
}

class _LinhaCategoria extends StatelessWidget {
  final CategoriaTotal categoria;
  final Color cor;
  final double totalGeral;
  const _LinhaCategoria({
    required this.categoria,
    required this.cor,
    required this.totalGeral,
  });

  @override
  Widget build(BuildContext context) {
    final pct = totalGeral > 0
        ? (categoria.total / totalGeral).clamp(0.0, 1.0)
        : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  categoria.nome,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
              Text(
                currencyFormat.format(categoria.total),
                style: TextStyle(fontWeight: FontWeight.bold, color: cor),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 6,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(
                cor.withValues(alpha: 0.7),
              ),
            ),
          ),
          const SizedBox(height: 2),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${(pct * 100).toStringAsFixed(0)}%',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ),
        ],
      ),
    );
  }
}

class _SecaoWrapper extends StatelessWidget {
  final String titulo;
  final IconData icone;
  final String vazioMsg;
  final List<Widget> children;
  const _SecaoWrapper({
    required this.titulo,
    required this.icone,
    required this.vazioMsg,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final temConteudo = children.isNotEmpty;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icone, size: 20, color: Colors.grey.shade700),
                const SizedBox(width: 8),
                Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (temConteudo)
              ...children
            else
              Text(vazioMsg, style: TextStyle(color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }
}

class _ErroView extends StatelessWidget {
  final String mensagem;
  final VoidCallback onRetry;
  const _ErroView({required this.mensagem, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 80),
        Icon(Icons.error_outline, size: 60, color: Colors.red.shade400),
        const SizedBox(height: 12),
        const Text(
          'Não foi possível carregar o balanço',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Text(
          mensagem,
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
        ),
        const SizedBox(height: 16),
        Center(
          child: FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Tentar de novo'),
          ),
        ),
      ],
    );
  }
}
