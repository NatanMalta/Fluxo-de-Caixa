import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../main.dart';
import '../models/categoria.dart';
import '../models/conta.dart';
import '../models/lancamento.dart';
import '../services/api_client.dart';
import '../services/lancamento_dto_builder.dart';
import '../services/valor_parser.dart';

// Formato pt-BR para o campo de valor (exibe "1.234,56" no campo ao re-editar).
final _valorFmt = NumberFormat.decimalPattern('pt_BR')
  ..minimumFractionDigits = 2
  ..maximumFractionDigits = 2;

class LancarScreen extends StatefulWidget {
  const LancarScreen({super.key});

  @override
  State<LancarScreen> createState() => LancarScreenState();
}

class LancarScreenState extends State<LancarScreen> {
  // -- Estado de carregamento de dados auxiliares (contas e categorias) --
  late Future<_LancarDados> _futureDados;

  // -- Estado do formulário --
  String? _tipo; // 'comum' | 'ajuste' | 'transferencia'
  String? _sentido; // 'entrada' | 'saida' (Comum e Ajuste)
  int? _contaId; // Comum e Ajuste
  int? _categoriaId; // Comum
  int? _contaOrigemId; // Transferência
  int? _contaDestinoId; // Transferência
  DateTime _data = DateTime.now();

  final _valorCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _formKey = GlobalKey();

  // -- Estado de edição --
  Lancamento? _editando;
  bool _salvando = false;

  // -- Estado da lista "Lançamentos de hoje" --
  Future<List<Lancamento>>? _futureHoje;

  @override
  void initState() {
    super.initState();
    _carregarTudo();
  }

