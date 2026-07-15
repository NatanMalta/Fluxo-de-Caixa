import 'package:flutter/material.dart';

import '../main.dart';
import '../models/conta.dart';
import '../models/lancamento.dart';
import '../services/api_client.dart';
import '../services/data_invalidator.dart';

/// Sub-tela "Extrato da Conta": lista cronologicamente os Lançamentos
/// que afetam uma única Conta (Comum, Ajuste e Transferência, com
/// `sentido` derivado para Transferência). Acessada via tap em uma
/// Conta no Dashboard — não é uma 5ª aba no `NavigationBar`.
///
/// Reusa o canal `onTapLancamento` (ADR 0004) para que tocar em um
/// Lançamento abra a edição na aba Lançar. Refresh via
/// `DataInvalidator.lancamentos` e `DataInvalidator.contas` (ADR 0006).
/// Sem mudanças no backend — usa o `GET /api/Lancamentos?contaId=...`
/// existente.
class ExtratoContaScreen extends StatefulWidget {
  final Conta conta;
  final ValueChanged<Lancamento>? onTapLancamento;

  const ExtratoContaScreen({
    super.key,
    required this.conta,
    this.onTapLancamento,
  });

  @override
  State<ExtratoContaScreen> createState() => _ExtratoContaScreenState();
}

class _ExtratoContaScreenState extends State<ExtratoContaScreen> {
  late DateTime _de;
  late DateTime _ate;
  // 'todas' | 'entrada' | 'saida'. Aplicado client-side após a busca.
  String _sentido = 'todas';

