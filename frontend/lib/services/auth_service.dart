import 'api_client.dart';

/// Camada fina sobre [ApiClient.login] que traduz os erros HTTP em
/// mensagens amigáveis para a `PinLockScreen`.
///
/// Mantida como classe estática (mesmo padrão do `ApiClient`) porque
/// o app é single-user e não há estado de instância.
class AuthService {
  AuthService._();

  /// Tenta fazer login. Retorna `null` em sucesso; em falha, retorna
  /// a mensagem a exibir no campo de erro da tela de PIN.
  ///
  /// Status codes:
  /// - 401: PIN errado ou formato inválido
  /// - 429: rate limit estourado (5 req/min/IP)
  /// - outros: erro de transporte / 5xx
  static Future<String?> login(String pin) async {
    try {
      await ApiClient.login(pin);
      return null;
    } on ApiException catch (e) {
      switch (e.statusCode) {
        case 401:
          return 'PIN incorreto.';
        case 429:
          return 'Muitas tentativas. Aguarde 1 minuto e tente de novo.';
        default:
          return 'Erro ao entrar (${e.statusCode}). Tente de novo.';
      }
    } catch (e) {
      // Erro de rede (servidor fora, DNS, etc.). O backend pode não
      // estar rodando ainda — o usuário geralmente sabe o que fazer.
      return 'Não foi possível conectar ao servidor.';
    }
  }
}