  @override
  void dispose() {
    _valorCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _carregarTudo() {
    setState(() {
      _futureDados = _carregarDados();
      _futureHoje = _carregarHoje();
    });
  }

  Future<_LancarDados> _carregarDados() async {
    final contas = await ApiClient.listarContas();
    final catsEntrada = await ApiClient.listarCategorias(tipo: 'entrada');
    final catsSaida = await ApiClient.listarCategorias(tipo: 'saida');
    return _LancarDados(contas, catsEntrada, catsSaida);
  }

  Future<List<Lancamento>> _carregarHoje() async {
    final hoje = DateTime.now();
    return ApiClient.listarLancamentos(
      inicio: DateTime(hoje.year, hoje.month, hoje.day),
      fim: DateTime(hoje.year, hoje.month, hoje.day),
    );
  }

  void _limparFormulario({bool manterTipo = false}) {
    setState(() {
      if (!manterTipo) _tipo = null;
      _sentido = null;
      _contaId = null;
      _categoriaId = null;
      _contaOrigemId = null;
      _contaDestinoId = null;
      _data = DateTime.now();
      _valorCtrl.clear();
      _descCtrl.clear();
      _editando = null;
    });
  }

  void _prefillFromLancamento(Lancamento l) {
    setState(() {
      _editando = l;
      _tipo = l.tipo;
      _data = l.data;
      _valorCtrl.text = _valorFmt.format(l.valor);
      _descCtrl.text = l.descricao ?? '';
      _sentido = l.sentido;
      _contaId = l.contaId;
      _categoriaId = l.categoriaId;
      _contaOrigemId = l.contaOrigemId;
      _contaDestinoId = l.contaDestinoId;
    });
  }

  /// Preenche o formulário com [l] para edição e rola o card do formulário
  /// para que fique visível. Chamado pelo `HomeScreen` quando o usuário toca
  /// em um Lançamento no widget "Últimos lançamentos" do Dashboard
  /// (ver ADR 0004).
  void editar(Lancamento l) {
    _prefillFromLancamento(l);
    final ctx = _formKey.currentContext;
    if (ctx == null) return;
    // Garante que o setState de _prefillFromLancamento já rebuildou
    // antes de tentarmos rolar até o card.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  String? _validar(_LancarDados dados) {
    if (_tipo == null) return 'Escolha o tipo de lançamento.';
    final valor = parseValor(_valorCtrl.text);
    if (valor == null) return 'Informe um valor numérico.';
    if (valor == 0) return 'O valor deve ser maior que zero.';

    switch (_tipo) {
      case 'comum':
        if (_sentido == null) return 'Escolha se é entrada ou saída.';
        if (_contaId == null) return 'Escolha a conta.';
        if (_categoriaId == null) return 'Escolha a categoria.';
        if (_sentido == 'entrada' &&
            !dados.catsEntrada.any((c) => c.id == _categoriaId)) {
          return 'Categoria incompatível com o sentido.';
        }
        if (_sentido == 'saida' &&
            !dados.catsSaida.any((c) => c.id == _categoriaId)) {
          return 'Categoria incompatível com o sentido.';
        }
        break;
      case 'ajuste':
        if (_sentido == null) return 'Escolha se é entrada ou saída.';
        if (_contaId == null) return 'Escolha a conta.';
        if (_descCtrl.text.trim().isEmpty) return 'Informe a descrição.';
        break;
      case 'transferencia':
        if (_contaOrigemId == null) return 'Escolha a conta de origem.';
        if (_contaDestinoId == null) return 'Escolha a conta de destino.';
        if (_contaOrigemId == _contaDestinoId) {
          return 'Origem e destino não podem ser a mesma conta.';
        }
        break;
    }
    return null;
  }

  Future<void> _salvar(_LancarDados dados) async {
    final erro = _validar(dados);
    if (erro != null) {
      _mostrarErro(erro);
      return;
    }
    final valor = parseValor(_valorCtrl.text)!;

    setState(() => _salvando = true);
    try {
      Map<String, dynamic> dto;
      switch (_tipo) {
        case 'comum':
          dto = buildLancamentoComumDto(
            data: _data,
            valor: valor,
            contaId: _contaId!,
            categoriaId: _categoriaId!,
            sentido: _sentido!,
          );
          break;
        case 'ajuste':
          dto = buildLancamentoAjusteDto(
            data: _data,
            valor: valor,
            contaId: _contaId!,
            sentido: _sentido!,
            descricao: _descCtrl.text,
          );
          break;
        case 'transferencia':
          dto = buildLancamentoTransferenciaDto(
            data: _data,
            valor: valor,
            contaOrigemId: _contaOrigemId!,
            contaDestinoId: _contaDestinoId!,
          );
          break;
        default:
          return;
      }

      final estavaEditando = _editando != null;
      if (estavaEditando) {
        await ApiClient.atualizarLancamento(_editando!.id, dto);
      } else {
        await ApiClient.criarLancamento(dto);
      }
      _limparFormulario();
      _carregarTudo();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              estavaEditando ? 'Alterações salvas.' : 'Lançamento salvo.',
            ),
          ),
        );
      }
    } catch (e) {
      _mostrarErro('Erro ao salvar: $e');
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  void _mostrarErro(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red.shade700),
    );
  }

  Future<void> _excluir(Lancamento l) async {
    final confirma = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir lançamento?'),
        content: Text(
          '${l.tituloResumido} — ${currencyFormat.format(l.valor)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirma != true) return;
    try {
      await ApiClient.excluirLancamento(l.id);
      if (_editando?.id == l.id) _limparFormulario();
      _carregarTudo();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Lançamento excluído.')));
      }
    } catch (e) {
      _mostrarErro('Erro ao excluir: $e');
    }
  }

  Future<void> _escolherData() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _data,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _data = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lançar'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _carregarTudo,
            tooltip: 'Atualizar',
          ),
        ],
      ),
      body: FutureBuilder<_LancarDados>(
        future: _futureDados,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return _ErroView(
              mensagem: snap.error.toString(),
              onRetry: _carregarTudo,
            );
          }
          final dados = snap.data!;
          if (dados.contas.isEmpty) {
            return const _VazioSemContas();
          }
          return RefreshIndicator(
            onRefresh: () async => _carregarTudo(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildForm(dados),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 8),
                _buildListaHoje(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildForm(_LancarDados dados) {
    return Card(
      key: _formKey,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  _editando == null ? 'Novo lançamento' : 'Editar lançamento',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (_editando != null) ...[
                  const Spacer(),
                  TextButton(
                    onPressed: _limparFormulario,
                    child: const Text('Cancelar'),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'comum',
                  label: Text('Comum'),
                  icon: Icon(Icons.swap_horiz),
                ),
                ButtonSegment(
                  value: 'ajuste',
                  label: Text('Ajuste'),
                  icon: Icon(Icons.tune),
                ),
                ButtonSegment(
                  value: 'transferencia',
                  label: Text('Transf.'),
                  icon: Icon(Icons.compare_arrows),
                ),
              ],
              selected: _tipo == null ? <String>{} : {_tipo!},
              emptySelectionAllowed: true,
              onSelectionChanged: _editando != null
                  ? null
                  : (sel) {
                      if (sel.isEmpty) return;
                      final novo = sel.first;
                      if (novo == _tipo) return;
                      setState(() {
                        _tipo = novo;
                        _sentido = null;
                        _contaId = null;
                        _categoriaId = null;
                        _contaOrigemId = null;
                        _contaDestinoId = null;
                      });
                    },
            ),
            const SizedBox(height: 16),
            _DataField(data: _data, onTap: _escolherData),
            const SizedBox(height: 12),
            if (_tipo == 'comum')
              _FormComum(
                dados: dados,
                sentido: _sentido,
                contaId: _contaId,
                categoriaId: _categoriaId,
                onSentido: (v) => setState(() {
                  _sentido = v;
                  _categoriaId = null;
                }),
                onConta: (v) => setState(() => _contaId = v),
                onCategoria: (v) => setState(() => _categoriaId = v),
              )
            else if (_tipo == 'ajuste')
              _FormAjuste(
                dados: dados,
                sentido: _sentido,
                contaId: _contaId,
                descricaoCtrl: _descCtrl,
                onSentido: (v) => setState(() => _sentido = v),
                onConta: (v) => setState(() => _contaId = v),
              )
            else if (_tipo == 'transferencia')
              _FormTransferencia(
                dados: dados,
                contaOrigemId: _contaOrigemId,
                contaDestinoId: _contaDestinoId,
                onOrigem: (v) => setState(() => _contaOrigemId = v),
                onDestino: (v) => setState(() => _contaDestinoId = v),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _valorCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,R\$\s]')),
              ],
              decoration: const InputDecoration(
                labelText: 'Valor (R\$)',
                border: OutlineInputBorder(),
                prefixText: 'R\$ ',
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _salvando ? null : () => _salvar(dados),
              icon: _salvando
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(_editando == null ? Icons.add : Icons.save),
              label: Text(_editando == null ? 'Salvar' : 'Salvar alterações'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListaHoje() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Text(
            'Lançamentos de hoje',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 8),
        FutureBuilder<List<Lancamento>>(
          future: _futureHoje,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.all(8),
                child: LinearProgressIndicator(),
              );
            }
            final lista = snap.data ?? <Lancamento>[];
            if (lista.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 4,
                ),
                child: Text(
                  'Nenhum lançamento hoje ainda.',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              );
            }
            return Column(
              children: lista
                  .map(
                    (l) => _LancamentoTile(
                      lancamento: l,
                      onEdit: () {
                        _prefillFromLancamento(l);
                        Scrollable.ensureVisible(
                          context,
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOut,
                        );
                      },
                      onDelete: () => _excluir(l),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}

class _LancarDados {
  final List<Conta> contas;
  final List<Categoria> catsEntrada;
  final List<Categoria> catsSaida;
  _LancarDados(this.contas, this.catsEntrada, this.catsSaida);
}

class _DataField extends StatelessWidget {
  final DateTime data;
  final VoidCallback onTap;
  const _DataField({required this.data, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Data',
          border: OutlineInputBorder(),
          suffixIcon: Icon(Icons.calendar_today),
        ),
        child: Text(dateFormat.format(data)),
      ),
    );
  }
}

class _SentidoToggle extends StatelessWidget {
  final String? sentido; // 'entrada' | 'saida'
  final ValueChanged<String> onChanged;
  const _SentidoToggle({required this.sentido, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(
          value: 'entrada',
          label: Text('Entrada'),
          icon: Icon(Icons.arrow_upward),
        ),
        ButtonSegment(
          value: 'saida',
          label: Text('Saída'),
          icon: Icon(Icons.arrow_downward),
        ),
      ],
      selected: sentido == null ? <String>{} : {sentido!},
      emptySelectionAllowed: true,
      onSelectionChanged: (sel) {
        if (sel.isNotEmpty) onChanged(sel.first);
      },
    );
  }
}

class _ContaDropdown extends StatelessWidget {
  final List<Conta> contas;
  final int? contaId;
  final String label;
  final ValueChanged<int?> onChanged;
  const _ContaDropdown({
    required this.contas,
    required this.contaId,
    required this.label,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int>(
      initialValue: contaId,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: contas
          .where((c) => c.ativo)
          .map((c) => DropdownMenuItem(value: c.id, child: Text(c.nome)))
          .toList(),
      onChanged: onChanged,
    );
  }
}

class _FormComum extends StatelessWidget {
  final _LancarDados dados;
  final String? sentido;
  final int? contaId;
  final int? categoriaId;
  final ValueChanged<String> onSentido;
  final ValueChanged<int?> onConta;
  final ValueChanged<int?> onCategoria;
  const _FormComum({
    required this.dados,
    required this.sentido,
    required this.contaId,
    required this.categoriaId,
    required this.onSentido,
    required this.onConta,
    required this.onCategoria,
  });

  @override
  Widget build(BuildContext context) {
    final catsFiltradas = sentido == 'entrada'
        ? dados.catsEntrada
        : dados.catsSaida;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SentidoToggle(sentido: sentido, onChanged: onSentido),
        const SizedBox(height: 12),
        _ContaDropdown(
          contas: dados.contas,
          contaId: contaId,
          label: 'Conta',
          onChanged: onConta,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
          initialValue: categoriaId,
          decoration: const InputDecoration(
            labelText: 'Categoria',
            border: OutlineInputBorder(),
          ),
          items: catsFiltradas
              .where((c) => c.ativo)
              .map((c) => DropdownMenuItem(value: c.id, child: Text(c.nome)))
              .toList(),
          onChanged: sentido == null ? null : onCategoria,
        ),
      ],
    );
  }
}

