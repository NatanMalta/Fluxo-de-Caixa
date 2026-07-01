class ContaSaldo {
  final int contaId;
  final String nome;
  final double saldo;
  ContaSaldo({required this.contaId, required this.nome, required this.saldo});

  factory ContaSaldo.fromJson(Map<String, dynamic> j) => ContaSaldo(
    contaId: j['contaId'] as int,
    nome: j['nome'] as String,
    saldo: (j['saldo'] as num).toDouble(),
  );
}

class CategoriaTotal {
  final int categoriaId;
  final String nome;
  final double total;
  CategoriaTotal({
    required this.categoriaId,
    required this.nome,
    required this.total,
  });

  factory CategoriaTotal.fromJson(Map<String, dynamic> j) => CategoriaTotal(
    categoriaId: j['categoriaId'] as int,
    nome: j['nome'] as String,
    total: (j['total'] as num).toDouble(),
  );
}

class Balanco {
  final DateTime inicio;
  final DateTime fim;
  final double totalEntradas;
  final double totalSaidas;
  final double resultado;
  final List<ContaSaldo> saldosPorConta;
  final List<CategoriaTotal> entradasPorCategoria;
  final List<CategoriaTotal> saidasPorCategoria;

  Balanco({
    required this.inicio,
    required this.fim,
    required this.totalEntradas,
    required this.totalSaidas,
    required this.resultado,
    required this.saldosPorConta,
    required this.entradasPorCategoria,
    required this.saidasPorCategoria,
  });

  factory Balanco.fromJson(Map<String, dynamic> j) => Balanco(
    inicio: DateTime.parse(j['inicio'] as String),
    fim: DateTime.parse(j['fim'] as String),
    totalEntradas: (j['totalEntradas'] as num).toDouble(),
    totalSaidas: (j['totalSaidas'] as num).toDouble(),
    resultado: (j['resultado'] as num).toDouble(),
    saldosPorConta: (j['saldosPorConta'] as List<dynamic>)
        .map((e) => ContaSaldo.fromJson(e as Map<String, dynamic>))
        .toList(),
    entradasPorCategoria: (j['entradasPorCategoria'] as List<dynamic>)
        .map((e) => CategoriaTotal.fromJson(e as Map<String, dynamic>))
        .toList(),
    saidasPorCategoria: (j['saidasPorCategoria'] as List<dynamic>)
        .map((e) => CategoriaTotal.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}
