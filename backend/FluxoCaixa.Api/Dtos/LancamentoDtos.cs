using FluxoCaixa.Api.Models;

namespace FluxoCaixa.Api.Dtos;

public record LancamentoCreateDto(
    DateTime Data,
    TipoLancamento Tipo,
    decimal Valor,
    int? ContaId,
    SentidoLancamento? Sentido,
    int? CategoriaId,
    string? Descricao,
    int? ContaOrigemId,
    int? ContaDestinoId);

public record LancamentoUpdateDto(
    DateTime Data,
    decimal Valor,
    int? ContaId,
    SentidoLancamento? Sentido,
    int? CategoriaId,
    string? Descricao,
    int? ContaOrigemId,
    int? ContaDestinoId);

public record LancamentoResponseDto(
    int Id,
    DateTime Data,
    TipoLancamento Tipo,
    decimal Valor,
    int? ContaId,
    string? ContaNome,
    SentidoLancamento? Sentido,
    int? CategoriaId,
    string? CategoriaNome,
    string? Descricao,
    int? ContaOrigemId,
    string? ContaOrigemNome,
    int? ContaDestinoId,
    string? ContaDestinoNome,
    DateTime CriadoEm,
    DateTime AtualizadoEm);
