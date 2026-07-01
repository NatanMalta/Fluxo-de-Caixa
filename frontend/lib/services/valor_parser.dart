/// Faz o parse de uma string de valor monetário para `double`.
///
/// Aceita:
///   - `1234.56` (en-US)
///   - `1234,56` (pt-BR)
///   - `R\$ 1.234,56` (com prefixo de moeda e separador de milhar pt-BR)
///   - espaços nas pontas
///
/// Retorna `null` para entrada vazia, não-numérica, ou negativa.
/// Zero é aceito (o backend vai rejeitar depois com "Valor deve ser positivo").
double? parseValor(String entrada) {
  var s = entrada.trim();
  if (s.isEmpty) return null;

  // Remove prefixo de moeda "R$" (com ou sem espaço).
  s = s.replaceAll('R\$', '').trim();

  // Heurística pt-BR: se tem vírgula, é separador decimal.
  // Se tem ponto E vírgula, ponto é separador de milhar.
  if (s.contains(',')) {
    s = s.replaceAll('.', '').replaceAll(',', '.');
  }

  final v = double.tryParse(s);
  if (v == null) return null;
  if (v < 0) return null;
  return v;
}
