using FluxoCaixa.Api.Models;

namespace FluxoCaixa.Api.Dtos;

public record CategoriaCreateDto(string Nome, TipoCategoria Tipo);

public record CategoriaUpdateDto(string Nome, TipoCategoria Tipo, bool Ativo);

public record CategoriaResponseDto(
    int Id,
    string Nome,
    TipoCategoria Tipo,
    bool Ativo,
    DateTime CriadoEm,
    DateTime AtualizadoEm);
