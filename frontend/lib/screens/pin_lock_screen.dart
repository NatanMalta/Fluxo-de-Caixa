import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/auth_service.dart';

/// Tela de bloqueio por PIN (ADR 0007).
///
/// Exibida no nível do `MaterialApp` enquanto `ApiClient.token == null`.
/// Substitui todo o app: navegação por abas, telas individuais etc.
/// ficam inacessíveis até o login ser feito com sucesso.
///
/// UX:
/// - Teclado numérico na tela (4-8 dígitos), botão backspace, botão
///   "Entrar" desabilitado até atingir o `pinLength`.
/// - Após entrar o tamanho exigido, dispara o login automaticamente
///   (sem precisar de botão "OK" extra) — mais rápido no celular.
/// - Mensagem de erro abaixo dos pinos, sem alerta modal.
/// - Sem retry automático; após erro, o usuário apaga e digita de novo.
class PinLockScreen extends StatefulWidget {
  /// Quantos dígitos o PIN tem. A tela aceita de 4 a 8 (o backend
  /// valida com a mesma faixa em `AuthController`).
  final int pinLength;

  const PinLockScreen({super.key, this.pinLength = 4});

  @override
  State<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends State<PinLockScreen> {
  String _pin = '';
  bool _loading = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    // Mantém a tela viva enquanto o app está bloqueado. Não impede
    // rotação nem nada — só evita que o sistema "durma" o app
    // enquanto o usuário digita o PIN.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  Future<void> _tentarLogin() async {
    if (_loading || _pin.length != widget.pinLength) return;
    setState(() {
      _loading = true;
      _erro = null;
    });
    final erro = await AuthService.login(_pin);
    if (!mounted) return;
    if (erro == null) {
      // Sucesso: o `MaterialApp` reage ao `tokenNotifier` e desmonta
      // esta tela. Nada mais a fazer aqui.
      return;
    }
    setState(() {
      _loading = false;
      _erro = erro;
      _pin = '';
    });
  }

  void _adicionarDigito(int d) {
    if (_loading) return;
    if (_pin.length >= widget.pinLength) return;
    setState(() {
      _pin += d.toString();
      _erro = null;
    });
    // Auto-submit ao completar o tamanho esperado. Mais rápido que
    // pedir um "OK" extra, especialmente no celular.
    if (_pin.length == widget.pinLength) {
      _tentarLogin();
    }
  }

  void _apagar() {
    if (_loading) return;
    if (_pin.isEmpty) return;
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _erro = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.lock_outline,
                    size: 56,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Fluxo de Caixa',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Digite o PIN para entrar',
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
                  ),
                  const SizedBox(height: 32),
                  _PinosDisplay(
                    preenchidos: _pin.length,
                    total: widget.pinLength,
                    erro: _erro != null,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 20,
                    child: _erro == null
                        ? const SizedBox.shrink()
                        : Text(
                            _erro!,
                            style: TextStyle(
                              color: Colors.red.shade700,
                              fontSize: 13,
                            ),
                          ),
                  ),
                  const SizedBox(height: 16),
                  _Teclado(
                    onDigito: _adicionarDigito,
                    onApagar: _apagar,
                    habilitado: !_loading,
                  ),
                  const SizedBox(height: 12),
                  if (_loading)
                    const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PinosDisplay extends StatelessWidget {
  final int preenchidos;
  final int total;
  final bool erro;

  const _PinosDisplay({
    required this.preenchidos,
    required this.total,
    required this.erro,
  });

  @override
  Widget build(BuildContext context) {
    final cor = erro ? Colors.red.shade400 : Theme.of(context).colorScheme.primary;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < total; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < preenchidos ? cor : Colors.transparent,
              border: Border.all(color: cor, width: 2),
            ),
          ),
        ],
      ],
    );
  }
}

/// Teclado numérico 3x4: 1-9 na primeira/segunda/terceira linha,
/// vazio/0/backspace na quarta. Estilo minimalista — botão com
/// toque visual ao pressionar.
class _Teclado extends StatelessWidget {
  final ValueChanged<int> onDigito;
  final VoidCallback onApagar;
  final bool habilitado;

  const _Teclado({
    required this.onDigito,
    required this.onApagar,
    required this.habilitado,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _linha([1, 2, 3]),
        _linha([4, 5, 6]),
        _linha([7, 8, 9]),
        _ultimaLinha(),
      ],
    );
  }

  Widget _linha(List<int> digitos) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final d in digitos) _botao(d),
      ],
    );
  }

  Widget _ultimaLinha() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Espaço vazio para alinhar o "0" com a coluna do meio.
        const _BotaoVazio(),
        _botao(0),
        _BotaoIcone(
          icone: Icons.backspace_outlined,
          onTap: habilitado ? onApagar : null,
        ),
      ],
    );
  }

  Widget _botao(int d) {
    return _BotaoDigito(
      digito: d,
      onTap: habilitado ? () => onDigito(d) : null,
    );
  }
}

class _BotaoDigito extends StatelessWidget {
  final int digito;
  final VoidCallback? onTap;
  const _BotaoDigito({required this.digito, this.onTap});

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.all(6),
      child: Material(
        color: onTap == null ? Colors.grey.shade200 : Colors.grey.shade100,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 72,
            height: 72,
            child: Center(
              child: Text(
                digito.toString(),
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w500,
                  color: onTap == null ? Colors.grey : cor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BotaoVazio extends StatelessWidget {
  const _BotaoVazio();
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(6),
      child: SizedBox(width: 72, height: 72),
    );
  }
}

class _BotaoIcone extends StatelessWidget {
  final IconData icone;
  final VoidCallback? onTap;
  const _BotaoIcone({required this.icone, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(6),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 72,
            height: 72,
            child: Center(
              child: Icon(
                icone,
                size: 26,
                color: onTap == null
                    ? Colors.grey.shade300
                    : Colors.grey.shade800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
