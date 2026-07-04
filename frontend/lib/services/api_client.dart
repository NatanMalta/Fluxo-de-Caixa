import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

import '../models/conta.dart';
import '../models/categoria.dart';
import '../models/lancamento.dart';
import '../models/balanco.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// Cliente HTTP para o backend ASP.NET.
///
/// O endereço base é carregado de `assets/config.json` (chave `apiBaseUrl`)
/// durante o [init] no startup. O arquivo real é ignorado pelo git —
/// copie `assets/config.example.json` para `assets/config.json` e edite
/// com o IP do servidor na LAN. Em runtime, o setter `baseUrl`
/// (ver `ApiBaseUrlSetting` no main.dart) sobrescreve o config.
///
/// **Auth (ADR 0007)**: o JWT retornado por `POST /api/auth/login` é
/// mantido em memória em [_token] e adicionado a todo request por
/// [_authHeaders]. Ao receber 401, o token é limpo e a `PinLockScreen`
/// no nível do `MaterialApp` re-exibe o prompt de PIN. O token
/// **nunca** é persistido (ver ADR 0007 — limitação aceita: web
/// descarta o token ao fechar a aba).
class ApiClient {
  /// URL usada quando nem o config nem o override estão definidos.
  /// Útil para testes locais sem `config.json`.
  static const String _defaultBaseUrl = 'http://localhost:5000';

  /// Carregado de `assets/config.json` pelo [init].
  static String? _loadedBaseUrl;

  /// Sobrescrito em runtime via `ApiClient.baseUrl = ...`.
  static String? _overrideBaseUrl;

  /// URL efetiva: override em runtime > config.json > default.
  static String get baseUrl =>
      _overrideBaseUrl ?? _loadedBaseUrl ?? _defaultBaseUrl;

  /// Permite trocar a URL em runtime (ex.: tela de configurações futura).
  /// Passe `null` para voltar a usar config.json.
  static set baseUrl(String? url) => _overrideBaseUrl = url;

  /// JWT em memória. `null` antes do login / após logout / após 401.
  /// Nunca escrito em disco (ADR 0007).
  static String? _token;

  /// Notifier disparado quando o token muda (login ok, logout, 401).
  /// O `MaterialApp` raiz escuta isto para re-exibir a `PinLockScreen`
  /// quando `token == null`. Manter em `ValueListenable` (não `Stream`)
  /// porque o consumidor do `MaterialApp` usa `ValueListenableBuilder`.
  static final ValueNotifier<String?> tokenNotifier = ValueNotifier<String?>(null);

  static String? get token => _token;
  static bool get isAuthenticated => _token != null;

  /// Define o token em memória. Use apenas em [AuthService.login] e
  /// em [logout]. Dispara [tokenNotifier] para o `MaterialApp`.
  static void setToken(String? newToken) {
    _token = newToken;
    tokenNotifier.value = newToken;
  }

  /// Limpa o token local. Chamado no 401 e em logout explícito.
  static void clearToken() => setToken(null);

  /// Carrega `assets/config.json`. Deve ser chamado uma vez no startup,
  /// antes de qualquer chamada HTTP (tipicamente no `main()`).
  /// Falha silenciosa: se o arquivo não existir, estiver inválido,
  /// ou o `apiBaseUrl` não tiver scheme http(s), o app segue com
  /// [_defaultBaseUrl].
  static Future<void> init() async {
    try {
      final raw = await rootBundle.loadString('assets/config.json');
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final url = json['apiBaseUrl'];
      if (url is String &&
          url.isNotEmpty &&
          (url.startsWith('http://') || url.startsWith('https://'))) {
        _loadedBaseUrl = url;
      }
      // Silencia JSON inválido, valor ausente, ou scheme não suportado.
    } catch (_) {
      // Mantém _loadedBaseUrl = null; cai no _defaultBaseUrl.
    }
  }

