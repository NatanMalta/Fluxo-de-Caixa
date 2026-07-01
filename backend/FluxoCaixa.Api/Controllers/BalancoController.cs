using FluxoCaixa.Api.Data;
using FluxoCaixa.Api.Models;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace FluxoCaixa.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class BalancoController : ControllerBase
{
    private readonly AppDbContext _db;

    public BalancoController(AppDbContext db)
    {
        _db = db;
    }

    /// <summary>
    /// Retorna o resumo do período: total de Entradas, Saídas, Resultado,
    /// saldo de cada Conta no fim do período, e breakdown por Categoria.
    /// </summary>
    [HttpGet]
    public async Task<ActionResult<BalancoResponse>> Obter(
        [FromQuery] DateTime inicio,
        [FromQuery] DateTime fim)
    {
        if (fim < inicio) return BadRequest("Data final deve ser maior ou igual à inicial.");

        var inicioDate = inicio.Date;
        var fimExclusive = fim.Date.AddDays(1);

        // Total de Entradas e Saídas no período (Comuns + Ajustes).
        // Transferências são excluídas — são movimentos entre contas, não do negócio.
        var comunsAjustes = await _db.Lancamentos
            .Where(l => l.Data >= inicioDate && l.Data < fimExclusive)
            .Where(l => l.Tipo == TipoLancamento.Comum || l.Tipo == TipoLancamento.Ajuste)
            .ToListAsync();

        var totalEntradas = comunsAjustes
            .Where(l => l.Sentido == SentidoLancamento.Entrada)
            .Sum(l => l.Valor);

        var totalSaidas = comunsAjustes
            .Where(l => l.Sentido == SentidoLancamento.Saida)
            .Sum(l => l.Valor);

        // Saldo de cada Conta no fim do período.
        var contas = await _db.Contas.Where(c => c.Ativo).OrderBy(c => c.Nome).ToListAsync();
        var saldosPorConta = new List<ContaSaldo>();

        foreach (var conta in contas)
        {
            var saldo = conta.SaldoInicial;

            var lancs = await _db.Lancamentos
                .Where(l => l.Data < fimExclusive)
                .Where(l =>
                    ((l.Tipo == TipoLancamento.Comum || l.Tipo == TipoLancamento.Ajuste) && l.ContaId == conta.Id) ||
                    (l.Tipo == TipoLancamento.Transferencia &&
                        (l.ContaOrigemId == conta.Id || l.ContaDestinoId == conta.Id)))
                .ToListAsync();

            foreach (var l in lancs)
            {
                switch (l.Tipo)
                {
                    case TipoLancamento.Comum:
                    case TipoLancamento.Ajuste:
                        saldo += l.Sentido == SentidoLancamento.Entrada ? l.Valor : -l.Valor;
                        break;
                    case TipoLancamento.Transferencia:
                        if (l.ContaOrigemId == conta.Id) saldo -= l.Valor;
                        if (l.ContaDestinoId == conta.Id) saldo += l.Valor;
                        break;
                }
            }

            saldosPorConta.Add(new ContaSaldo(conta.Id, conta.Nome, saldo));
        }

        // Breakdown por Categoria (apenas Comuns).
        var comuns = comunsAjustes.Where(l => l.Tipo == TipoLancamento.Comum).ToList();

        var categorias = await _db.Categorias.ToDictionaryAsync(c => c.Id, c => c.Nome);
        var entradasPorCategoria = comuns
            .Where(l => l.Sentido == SentidoLancamento.Entrada && l.CategoriaId.HasValue)
            .GroupBy(l => l.CategoriaId!.Value)
            .Select(g => new CategoriaTotal(g.Key, categorias.GetValueOrDefault(g.Key, "?"), g.Sum(x => x.Valor)))
            .OrderByDescending(x => x.Total)
            .ToList();

        var saidasPorCategoria = comuns
            .Where(l => l.Sentido == SentidoLancamento.Saida && l.CategoriaId.HasValue)
            .GroupBy(l => l.CategoriaId!.Value)
            .Select(g => new CategoriaTotal(g.Key, categorias.GetValueOrDefault(g.Key, "?"), g.Sum(x => x.Valor)))
            .OrderByDescending(x => x.Total)
            .ToList();

        return Ok(new BalancoResponse(
            inicioDate,
            fim.Date,
            totalEntradas,
            totalSaidas,
            totalEntradas - totalSaidas,
            saldosPorConta,
            entradasPorCategoria,
            saidasPorCategoria));
    }

    public record ContaSaldo(int ContaId, string Nome, decimal Saldo);
    public record CategoriaTotal(int CategoriaId, string Nome, decimal Total);
    public record BalancoResponse(
        DateTime Inicio,
        DateTime Fim,
        decimal TotalEntradas,
        decimal TotalSaidas,
        decimal Resultado,
        List<ContaSaldo> SaldosPorConta,
        List<CategoriaTotal> EntradasPorCategoria,
        List<CategoriaTotal> SaidasPorCategoria);
}
