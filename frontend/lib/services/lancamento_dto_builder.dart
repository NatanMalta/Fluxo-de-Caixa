// Constrói o payload JSON (camelCase) que o backend espera para cada
// subtipo de Lançamento. As chaves batem com `LancamentoCreateDto`
// do backend (ver `backend/FluxoCaixa.Api/Dtos/LancamentoDtos.cs`).
//
// O backend tem triggers que abortam o insert/update se um Lançamento
// trouxer campos que não pertencem ao seu `tipo` — por isso cada builder
// abaixo envia **apenas** os campos relevantes para o subtipo.

String _isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Lançamento Comum: entrada/saída de uma Conta classificada por Categoria.
Map<String, dynamic> buildLancamentoComumDto({
  required DateTime data,
  required double valor,
  required int contaId,
  required int categoriaId,
  required String sentido, // 'entrada' | 'saida'
}) {
  return {
    'tipo': 'comum',
    'data': _isoDate(data),
    'valor': valor,
    'contaId': contaId,
    'categoriaId': categoriaId,
    'sentido': sentido,
  };
}

/// Ajuste: correção de saldo de uma Conta, com descrição livre.
Map<String, dynamic> buildLancamentoAjusteDto({
  required DateTime data,
  required double valor,
  required int contaId,
  required String sentido, // 'entrada' | 'saida'
  required String descricao,
}) {
  return {
    'tipo': 'ajuste',
    'data': _isoDate(data),
    'valor': valor,
    'contaId': contaId,
    'sentido': sentido,
    'descricao': descricao.trim(),
  };
}

/// Transferência: movimentação de uma Conta de origem para uma Conta de destino.
Map<String, dynamic> buildLancamentoTransferenciaDto({
  required DateTime data,
  required double valor,
  required int contaOrigemId,
  required int contaDestinoId,
}) {
  return {
    'tipo': 'transferencia',
    'data': _isoDate(data),
    'valor': valor,
    'contaOrigemId': contaOrigemId,
    'contaDestinoId': contaDestinoId,
  };
}