  static final _client = http.Client();

  static Map<String, String> get _jsonHeaders => {
    'Content-Type': 'application/json; charset=utf-8',
    'Accept': 'application/json',
  };

  /// Mesmos headers JSON, mais `Authorization: Bearer <jwt>` quando há
  /// token. O `POST /api/auth/login` é chamado sem token e usa
  /// [_jsonHeaders] direto.
  static Map<String, String> get _authHeaders => {
    ..._jsonHeaders,
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  static Uri _uri(String path) => Uri.parse('$baseUrl$path');

  // -----------------------------------------------------------------
  // Auth (ADR 0007)
  // -----------------------------------------------------------------

  /// `POST /api/auth/login` com `{ "pin": "..." }`. Em sucesso (200),
  /// armazena o JWT em memória via [setToken] e retorna o `expiresAt`.
  ///
  /// Erros:
  /// - 401 → [ApiException] com `statusCode: 401` (PIN errado ou
  ///   formato inválido). Caller exibe mensagem ao usuário.
  /// - 429 → rate limit estourado. Mensagem genérica do backend.
  /// - outros → [ApiException] com o statusCode.
  static Future<DateTime> login(String pin) async {
    final res = await _client.post(
      _uri('/api/auth/login'),
      headers: _jsonHeaders,
      body: jsonEncode({'pin': pin}),
    );
    _check(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final token = body['token'] as String;
    final expiresAt = DateTime.parse(body['expiresAt'] as String);
    setToken(token);
    return expiresAt;
  }

  // -----------------------------------------------------------------
  // Contas
  // -----------------------------------------------------------------
  static Future<List<Conta>> listarContas({
    bool incluirInativas = false,
  }) async {
    final qs = incluirInativas ? '?incluirInativas=true' : '';
    final res = await _client.get(_uri('/api/Contas$qs'), headers: _authHeaders);
    _check(res);
    final list = jsonDecode(res.body) as List<dynamic>;
    return list.map((j) => Conta.fromJson(j as Map<String, dynamic>)).toList();
  }

  static Future<Conta> criarConta({
    required String nome,
    required String tipo,
    required double saldoInicial,
  }) async {
    final res = await _client.post(
      _uri('/api/Contas'),
      headers: _authHeaders,
      body: jsonEncode({
        'nome': nome,
        'tipo': tipo,
        'saldoInicial': saldoInicial,
      }),
    );
    _check(res);
    return Conta.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  static Future<Conta> atualizarConta(Conta c) async {
    final res = await _client.put(
      _uri('/api/Contas/${c.id}'),
      headers: _authHeaders,
      body: jsonEncode({
        'nome': c.nome,
        'tipo': c.tipo,
        'saldoInicial': c.saldoInicial,
        'ativo': c.ativo,
      }),
    );
    _check(res);
    return Conta.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  static Future<void> excluirConta(int id) async {
    final res = await _client.delete(_uri('/api/Contas/$id'), headers: _authHeaders);
    _check(res);
  }

  // -----------------------------------------------------------------
  // Categorias
  // -----------------------------------------------------------------
  static Future<List<Categoria>> listarCategorias({
    String? tipo,
    bool incluirInativas = false,
  }) async {
    final params = <String, String>{};
    if (tipo != null) params['tipo'] = tipo;
    if (incluirInativas) params['incluirInativas'] = 'true';
    final qs = params.isEmpty ? '' : '?${Uri(queryParameters: params).query}';
    final res = await _client.get(_uri('/api/Categorias$qs'), headers: _authHeaders);
    _check(res);
    final list = jsonDecode(res.body) as List<dynamic>;
    return list
        .map((j) => Categoria.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  static Future<Categoria> criarCategoria({
    required String nome,
    required String tipo,
  }) async {
    final res = await _client.post(
      _uri('/api/Categorias'),
      headers: _authHeaders,
      body: jsonEncode({'nome': nome, 'tipo': tipo}),
    );
    _check(res);
    return Categoria.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  static Future<Categoria> atualizarCategoria(Categoria c) async {
    final res = await _client.put(
      _uri('/api/Categorias/${c.id}'),
      headers: _authHeaders,
      body: jsonEncode({'nome': c.nome, 'tipo': c.tipo, 'ativo': c.ativo}),
    );
    _check(res);
    return Categoria.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  static Future<void> excluirCategoria(int id) async {
    final res = await _client.delete(_uri('/api/Categorias/$id'), headers: _authHeaders);
    _check(res);
  }

  // -----------------------------------------------------------------
  // Lançamentos
  // -----------------------------------------------------------------
  static Future<List<Lancamento>> listarLancamentos({
    DateTime? inicio,
    DateTime? fim,
    String? tipo,
    int? contaId,
  }) async {
    final params = <String, String>{};
    if (inicio != null) params['inicio'] = _isoDate(inicio);
    if (fim != null) params['fim'] = _isoDate(fim);
    if (tipo != null) params['tipo'] = tipo;
    if (contaId != null) params['contaId'] = contaId.toString();
    final qs = params.isEmpty ? '' : '?${Uri(queryParameters: params).query}';
    final res = await _client.get(_uri('/api/Lancamentos$qs'), headers: _authHeaders);
    _check(res);
    final list = jsonDecode(res.body) as List<dynamic>;
    return list
        .map((j) => Lancamento.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  static Future<Lancamento> criarLancamento(Map<String, dynamic> dto) async {
    final res = await _client.post(
      _uri('/api/Lancamentos'),
      headers: _authHeaders,
      body: jsonEncode(dto),
    );
    _check(res);
    return Lancamento.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// Atualiza um Lançamento existente.
  /// O `dto` deve ter o mesmo formato de [criarLancamento] (camelCase),
  /// mas o campo `tipo` é ignorado — o tipo do Lançamento é imutável após
  /// a criação (ver `LancamentoUpdateDto` no backend).
  static Future<Lancamento> atualizarLancamento(
    int id,
    Map<String, dynamic> dto,
  ) async {
    // Remove `tipo` se vier — PUT não aceita esse campo.
    final semTipo = Map<String, dynamic>.from(dto)..remove('tipo');
    final res = await _client.put(
      _uri('/api/Lancamentos/$id'),
      headers: _authHeaders,
      body: jsonEncode(semTipo),
    );
    _check(res);
    return Lancamento.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  static Future<void> excluirLancamento(int id) async {
    final res = await _client.delete(_uri('/api/Lancamentos/$id'), headers: _authHeaders);
    _check(res);
  }

  // -----------------------------------------------------------------
  // Balanço
  // -----------------------------------------------------------------
  static Future<Balanco> obterBalanco({
    required DateTime inicio,
    required DateTime fim,
  }) async {
    final qs = Uri(
      queryParameters: {'inicio': _isoDate(inicio), 'fim': _isoDate(fim)},
    ).query;
    final res = await _client.get(_uri('/api/Balanco?$qs'), headers: _authHeaders);
    _check(res);
    return Balanco.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  // -----------------------------------------------------------------
  // Helpers
  // -----------------------------------------------------------------
  static void _check(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) return;

    // 401 = token inválido/expirado. Limpa o token local para que a
    // PinLockScreen volte a aparecer. O 401 do /api/auth/login (PIN
    // errado) é tratado pelo caller — não limpamos o token nesse
    // caso porque ele já é null.
    if (res.statusCode == 401 && res.request?.url.path != '/api/auth/login') {
      clearToken();
    }

    String message;
    try {
      message =
          (jsonDecode(res.body) as Map<String, dynamic>)['title']?.toString() ??
          res.body;
    } catch (_) {
      message = res.body;
    }
    throw ApiException(res.statusCode, message);
  }

  static String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
