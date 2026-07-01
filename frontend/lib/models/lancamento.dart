class Lancamento {
  final int id;
  final DateTime data;
  final String tipo; // 'comum' | 'ajuste' | 'transferencia'
  final double valor;

  final int? contaId;
  final String? contaNome;
  final String? sentido; // 'entrada' | 'saida'

  final int? categoriaId;
  final String? categoriaNome;
  final String? descricao;

  final int? contaOrigemId;
  final String? contaOrigemNome;
  final int? contaDestinoId;
  final String? contaDestinoNome;

  final DateTime criadoEm;
  final DateTime atualizadoEm;

  Lancamento({
    required this.id,
    required this.data,
    required this.tipo,
    required this.valor,
    this.contaId,
    this.contaNome,
    this.sentido,
    this.categoriaId,
    this.categoriaNome,
    this.descricao,
    this.contaOrigemId,
    this.contaOrigemNome,
    this.contaDestinoId,
    this.contaDestinoNome,
    required this.criadoEm,
    required this.atualizadoEm,
  });

  factory Lancamento.fromJson(Map<String, dynamic> j) => Lancamento(
    id: j['id'] as int,
    data: DateTime.parse(j['data'] as String),
    tipo: j['tipo'] as String,
    valor: (j['valor'] as num).toDouble(),
    contaId: j['contaId'] as int?,
    contaNome: j['contaNome'] as String?,
    sentido: j['sentido'] as String?,
    categoriaId: j['categoriaId'] as int?,
    categoriaNome: j['categoriaNome'] as String?,
    descricao: j['descricao'] as String?,
    contaOrigemId: j['contaOrigemId'] as int?,
    contaOrigemNome: j['contaOrigemNome'] as String?,
    contaDestinoId: j['contaDestinoId'] as int?,
    contaDestinoNome: j['contaDestinoNome'] as String?,
    criadoEm: DateTime.parse(j['criadoEm'] as String),
    atualizadoEm: DateTime.parse(j['atualizadoEm'] as String),
  );

  bool get isComum => tipo == 'comum';
  bool get isAjuste => tipo == 'ajuste';
  bool get isTransferencia => tipo == 'transferencia';
}
