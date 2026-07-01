/// Tipos de período pré-definidos para o Balanço.
enum PeriodoBalanco {
  /// Apenas o dia de [referencia].
  hoje,

  /// Do dia 1 do mês de [referencia] até [referencia].
  esteMes,

  /// Do dia 1 de janeiro do ano de [referencia] até [referencia].
  esteAno,

  /// Intervalo livre, definido por [customInicio] e [customFim].
  /// Se ausentes, cai de volta para [PeriodoBalanco.hoje].
  customizado,
}

/// Resultado de [calcularPeriodo] — um par (inicio, fim) com granularidade de dia.
///
/// Ambos os campos são truncados para a data (hora 00:00:00). O backend
/// interpreta [fim] como inclusivo (`fim.Date.AddDays(1)` na query).
class PeriodoCalculado {
  final DateTime inicio;
  final DateTime fim;
  const PeriodoCalculado(this.inicio, this.fim);
}

/// Calcula o par (inicio, fim) para o tipo de período informado.
///
/// [referencia] é a data a partir da qual períodos pré-definidos
/// (hoje / este mês / este ano) são derivados. Aceitar essa data como
/// parâmetro torna a função determinística e testável.
PeriodoCalculado calcularPeriodo(
  PeriodoBalanco tipo, {
  required DateTime referencia,
  DateTime? customInicio,
  DateTime? customFim,
}) {
  final ref = DateTime(referencia.year, referencia.month, referencia.day);

  switch (tipo) {
    case PeriodoBalanco.hoje:
      return PeriodoCalculado(ref, ref);

    case PeriodoBalanco.esteMes:
      final inicio = DateTime(ref.year, ref.month, 1);
      return PeriodoCalculado(inicio, ref);

    case PeriodoBalanco.esteAno:
      final inicio = DateTime(ref.year, 1, 1);
      return PeriodoCalculado(inicio, ref);

    case PeriodoBalanco.customizado:
      if (customInicio == null || customFim == null) {
        return PeriodoCalculado(ref, ref);
      }
      final i = DateTime(
        customInicio.year,
        customInicio.month,
        customInicio.day,
      );
      final f = DateTime(customFim.year, customFim.month, customFim.day);
      // Garante ordem não-decrescente — a UI pode deixar o usuário inverter.
      if (i.isAfter(f)) return PeriodoCalculado(f, i);
      return PeriodoCalculado(i, f);
  }
}
