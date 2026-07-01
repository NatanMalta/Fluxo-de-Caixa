class Categoria {
  final int id;
  final String nome;
  final String tipo; // 'entrada' | 'saida'
  final bool ativo;

  Categoria({
    required this.id,
    required this.nome,
    required this.tipo,
    required this.ativo,
  });

  factory Categoria.fromJson(Map<String, dynamic> j) => Categoria(
    id: j['id'] as int,
    nome: j['nome'] as String,
    tipo: j['tipo'] as String,
    ativo: j['ativo'] as bool,
  );

  bool get isEntrada => tipo == 'entrada';
  bool get isSaida => tipo == 'saida';
}