class _FormAjuste extends StatelessWidget {
  final _LancarDados dados;
  final String? sentido;
  final int? contaId;
  final TextEditingController descricaoCtrl;
  final ValueChanged<String> onSentido;
  final ValueChanged<int?> onConta;
  const _FormAjuste({
    required this.dados,
    required this.sentido,
    required this.contaId,
    required this.descricaoCtrl,
    required this.onSentido,
    required this.onConta,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SentidoToggle(sentido: sentido, onChanged: onSentido),
        const SizedBox(height: 12),
        _ContaDropdown(
          contas: dados.contas,
          contaId: contaId,
          label: 'Conta',
          onChanged: onConta,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: descricaoCtrl,
          decoration: const InputDecoration(
            labelText: 'Descrição',
            border: OutlineInputBorder(),
            hintText: 'Ex.: Tarifa bancária, rendimento, contagem do caixa',
          ),
          maxLength: 200,
        ),
      ],
    );
  }
}

class _FormTransferencia extends StatelessWidget {
  final _LancarDados dados;
  final int? contaOrigemId;
  final int? contaDestinoId;
  final ValueChanged<int?> onOrigem;
  final ValueChanged<int?> onDestino;
  const _FormTransferencia({
    required this.dados,
    required this.contaOrigemId,
    required this.contaDestinoId,
    required this.onOrigem,
    required this.onDestino,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ContaDropdown(
          contas: dados.contas,
          contaId: contaOrigemId,
          label: 'Conta de origem',
          onChanged: onOrigem,
        ),
        const SizedBox(height: 12),
        _ContaDropdown(
          contas: dados.contas,
          contaId: contaDestinoId,
          label: 'Conta de destino',
          onChanged: onDestino,
        ),
      ],
    );
  }
}

