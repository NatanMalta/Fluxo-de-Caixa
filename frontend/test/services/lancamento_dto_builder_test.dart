import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/services/lancamento_dto_builder.dart';

void main() {
  group('buildLancamentoComumDto', () {
    test('monta payload minimo para entrada', () {
      final dto = buildLancamentoComumDto(
        data: DateTime(2026, 3, 15),
        valor: 480.50,
        contaId: 1,
        categoriaId: 7,
        sentido: 'entrada',
      );
      expect(dto['tipo'], 'comum');
      expect(dto['data'], '2026-03-15');
      expect(dto['valor'], 480.50);
      expect(dto['contaId'], 1);
      expect(dto['categoriaId'], 7);
      expect(dto['sentido'], 'entrada');
      // Campos que NAO devem ir para um comum:
      expect(dto.containsKey('descricao'), isFalse);
      expect(dto.containsKey('contaOrigemId'), isFalse);
      expect(dto.containsKey('contaDestinoId'), isFalse);
    });

    test('monta payload para saida', () {
      final dto = buildLancamentoComumDto(
        data: DateTime(2026, 3, 15),
        valor: 150,
        contaId: 2,
        categoriaId: 9,
        sentido: 'saida',
      );
      expect(dto['sentido'], 'saida');
    });

    test('valor eh enviado como double, nao como string', () {
      final dto = buildLancamentoComumDto(
        data: DateTime(2026, 3, 15),
        valor: 0.01,
        contaId: 1,
        categoriaId: 1,
        sentido: 'entrada',
      );
      expect(dto['valor'], isA<double>());
      expect(dto['valor'], 0.01);
    });
  });

  group('buildLancamentoAjusteDto', () {
    test('monta payload com descricao e sem categoria', () {
      final dto = buildLancamentoAjusteDto(
        data: DateTime(2026, 3, 15),
        valor: 12.50,
        contaId: 1,
        sentido: 'saida',
        descricao: 'Tarifa banco',
      );
      expect(dto['tipo'], 'ajuste');
      expect(dto['data'], '2026-03-15');
      expect(dto['valor'], 12.50);
      expect(dto['contaId'], 1);
      expect(dto['sentido'], 'saida');
      expect(dto['descricao'], 'Tarifa banco');
      expect(dto.containsKey('categoriaId'), isFalse);
      expect(dto.containsKey('contaOrigemId'), isFalse);
      expect(dto.containsKey('contaDestinoId'), isFalse);
    });

    test('descricao com espacos nas pontas eh trimada', () {
      final dto = buildLancamentoAjusteDto(
        data: DateTime(2026, 3, 15),
        valor: 5,
        contaId: 1,
        sentido: 'entrada',
        descricao: '   rendimento   ',
      );
      expect(dto['descricao'], 'rendimento');
    });
  });

  group('buildLancamentoTransferenciaDto', () {
    test('monta payload com origem e destino', () {
      final dto = buildLancamentoTransferenciaDto(
        data: DateTime(2026, 3, 15),
        valor: 200,
        contaOrigemId: 1,
        contaDestinoId: 2,
      );
      expect(dto['tipo'], 'transferencia');
      expect(dto['data'], '2026-03-15');
      expect(dto['valor'], 200);
      expect(dto['contaOrigemId'], 1);
      expect(dto['contaDestinoId'], 2);
      // Campos que NAO devem ir para uma transferencia:
      expect(dto.containsKey('contaId'), isFalse);
      expect(dto.containsKey('categoriaId'), isFalse);
      expect(dto.containsKey('sentido'), isFalse);
      expect(dto.containsKey('descricao'), isFalse);
    });
  });
}
