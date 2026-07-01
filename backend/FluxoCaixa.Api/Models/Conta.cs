namespace FluxoCaixa.Api.Models;

public class Conta
{
    public int Id { get; set; }
    public string Nome { get; set; } = string.Empty;
    public TipoConta Tipo { get; set; }
    public decimal SaldoInicial { get; set; }
    public bool Ativo { get; set; } = true;
    public DateTime CriadoEm { get; set; }
    public DateTime AtualizadoEm { get; set; }
}
