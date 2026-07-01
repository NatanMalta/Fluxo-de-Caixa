namespace FluxoCaixa.Api.Models;

public class Lancamento
{
    public int Id { get; set; }
    public DateTime Data { get; set; }
    public TipoLancamento Tipo { get; set; }
    public decimal Valor { get; set; }

    // Comum e Ajuste
    public int? ContaId { get; set; }
    public Conta? Conta { get; set; }
    public SentidoLancamento? Sentido { get; set; }

    // Comum
    public int? CategoriaId { get; set; }
    public Categoria? Categoria { get; set; }

    // Ajuste
    public string? Descricao { get; set; }

    // Transferência
    public int? ContaOrigemId { get; set; }
    public Conta? ContaOrigem { get; set; }
    public int? ContaDestinoId { get; set; }
    public Conta? ContaDestino { get; set; }

    public DateTime CriadoEm { get; set; }
    public DateTime AtualizadoEm { get; set; }
}
