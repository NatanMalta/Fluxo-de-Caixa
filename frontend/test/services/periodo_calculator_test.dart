import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/services/periodo_calculator.dart';

void main() {
  // Fix a reference date so tests are deterministic regardless of when they run.
  // 15 de março de 2026 (domingo), 10:00 local.
  final ref = DateTime(2026, 3, 15, 10, 0, 0);

  group('calcularPeriodo', () {
    test('hoje retorna inicio == fim == referencia (apenas a data)', () {
      final p = calcularPeriodo(PeriodoBalanco.hoje, referencia: ref);
      expect(p.inicio, DateTime(2026, 3, 15));
      expect(p.fim, DateTime(2026, 3, 15));
    });

    test('esteMes retorna do dia 1 ate a data de referencia', () {
      final p = calcularPeriodo(PeriodoBalanco.esteMes, referencia: ref);
      expect(p.inicio, DateTime(2026, 3, 1));
      expect(p.fim, DateTime(2026, 3, 15));
    });

    test('esteMes no dia 1 do mes retorna dia 1 nos dois extremos', () {
      final p = calcularPeriodo(
        PeriodoBalanco.esteMes,
        referencia: DateTime(2026, 1, 1),
      );
      expect(p.inicio, DateTime(2026, 1, 1));
      expect(p.fim, DateTime(2026, 1, 1));
    });

    test('esteAno retorna do dia 1 de janeiro ate a data de referencia', () {
      final p = calcularPeriodo(PeriodoBalanco.esteAno, referencia: ref);
      expect(p.inicio, DateTime(2026, 1, 1));
      expect(p.fim, DateTime(2026, 3, 15));
    });

    test(
      'customizado usa as datas fornecidas (apenas a data, ignora hora)',
      () {
        final inicio = DateTime(2026, 2, 1, 23, 30);
        final fim = DateTime(2026, 2, 28, 5, 45);
        final p = calcularPeriodo(
          PeriodoBalanco.customizado,
          referencia: ref,
          customInicio: inicio,
          customFim: fim,
        );
        expect(p.inicio, DateTime(2026, 2, 1));
        expect(p.fim, DateTime(2026, 2, 28));
      },
    );

    test('customizado sem datas cai de volta para hoje', () {
      final p = calcularPeriodo(PeriodoBalanco.customizado, referencia: ref);
      expect(p.inicio, DateTime(2026, 3, 15));
      expect(p.fim, DateTime(2026, 3, 15));
    });

    test(
      'customizado com inicio > fim troca para garantir ordem nao-decrescente',
      () {
        final p = calcularPeriodo(
          PeriodoBalanco.customizado,
          referencia: ref,
          customInicio: DateTime(2026, 5, 10),
          customFim: DateTime(2026, 5, 1),
        );
        expect(p.inicio, DateTime(2026, 5, 1));
        expect(p.fim, DateTime(2026, 5, 10));
      },
    );
  });
}
