class Conta {
  final int id;
  final String nome;
  final String tipo; // 'banco' | 'especie'
  final double saldoInicial;
  final bool ativo;
  final DateTime criadoEm;
  final DateTime atualizadoEm;
  final double saldoAtual; // derivado, vem do backend

  Conta({
    required this.id,
    required this.nome,
    required this.tipo,
    required this.saldoInicial,
    required this.ativo,
    required this.criadoEm,
    required this.atualizadoEm,
    required this.saldoAtual,
  });

  factory Conta.fromJson(Map<String, dynamic> j) => Conta(
    id: j['id'] as int,
    nome: j['nome'] as String,
    tipo: j['tipo'] as String,
    saldoInicial: (j['saldoInicial'] as num).toDouble(),
    ativo: j['ativo'] as bool,
    criadoEm: DateTime.parse(j['criadoEm'] as String),
    atualizadoEm: DateTime.parse(j['atualizadoEm'] as String),
    saldoAtual: (j['saldoAtual'] as num).toDouble(),
  );

  bool get isEspecie => tipo == 'especie';
  bool get isBanco => tipo == 'banco';
}