class _LancamentoTile extends StatelessWidget {
  final Lancamento lancamento;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _LancamentoTile({
    required this.lancamento,
    required this.onEdit,
    required this.onDelete,
  });

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

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        onTap: onEdit,
        leading: CircleAvatar(
          backgroundColor: _cor.withValues(alpha: 0.15),
          child: Icon(_icone, color: _cor, size: 20),
        ),
        title: Text(
          lancamento.tituloResumido,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          lancamento.subtituloResumido,
          style: TextStyle(color: Colors.grey.shade700),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$_sinal ${currencyFormat.format(lancamento.valor)}',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: _cor,
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: Icon(Icons.delete_outline, color: Colors.red.shade400),
              onPressed: onDelete,
              tooltip: 'Excluir',
            ),
          ],
        ),
      ),
    );
  }
}

class _VazioSemContas extends StatelessWidget {
  const _VazioSemContas();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 80),
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
          'Vá em Configurações para cadastrar suas contas antes de lançar.',
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

extension on Lancamento {
  String get tituloResumido {
    if (isComum) return categoriaNome ?? 'Comum';
    if (isAjuste) return descricao ?? 'Ajuste';
    return 'Transferência';
  }

  String get subtituloResumido {
    if (isComum) return contaNome ?? '';
    if (isAjuste) return contaNome ?? '';
    return '${contaOrigemNome ?? '?'}  →  ${contaDestinoNome ?? '?'}';
  }
}
