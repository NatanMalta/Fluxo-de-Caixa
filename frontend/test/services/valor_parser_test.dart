import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/services/valor_parser.dart';

void main() {
  group('parseValor', () {
    test('aceita 1234.56', () {
      expect(parseValor('1234.56'), 1234.56);
    });

    test('aceita 1234,56 (BR)', () {
      expect(parseValor('1234,56'), 1234.56);
    });

    test('aceita R\$ 1.234,56 com prefixo e separador de milhar', () {
      expect(parseValor('R\$ 1.234,56'), 1234.56);
    });

    test('aceita inteiro sem casas decimais', () {
      expect(parseValor('100'), 100.0);
    });

    test('aceita zero', () {
      expect(parseValor('0'), 0.0);
    });

    test('retorna null para string vazia', () {
      expect(parseValor(''), isNull);
    });

    test('retorna null para texto nao-numerico', () {
      expect(parseValor('abc'), isNull);
    });

    test('retorna null para valor negativo', () {
      expect(parseValor('-50'), isNull);
    });

    test('valor 0.00 retorna 0.0 (backend rejeita, mas parser aceita)', () {
      expect(parseValor('0.00'), 0.0);
    });

    test('espaços nas pontas são ignorados', () {
      expect(parseValor('  42.5  '), 42.5);
    });
  });
}
