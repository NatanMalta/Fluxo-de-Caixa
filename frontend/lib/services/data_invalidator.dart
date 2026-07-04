import 'package:flutter/foundation.dart';

/// Barramento de invalidação por tipo de dado (ver ADR 0006).
///
/// Quatro `ValueNotifier<int>` moram nesta classe estática. As telas
/// escutam os notifiers relevantes via `ListenableBuilder` envolvendo o
/// seu `FutureBuilder`; mutações chamam `value++` no notifier apropriado
/// **depois** do `await` da chamada HTTP ter sucesso.
///
/// Tabela de bumps por mutação (ver ADR 0006):
///
/// | Mutação                                       | Counters                    |
/// |-----------------------------------------------|-----------------------------|
/// | Conta criar/editar/excluir (em Config)        | `contas`, `balanco`         |
/// | Categoria criar/editar/excluir (em Config)    | `categorias`, `balanco`,    |
/// |                                               | `lancamentos`               |
/// | Lançamento criar/editar/excluir (em Lançar)   | `lancamentos`, `balanco`    |
///
/// Esquecer um bump deixa silenciosamente uma tela stale — é o ônus real
/// deste modelo. A checagem manual está documentada no `AGENTS.md`.
class DataInvalidator {
  DataInvalidator._();

  /// Bump quando Contas são criadas/alteradas/excluídas.
  /// Ouvido por `DashboardScreen` (saldos, lista) e `LancarScreen`
  /// (dropdown de contas no formulário).
  static final ValueNotifier<int> contas = ValueNotifier<int>(0);

  /// Bump quando Categorias são criadas/alteradas/excluídas.
  /// Ouvido por `LancarScreen` (dropdowns do formulário comum).
  /// Também bumpa `lancamentos` porque o nome da categoria entra
  /// joinado na resposta de `GET /api/Lancamentos`.
  static final ValueNotifier<int> categorias = ValueNotifier<int>(0);

  /// Bump quando Lançamentos são criados/alterados/excluídos.
  /// Ouvido por `DashboardScreen` (últimos lançamentos) e
  /// `LancarScreen` (lista "Lançamentos de hoje").
  static final ValueNotifier<int> lancamentos = ValueNotifier<int>(0);

  /// Bump quando qualquer coisa que afete o Balanço muda:
  /// Contas (saldos), Categorias (quebra), Lançamentos (totais).
  /// Ouvido apenas por `BalancoScreen`.
  static final ValueNotifier<int> balanco = ValueNotifier<int>(0);
}
