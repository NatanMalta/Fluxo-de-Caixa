import 'package:flutter/material.dart';

import '../models/conta.dart';
import '../models/categoria.dart';
import '../services/api_client.dart';

class ConfigScreen extends StatefulWidget {
  const ConfigScreen({super.key});

  @override
  State<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends State<ConfigScreen> {
  late Future<List<Conta>> _futureContas;
  late Future<List<Categoria>> _futureCatsEntrada;
  late Future<List<Categoria>> _futureCatsSaida;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  void _carregar() {
    setState(() {
      _futureContas = ApiClient.listarContas(incluirInativas: true);
      _futureCatsEntrada = ApiClient.listarCategorias(
        tipo: 'entrada',
        incluirInativas: true,
      );
      _futureCatsSaida = ApiClient.listarCategorias(
        tipo: 'saida',
        incluirInativas: true,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      body: RefreshIndicator(
        onRefresh: () async => _carregar(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _SecaoContas(future: _futureContas, onChanged: _carregar),
            const SizedBox(height: 16),
            _SecaoCategorias(
              titulo: 'Categorias de Entrada',
              future: _futureCatsEntrada,
              tipo: 'entrada',
              onChanged: _carregar,
            ),
            const SizedBox(height: 16),
            _SecaoCategorias(
              titulo: 'Categorias de Saída',
              future: _futureCatsSaida,
              tipo: 'saida',
              onChanged: _carregar,
            ),
          ],
        ),
      ),
    );
  }
}

class _SecaoContas extends StatelessWidget {
  final Future<List<Conta>> future;
  final VoidCallback onChanged;
  const _SecaoContas({required this.future, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Contas',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => _abrirDialogConta(context, null),
                  icon: const Icon(Icons.add),
                  label: const Text('Nova'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FutureBuilder<List<Conta>>(
              future: future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.all(8),
                    child: LinearProgressIndicator(),
                  );
                }
                final contas = snap.data ?? <Conta>[];
                if (contas.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Nenhuma conta cadastrada.',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  );
                }
                return _ContasList(
                  contas: contas,
                  onEditConta: (c) => _abrirDialogConta(context, c),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _abrirDialogConta(BuildContext context, Conta? existente) async {
    final nomeCtrl = TextEditingController(text: existente?.nome ?? '');
    final saldoCtrl = TextEditingController(
      text: existente?.saldoInicial.toStringAsFixed(2) ?? '0.00',
    );
    var tipo = existente?.tipo ?? 'banco';
    var ativo = existente?.ativo ?? true;

    final salvo = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(existente == null ? 'Nova conta' : 'Editar conta'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nomeCtrl,
                  decoration: const InputDecoration(labelText: 'Nome'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: saldoCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Saldo inicial (R\$)',
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: tipo,
                  decoration: const InputDecoration(labelText: 'Tipo'),
                  items: const [
                    DropdownMenuItem(
                      value: 'banco',
                      child: Text('Conta bancária'),
                    ),
                    DropdownMenuItem(
                      value: 'especie',
                      child: Text('Dinheiro em espécie'),
                    ),
                  ],
                  onChanged: (v) => setLocal(() => tipo = v ?? 'banco'),
                ),
                if (existente != null) ...[
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Ativa'),
                    value: ativo,
                    onChanged: (v) => setLocal(() => ativo = v),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );

    if (salvo != true) return;
    final nome = nomeCtrl.text.trim();
    final saldo = double.tryParse(saldoCtrl.text.replaceAll(',', '.')) ?? 0.0;
    if (nome.isEmpty) return;

    try {
      if (existente == null) {
        await ApiClient.criarConta(nome: nome, tipo: tipo, saldoInicial: saldo);
      } else {
        await ApiClient.atualizarConta(
          Conta(
            id: existente.id,
            nome: nome,
            tipo: tipo,
            saldoInicial: saldo,
            ativo: ativo,
            criadoEm: existente.criadoEm,
            atualizadoEm: existente.atualizadoEm,
            saldoAtual: existente.saldoAtual,
          ),
        );
      }
      onChanged();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    }
  }
}


class _SecaoCategorias extends StatelessWidget {
  final String titulo;
  final Future<List<Categoria>> future;
  final String tipo; // 'entrada' | 'saida'
  final VoidCallback onChanged;
  const _SecaoCategorias({
    required this.titulo,
    required this.future,
    required this.tipo,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    titulo,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => _abrirDialog(context, null),
                  icon: const Icon(Icons.add),
                  label: const Text('Nova'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FutureBuilder<List<Categoria>>(
              future: future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.all(8),
                    child: LinearProgressIndicator(),
                  );
                }
                final cats = snap.data ?? <Categoria>[];
                if (cats.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Nenhuma categoria cadastrada.',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  );
                }
                return Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: cats
                      .map(
                        (c) => InputChip(
                          label: Text(
                            c.ativo ? c.nome : '${c.nome}  (inativa)',
                          ),
                          onPressed: () => _abrirDialog(context, c),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _abrirDialog(BuildContext context, Categoria? existente) async {
    final nomeCtrl = TextEditingController(text: existente?.nome ?? '');
    var ativo = existente?.ativo ?? true;

    final salvo = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(
            existente == null ? 'Nova categoria' : 'Editar categoria',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nomeCtrl,
                decoration: const InputDecoration(labelText: 'Nome'),
              ),
              if (existente != null) ...[
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Ativa'),
                  value: ativo,
                  onChanged: (v) => setLocal(() => ativo = v),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );

    if (salvo != true) return;
    final nome = nomeCtrl.text.trim();
    if (nome.isEmpty) return;

    try {
      if (existente == null) {
        await ApiClient.criarCategoria(nome: nome, tipo: tipo);
      } else {
        await ApiClient.atualizarCategoria(
          Categoria(
            id: existente.id,
            nome: nome,
            tipo: existente.tipo,
            ativo: ativo,
          ),
        );
      }
      onChanged();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    }
  }
}

class _ContasList extends StatefulWidget {
  final List<Conta> contas;
  final void Function(Conta) onEditConta;
  const _ContasList({required this.contas, required this.onEditConta});

  @override
  State<_ContasList> createState() => _ContasListState();
}

class _ContasListState extends State<_ContasList> {
  late final TextEditingController _searchCtrl;

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _searchCtrl,
      builder: (context, value, _) {
        final query = value.text.trim().toLowerCase();
        final filtered = query.isEmpty
            ? widget.contas
            : widget.contas
                  .where((c) => c.nome.toLowerCase().contains(query))
                  .toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Buscar por nome',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: value.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        tooltip: 'Limpar',
                        onPressed: () => _searchCtrl.clear(),
                      ),
              ),
            ),
            if (filtered.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  "Nenhuma conta encontrada para '${value.text.trim()}'.",
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemExtent: 56,
                itemCount: filtered.length,
                itemBuilder: (context, i) {
                  final c = filtered[i];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      c.isEspecie
                          ? Icons.payments_outlined
                          : Icons.account_balance_outlined,
                    ),
                    title: Text(c.nome),
                    subtitle: Text(
                      '${c.isEspecie ? "Espécie" : "Banco"} • Saldo inicial: R\$ ${c.saldoInicial.toStringAsFixed(2)}'
                      '${!c.ativo ? "  •  INATIVA" : ""}',
                    ),
                    onTap: () => widget.onEditConta(c),
                  );
                },
              ),
          ],
        );
      },
    );
  }
}