  // Altura do cabeçalho sticky (saldo + filtros). Usada pelo
  // `PreferredSize` do AppBar.bottom.
  static const double _headerHeight = 124;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _de = DateTime(now.year, now.month, 1);
    _ate = now;
  }

  Future<List<Lancamento>> _carregar() {
    return ApiClient.listarLancamentos(
      contaId: widget.conta.id,
      inicio: _de,
      fim: _ate,
    );
  }

  /// Dispara o refresh via `DataInvalidator` (ver ADR 0006). Usado
  /// pelo pull-to-refresh e pelo botão de refresh do AppBar.
  void _atualizar() {
    DataInvalidator.lancamentos.value++;
    DataInvalidator.contas.value++;
  }

  /// `sentido` efetivo do Lançamento em relação à `widget.conta`:
  /// - Comum / Ajuste: usa o `sentido` armazenado.
  /// - Transferência: derivado. `contaDestinoId == estaConta` → entrada;
  ///   `contaOrigemId == estaConta` → saída. (Impossível ambos por causa
  ///   do trigger do backend, mas o helper é defensivo.)
  String? _sentidoRelativo(Lancamento l) {
    if (l.isComum || l.isAjuste) return l.sentido;
    if (l.contaDestinoId == widget.conta.id) return 'entrada';
    if (l.contaOrigemId == widget.conta.id) return 'saida';
    return null;
  }

  Future<void> _escolherDe() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _de,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _de = picked);
  }

  Future<void> _escolherAte() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _ate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _ate = picked);
  }

  String _rotuloSentido(String s) {
    switch (s) {
      case 'todas':
        return 'Todas';
      case 'entrada':
        return 'Entradas';
      case 'saida':
        return 'Saídas';
    }
    return s;
  }

  @override
  Widget build(BuildContext context) {
    final negativo = widget.conta.saldoAtual < 0;
    return Scaffold(
      appBar: AppBar(
        title: Text('Extrato — ${widget.conta.nome}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _atualizar,
            tooltip: 'Atualizar',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(_headerHeight),
          child: Container(
            color: Theme.of(context).appBarTheme.backgroundColor
                ?? Theme.of(context).colorScheme.surface,
            child: Column(
              children: [
                // Linha do saldo atual.
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: Row(
                    children: [
                      Text(
                        'Saldo atual:',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 13,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        currencyFormat.format(widget.conta.saldoAtual),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: negativo
                              ? Colors.red.shade700
                              : Colors.green.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
                // Filtros de data.
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: _DatePickerButton(
                          label: 'De',
                          date: _de,
                          onTap: _escolherDe,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _DatePickerButton(
                          label: 'Até',
                          date: _ate,
                          onTap: _escolherAte,
                        ),
                      ),
                    ],
                  ),
                ),
                // Filtro de sentido (aplicado client-side).
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
                  child: Row(
                    children: [
                      for (final s in const ['todas', 'entrada', 'saida'])
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(_rotuloSentido(s)),
                            selected: _sentido == s,
                            onSelected: (_) =>
                                setState(() => _sentido = s),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async => _atualizar(),
        child: ListenableBuilder(
          listenable: Listenable.merge([
            DataInvalidator.lancamentos,
            DataInvalidator.contas,
          ]),
          builder: (context, _) => FutureBuilder<List<Lancamento>>(
            future: _carregar(),
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return _ErroView(
                  mensagem: snap.error.toString(),
                  onRetry: _atualizar,
                );
              }
              final todos = snap.data ?? <Lancamento>[];
              final filtrados = _sentido == 'todas'
                  ? todos
                  : todos
                        .where((l) => _sentidoRelativo(l) == _sentido)
                        .toList();
              return _ExtratoLista(
                conta: widget.conta,
                lancamentos: filtrados,
                onTapLancamento: widget.onTapLancamento,
                emptyMsg: 'Nenhum lançamento nesta conta neste período.',
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Botão tátil que abre um `showDatePicker` quando tocado. Mostra a
/// data atual em `dateFormat` (`dd/MM/yyyy`).
class _DatePickerButton extends StatelessWidget {
  final String label;
  final DateTime date;
  final VoidCallback onTap;

  const _DatePickerButton({
    required this.label,
    required this.date,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
          suffixIcon: const Icon(Icons.calendar_today, size: 18),
        ),
        child: Text(dateFormat.format(date)),
      ),
    );
  }
}

/// Lista do extrato: linhas tipo extrato bancário + footer com totais.
class _ExtratoLista extends StatelessWidget {
  final Conta conta;
  final List<Lancamento> lancamentos;
  final ValueChanged<Lancamento>? onTapLancamento;
  final String emptyMsg;

  const _ExtratoLista({
    required this.conta,
    required this.lancamentos,
    required this.onTapLancamento,
    required this.emptyMsg,
  });

  /// Calcula os totais a partir da lista já filtrada. Defensivo contra
  /// `sentido` ausente (impossível em dados válidos, mas a soma não
  /// quebra).
  ({double entradas, double saidas}) _totais() {
    var e = 0.0;
    var s = 0.0;
    for (final l in lancamentos) {
      final sen = _sentidoEfetivo(l);
      if (sen == 'entrada') {
        e += l.valor;
      } else if (sen == 'saida') {
        s += l.valor;
      }
    }
    return (entradas: e, saidas: s);
  }

  String _sentidoEfetivo(Lancamento l) {
    if (l.isComum || l.isAjuste) return l.sentido ?? '';
    if (l.contaDestinoId == conta.id) return 'entrada';
    if (l.contaOrigemId == conta.id) return 'saida';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    if (lancamentos.isEmpty) {
      return ListView(
        // Conteúdo scrollável para o `RefreshIndicator` funcionar
        // também no estado vazio.
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 120),
          Center(
            child: Text(
              emptyMsg,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
        ],
      );
    }
    final totais = _totais();
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 4, bottom: 24),
      itemCount: lancamentos.length + 1, // +1 para o footer.
      itemBuilder: (context, i) {
        if (i < lancamentos.length) {
          final l = lancamentos[i];
          return _ExtratoRow(
            lancamento: l,
            conta: conta,
            onTap: onTapLancamento == null
                ? null
                : () {
                    Navigator.pop(context);
                    onTapLancamento!(l);
                  },
          );
        }
        return _TotaisFooter(entradas: totais.entradas, saidas: totais.saidas);
      },
    );
  }
}

/// Linha de extrato no estilo de extrato bancário:
///   [dd/MM]   [icon]  título                     ±R$ valor
///   [weekday]         subtítulo
class _ExtratoRow extends StatelessWidget {
  final Lancamento lancamento;
  final Conta conta;
  final VoidCallback? onTap;

  const _ExtratoRow({
    required this.lancamento,
    required this.conta,
    required this.onTap,
  });

  String get _sentidoEfetivo {
    if (lancamento.isComum || lancamento.isAjuste) {
      return lancamento.sentido ?? '';
    }
    if (lancamento.contaDestinoId == conta.id) return 'entrada';
    if (lancamento.contaOrigemId == conta.id) return 'saida';
    return '';
  }

  IconData get _icone {
    if (lancamento.isComum) return Icons.swap_horiz;
    if (lancamento.isAjuste) return Icons.tune;
    return Icons.compare_arrows;
  }

  Color get _cor {
    final s = _sentidoEfetivo;
    if (s == 'entrada') return Colors.green.shade700;
    if (s == 'saida') return Colors.red.shade700;
    return Colors.grey;
  }

  String get _sinal {
    final s = _sentidoEfetivo;
    if (s == 'entrada') return '+';
    if (s == 'saida') return '−';
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

  static const _diasSemanaCurto = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];

  String _weekday(DateTime d) => _diasSemanaCurto[d.weekday - 1];

  @override
  Widget build(BuildContext context) {
    final data = lancamento.data;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            // Coluna fixa da data (esquerda): dd/MM em cima, dia da semana
            // abreviado embaixo.
            SizedBox(
              width: 44,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    '${data.day.toString().padLeft(2, '0')}/'
                    '${data.month.toString().padLeft(2, '0')}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _weekday(data),
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: _cor.withValues(alpha: 0.15),
              child: Icon(_icone, color: _cor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _titulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    _subtitulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$_sinal ${currencyFormat.format(lancamento.valor)}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: _cor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Footer com os totais do range filtrado: Entradas │ Saídas.
class _TotaisFooter extends StatelessWidget {
  final double entradas;
  final double saidas;

  const _TotaisFooter({required this.entradas, required this.saidas});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: _ColunaTotal(
                  label: 'Entradas',
                  valor: entradas,
                  cor: Colors.green.shade800,
                ),
              ),
              Container(
                width: 1,
                height: 36,
                color: Colors.grey.shade300,
                margin: const EdgeInsets.symmetric(horizontal: 8),
              ),
              Expanded(
                child: _ColunaTotal(
                  label: 'Saídas',
                  valor: saidas,
                  cor: Colors.red.shade800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ColunaTotal extends StatelessWidget {
  final String label;
  final double valor;
  final Color cor;

  const _ColunaTotal({
    required this.label,
    required this.valor,
    required this.cor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
        ),
        const SizedBox(height: 2),
        Text(
          currencyFormat.format(valor),
          style: TextStyle(
            color: cor,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}

/// Cópia local de `_ErroView` por enquanto — o handoff pediu para
/// extrair para um widget compartilhado só quando uma 3ª tela precisar.
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
          'Não foi possível carregar o extrato',
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
