using FluxoCaixa.Api.Models;

namespace FluxoCaixa.Api.Dtos;

public record ContaCreateDto(string Nome, TipoConta Tipo, decimal SaldoInicial);

public record ContaUpdateDto(string Nome, TipoConta Tipo, decimal SaldoInicial, bool Ativo);

public record ContaResponseDto(
    int Id,
    string Nome,
    TipoConta Tipo,
    decimal SaldoInicial,
    bool Ativo,
    DateTime CriadoEm,
    DateTime AtualizadoEm,
    decimal SaldoAtual);
