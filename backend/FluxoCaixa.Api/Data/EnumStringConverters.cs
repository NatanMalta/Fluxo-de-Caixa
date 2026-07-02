using FluxoCaixa.Api.Models;
using Microsoft.EntityFrameworkCore.Storage.ValueConversion;

namespace FluxoCaixa.Api.Data;

/// <summary>
/// Conversores de enum <-> string para o EF Core.
///
/// Por que isto existe:
/// O schema SQLite define CHECK constraints com os valores canônicos minúsculos
/// do domínio (`'banco'`, `'especie'`, `'entrada'`, `'saida'`, etc. — ver
/// `db/schema.sql` e `CONTEXT.md`). O `HasConversion<string>()` padrão do EF
/// grava o nome C# do enum (`"Banco"`, `"Especie"`, ...), o que viola a
/// CHECK constraint. Estes conversores gravam a forma canônica minúscula.
///
/// A leitura é case-insensitive, então funciona mesmo que o banco (ou um
/// script de migração) contenha variantes de capitalização.
/// </summary>
public static class EnumStringConverters
{
    public static readonly ValueConverter<TipoConta, string> Conta =
        new(v => v.ToString().ToLowerInvariant(),
            v => (TipoConta)Enum.Parse(typeof(TipoConta), v, ignoreCase: true));

    public static readonly ValueConverter<TipoCategoria, string> Categoria =
        new(v => v.ToString().ToLowerInvariant(),
            v => (TipoCategoria)Enum.Parse(typeof(TipoCategoria), v, ignoreCase: true));

    public static readonly ValueConverter<TipoLancamento, string> Lancamento =
        new(v => v.ToString().ToLowerInvariant(),
            v => (TipoLancamento)Enum.Parse(typeof(TipoLancamento), v, ignoreCase: true));

    public static readonly ValueConverter<SentidoLancamento?, string?> Sentido =
        new(v => v.HasValue ? v.Value.ToString().ToLowerInvariant() : null,
            v => v == null
                ? (SentidoLancamento?)null
                : (SentidoLancamento)Enum.Parse(typeof(SentidoLancamento), v, ignoreCase: true));
}
