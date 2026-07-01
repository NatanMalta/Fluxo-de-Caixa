using FluxoCaixa.Api.Data;
using FluxoCaixa.Api.Models;
using Microsoft.EntityFrameworkCore;

namespace FluxoCaixa.Api.Services;

public class SaldoCalculator
{
    private readonly AppDbContext _db;

    public SaldoCalculator(AppDbContext db)
    {
        _db = db;
    }

    public decimal CalcularSaldoAtual(int contaId, DateTime? ateData = null)
    {
        var conta = _db.Contas.Find(contaId);
        if (conta == null) return 0m;

        var saldo = conta.SaldoInicial;
        var limiteSuperior = ateData?.Date.AddDays(1) ?? DateTime.MaxValue;

        var lancamentos = _db.Lancamentos
            .Where(l => l.Data < limiteSuperior)
            .Where(l =>
                ((l.Tipo == TipoLancamento.Comum || l.Tipo == TipoLancamento.Ajuste) && l.ContaId == contaId) ||
                (l.Tipo == TipoLancamento.Transferencia &&
                    (l.ContaOrigemId == contaId || l.ContaDestinoId == contaId)))
            .ToList();

        foreach (var l in lancamentos)
        {
            switch (l.Tipo)
            {
                case TipoLancamento.Comum:
                case TipoLancamento.Ajuste:
                    saldo += l.Sentido == SentidoLancamento.Entrada ? l.Valor : -l.Valor;
                    break;
                case TipoLancamento.Transferencia:
                    if (l.ContaOrigemId == contaId) saldo -= l.Valor;
                    if (l.ContaDestinoId == contaId) saldo += l.Valor;
                    break;
            }
        }

        return saldo;
    }
}
