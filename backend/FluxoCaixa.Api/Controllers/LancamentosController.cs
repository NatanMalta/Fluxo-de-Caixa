using FluxoCaixa.Api.Data;
using FluxoCaixa.Api.Dtos;
using FluxoCaixa.Api.Models;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace FluxoCaixa.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class LancamentosController : ControllerBase
{
    private readonly AppDbContext _db;

    public LancamentosController(AppDbContext db)
    {
        _db = db;
    }

    [HttpGet]
    public async Task<ActionResult<IEnumerable<LancamentoResponseDto>>> Listar(
        DateTime? inicio = null,
        DateTime? fim = null,
        TipoLancamento? tipo = null,
        int? contaId = null)
    {
        var query = _db.Lancamentos
            .Include(l => l.Conta)
            .Include(l => l.Categoria)
            .Include(l => l.ContaOrigem)
            .Include(l => l.ContaDestino)
            .AsQueryable();

        if (inicio.HasValue) query = query.Where(l => l.Data >= inicio.Value.Date);
        if (fim.HasValue) query = query.Where(l => l.Data < fim.Value.Date.AddDays(1));
        if (tipo.HasValue) query = query.Where(l => l.Tipo == tipo.Value);
        if (contaId.HasValue)
        {
            query = query.Where(l =>
                l.ContaId == contaId ||
                l.ContaOrigemId == contaId ||
                l.ContaDestinoId == contaId);
        }

        var lancs = await query.OrderByDescending(l => l.Data).ThenByDescending(l => l.Id).ToListAsync();
        return Ok(lancs.Select(ToDto));
    }

    [HttpGet("{id}")]
    public async Task<ActionResult<LancamentoResponseDto>> Obter(int id)
    {
        var l = await _db.Lancamentos
            .Include(l => l.Conta)
            .Include(l => l.Categoria)
            .Include(l => l.ContaOrigem)
            .Include(l => l.ContaDestino)
            .FirstOrDefaultAsync(l => l.Id == id);
        if (l == null) return NotFound();
        return Ok(ToDto(l));
    }

    [HttpPost]
    public async Task<ActionResult<LancamentoResponseDto>> Criar(LancamentoCreateDto dto)
    {
        if (dto.Valor <= 0) return BadRequest("Valor deve ser positivo.");

        var l = new Lancamento
        {
            Data = dto.Data.Date,
            Tipo = dto.Tipo,
            Valor = dto.Valor,
            ContaId = dto.ContaId,
            Sentido = dto.Sentido,
            CategoriaId = dto.CategoriaId,
            Descricao = dto.Descricao?.Trim(),
            ContaOrigemId = dto.ContaOrigemId,
            ContaDestinoId = dto.ContaDestinoId,
        };
        _db.Lancamentos.Add(l);

        try
        {
            await _db.SaveChangesAsync();
        }
        catch (DbUpdateException ex) when (ex.InnerException?.Message?.Contains("Lançamento") == true
                                        || ex.InnerException?.Message?.Contains("Ajuste") == true
                                        || ex.InnerException?.Message?.Contains("Transferência") == true)
        {
            return BadRequest(ex.InnerException.Message);
        }

        var loaded = await _db.Lancamentos
            .Include(x => x.Conta)
            .Include(x => x.Categoria)
            .Include(x => x.ContaOrigem)
            .Include(x => x.ContaDestino)
            .FirstAsync(x => x.Id == l.Id);
        return CreatedAtAction(nameof(Obter), new { id = loaded.Id }, ToDto(loaded));
    }

    [HttpPut("{id}")]
    public async Task<ActionResult<LancamentoResponseDto>> Atualizar(int id, LancamentoUpdateDto dto)
    {
        var l = await _db.Lancamentos.FindAsync(id);
        if (l == null) return NotFound();
        if (dto.Valor <= 0) return BadRequest("Valor deve ser positivo.");

        l.Data = dto.Data.Date;
        l.Valor = dto.Valor;
        l.ContaId = dto.ContaId;
        l.Sentido = dto.Sentido;
        l.CategoriaId = dto.CategoriaId;
        l.Descricao = dto.Descricao?.Trim();
        l.ContaOrigemId = dto.ContaOrigemId;
        l.ContaDestinoId = dto.ContaDestinoId;

        try
        {
            await _db.SaveChangesAsync();
        }
        catch (DbUpdateException ex) when (ex.InnerException?.Message?.Contains("Lançamento") == true
                                        || ex.InnerException?.Message?.Contains("Ajuste") == true
                                        || ex.InnerException?.Message?.Contains("Transferência") == true)
        {
            return BadRequest(ex.InnerException.Message);
        }

        var loaded = await _db.Lancamentos
            .Include(x => x.Conta)
            .Include(x => x.Categoria)
            .Include(x => x.ContaOrigem)
            .Include(x => x.ContaDestino)
            .FirstAsync(x => x.Id == l.Id);
        return Ok(ToDto(loaded));
    }

    [HttpDelete("{id}")]
    public async Task<IActionResult> Excluir(int id)
    {
        var l = await _db.Lancamentos.FindAsync(id);
        if (l == null) return NotFound();
        _db.Lancamentos.Remove(l);
        await _db.SaveChangesAsync();
        return NoContent();
    }

    private static LancamentoResponseDto ToDto(Lancamento l) => new(
        l.Id, l.Data, l.Tipo, l.Valor,
        l.ContaId, l.Conta?.Nome,
        l.Sentido,
        l.CategoriaId, l.Categoria?.Nome,
        l.Descricao,
        l.ContaOrigemId, l.ContaOrigem?.Nome,
        l.ContaDestinoId, l.ContaDestino?.Nome,
        l.CriadoEm, l.AtualizadoEm);
}
