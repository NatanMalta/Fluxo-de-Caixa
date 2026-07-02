import 'package:flutter/material.dart';

import '../main.dart';
import '../models/conta.dart';
import '../models/lancamento.dart';
import '../services/api_client.dart';

/// Quantos Lançamentos exibir no widget "Últimos lançamentos" do Dashboard.
const int _kRecentesMax = 5;

class DashboardScreen extends StatefulWidget {
  /// Disparado quando o usuário toca em um Lançamento no widget
  /// "Últimos lançamentos". O `HomeScreen` usa isto para acionar a
  /// edição no `LancarScreen` (ver ADR 0004).
  final ValueChanged<Lancamento>? onTapLancamento;

  const DashboardScreen({super.key, this.onTapLancamento});

  @override
  State<DashboardScreen> createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen> {
  late Future<List<Conta>> _futureContas;
  late Future<List<Lancamento>> _futureRecentes;

  @override
  void initState() {
    super.initState();
    _futureContas = ApiClient.listarContas();
    _futureRecentes = ApiClient.listarLancamentos();
  }

  /// Re-busca Contas e últimos Lançamentos. Chamado pelo pull-to-refresh,
  /// pelo botão de refresh do AppBar e pelo `HomeScreen` quando o usuário
  /// volta da aba Lançar (ver ADR 0004).
  Future<void> atualizar() async {
    setState(() {
      _futureContas = ApiClient.listarContas();
      _futureRecentes = ApiClient.listarLancamentos();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Início'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: atualizar),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: atualizar,
        child: FutureBuilder<List<Conta>>(
          future: _futureContas,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return _ErroView(
                mensagem: snap.error.toString(),
                onRetry: atualizar,
              );
            }
            final contas = snap.data ?? <Conta>[];
            final saldoTotal = contas.fold<double>(0, (acc, c) => acc + c.saldoAtual);
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _SaldoTotalCard(valor: saldoTotal),
                const SizedBox(height: 16),
                if (contas.isEmpty)
                  const _VazioView()
                else
                  for (final c in contas) ...[
                    _ContaTile(conta: c),
                    const SizedBox(height: 8),
                  ],
                const SizedBox(height: 8),
                _UltimosLancamentosSecao(
                  future: _futureRecentes,
                  onTap: widget.onTapLancamento,
                  onRetry: atualizar,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ContaTile extends StatelessWidget {
  final Conta conta;
  const _ContaTile({required this.conta});

  @override
  Widget build(BuildContext context) {
    final negativo = conta.saldoAtual < 0;
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: conta.isEspecie
              ? Colors.amber.shade100
              : Colors.blue.shade100,
          child: Icon(
            conta.isEspecie
                ? Icons.payments_outlined
                : Icons.account_balance_outlined,
            color: conta.isEspecie
                ? Colors.amber.shade900
                : Colors.blue.shade900,
          ),
        ),
        title: Text(
          conta.nome,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          conta.isEspecie ? 'Dinheiro em espécie' : 'Conta bancária',
        ),
        trailing: Text(
          currencyFormat.format(conta.saldoAtual),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: negativo ? Colors.red.shade700 : Colors.green.shade800,
          ),
        ),
      ),
    );
  }
}

class _VazioView extends StatelessWidget {
  const _VazioView();
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 32),
        Icon(
          Icons.account_balance_wallet_outlined,
          size: 80,
          color: Colors.grey.shade400,
        ),
        const SizedBox(height: 16),
        const Text(
          'Nenhuma conta cadastrada',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Text(
          'Vá em Configurações para cadastrar suas contas (caixa físico, conta-corrente, etc.) e categorias.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade600),
        ),
      ],
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
          'Não foi possível conectar ao backend',
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

class _SaldoTotalCard extends StatelessWidget {
  final double valor;
  const _SaldoTotalCard({required this.valor});

  @override
  Widget build(BuildContext context) {
    final negativo = valor < 0;
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Saldo total',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              currencyFormat.format(valor),
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: negativo ? Colors.red.shade700 : Colors.green.shade800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Seção "Últimos lançamentos" do Dashboard.
///
/// Mostra os `_kRecentesMax` Lançamentos mais recentes como tiles tocáveis.
/// Tocar em um tile invoca [onTap], que o `HomeScreen` usa para acionar a
/// edição na aba Lançar (ver ADR 0004).
class _UltimosLancamentosSecao extends StatelessWidget {
  final Future<List<Lancamento>> future;
  final ValueChanged<Lancamento>? onTap;
  final VoidCallback onRetry;

  const _UltimosLancamentosSecao({
    required this.future,
    required this.onTap,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.history,
                  size: 20,
                  color: Colors.grey.shade700,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Últimos lançamentos',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FutureBuilder<List<Lancamento>>(
              future: future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: LinearProgressIndicator(),
                  );
                }
                if (snap.hasError) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Erro ao carregar últimos lançamentos.',
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontSize: 13,
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: onRetry,
                            icon: const Icon(Icons.refresh, size: 18),
                            label: const Text('Tentar de novo'),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                final todos = snap.data ?? <Lancamento>[];
                final recentes = todos.take(_kRecentesMax).toList();
                if (recentes.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'Nenhum lançamento ainda.',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  );
                }
                return Column(
                  children: [
                    for (final l in recentes) _RecenteTile(lancamento: l, onTap: onTap),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _RecenteTile extends StatelessWidget {
  final Lancamento lancamento;
  final ValueChanged<Lancamento>? onTap;
  const _RecenteTile({required this.lancamento, required this.onTap});

  IconData get _icone {
    if (lancamento.isComum) return Icons.swap_horiz;
    if (lancamento.isAjuste) return Icons.tune;
    return Icons.compare_arrows;
  }

  Color get _cor {
    if (lancamento.isTransferencia) return Colors.blue.shade700;
    if (lancamento.sentido == 'entrada') return Colors.green.shade700;
    if (lancamento.sentido == 'saida') return Colors.red.shade700;
    return Colors.grey;
  }

  String get _sinal {
    if (lancamento.isTransferencia) return '';
    if (lancamento.sentido == 'entrada') return '+';
    if (lancamento.sentido == 'saida') return '−';
    return '';
  }

  String get _titulo {
    if (lancamento.isComum) return lancamento.categoriaNome ?? 'Comum';
    if (lancamento.isAjuste) return lancamento.descricao ?? 'Ajuste';
    return 'Transferência';
  }

  String get _subtitulo {
    if (lancamento.isComum) return lancamento.contaNome ?? '';
    if (lancamento.isAjuste) return lancamento.contaNome ?? '';
    return '${lancamento.contaOrigemNome ?? '?'}  →  '
        '${lancamento.contaDestinoNome ?? '?'}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        onTap: onTap == null ? null : () => onTap!(lancamento),
        leading: CircleAvatar(
          backgroundColor: _cor.withValues(alpha: 0.15),
          child: Icon(_icone, color: _cor, size: 20),
        ),
        title: Text(
          _titulo,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          _subtitulo,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: Colors.grey.shade700),
        ),
        trailing: Text(
          '$_sinal ${currencyFormat.format(lancamento.valor)}',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: _cor,
          ),
        ),
      ),
    );
  }
}
