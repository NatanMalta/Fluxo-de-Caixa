import 'dart:convert';
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
/// O endereço base pode ser configurado em tempo de execução.
/// Padrão: http://localhost:5000 (mesma máquina, web).
/// Para Android no emulador: http://10.0.2.2:5000
/// Para Android via Wi-Fi:  http://<IP-do-PC>:5000
class ApiClient {
  static String baseUrl = 'http://localhost:5000';

  static final _client = http.Client();

  static Map<String, String> get _jsonHeaders => {
    'Content-Type': 'application/json; charset=utf-8',
    'Accept': 'application/json',
  };

  static Uri _uri(String path) => Uri.parse('$baseUrl$path');

  // -----------------------------------------------------------------
  // Contas
  // -----------------------------------------------------------------
  static Future<List<Conta>> listarContas({
    bool incluirInativas = false,
  }) async {
    final qs = incluirInativas ? '?incluirInativas=true' : '';
    final res = await _client.get(_uri('/api/Contas$qs'));
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
      headers: _jsonHeaders,
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
      headers: _jsonHeaders,
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
    final res = await _client.delete(_uri('/api/Contas/$id'));
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
    final res = await _client.get(_uri('/api/Categorias$qs'));
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
      headers: _jsonHeaders,
      body: jsonEncode({'nome': nome, 'tipo': tipo}),
    );
    _check(res);
    return Categoria.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  static Future<Categoria> atualizarCategoria(Categoria c) async {
    final res = await _client.put(
      _uri('/api/Categorias/${c.id}'),
      headers: _jsonHeaders,
      body: jsonEncode({'nome': c.nome, 'tipo': c.tipo, 'ativo': c.ativo}),
    );
    _check(res);
    return Categoria.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  static Future<void> excluirCategoria(int id) async {
    final res = await _client.delete(_uri('/api/Categorias/$id'));
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
    final res = await _client.get(_uri('/api/Lancamentos$qs'));
    _check(res);
    final list = jsonDecode(res.body) as List<dynamic>;
    return list
        .map((j) => Lancamento.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  static Future<Lancamento> criarLancamento(Map<String, dynamic> dto) async {
    final res = await _client.post(
      _uri('/api/Lancamentos'),
      headers: _jsonHeaders,
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
      headers: _jsonHeaders,
      body: jsonEncode(semTipo),
    );
    _check(res);
    return Lancamento.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  static Future<void> excluirLancamento(int id) async {
    final res = await _client.delete(_uri('/api/Lancamentos/$id'));
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
    final res = await _client.get(_uri('/api/Balanco?$qs'));
    _check(res);
    return Balanco.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  // -----------------------------------------------------------------
  // Helpers
  // -----------------------------------------------------------------
  static void _check(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) return;
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
