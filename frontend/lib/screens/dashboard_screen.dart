import 'package:flutter/material.dart';

import '../main.dart';
import '../models/conta.dart';
import '../services/api_client.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<List<Conta>> _future;

  @override
  void initState() {
    super.initState();
    _future = ApiClient.listarContas();
  }

  Future<void> _atualizar() async {
    setState(() {
      _future = ApiClient.listarContas();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Início'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _atualizar),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _atualizar,
        child: FutureBuilder<List<Conta>>(
          future: _future,
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
            final contas = snap.data ?? <Conta>[];
            if (contas.isEmpty) return const _VazioView();
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: contas.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) => _ContaTile(conta: contas[i]),
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
