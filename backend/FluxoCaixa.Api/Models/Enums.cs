namespace FluxoCaixa.Api.Models;

public enum TipoConta
{
    Banco,
    Especie,
}

public enum TipoCategoria
{
    Entrada,
    Saida,
}

public enum TipoLancamento
{
    Comum,
    Ajuste,
    Transferencia,
}

public enum SentidoLancamento
{
    Entrada,
    Saida,
}
