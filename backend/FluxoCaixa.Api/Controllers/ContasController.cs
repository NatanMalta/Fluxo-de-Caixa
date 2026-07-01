using FluxoCaixa.Api.Data;
using FluxoCaixa.Api.Dtos;
using FluxoCaixa.Api.Models;
using FluxoCaixa.Api.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace FluxoCaixa.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class ContasController : ControllerBase
{
    private readonly AppDbContext _db;
    private readonly SaldoCalculator _saldo;

    public ContasController(AppDbContext db, SaldoCalculator saldo)
    {
        _db = db;
        _saldo = saldo;
    }

    [HttpGet]
    public async Task<ActionResult<IEnumerable<ContaResponseDto>>> Listar(bool? incluirInativas = false)
    {
        var query = _db.Contas.AsQueryable();
        if (incluirInativas != true) query = query.Where(c => c.Ativo);
        var contas = await query.OrderBy(c => c.Nome).ToListAsync();

        return Ok(contas.Select(c => ToDto(c)));
    }

    [HttpGet("{id}")]
    public async Task<ActionResult<ContaResponseDto>> Obter(int id)
    {
        var c = await _db.Contas.FindAsync(id);
        if (c == null) return NotFound();
        return Ok(ToDto(c));
    }

    [HttpPost]
    public async Task<ActionResult<ContaResponseDto>> Criar(ContaCreateDto dto)
    {
        if (string.IsNullOrWhiteSpace(dto.Nome)) return BadRequest("Nome é obrigatório.");

        var c = new Conta
        {
            Nome = dto.Nome.Trim(),
            Tipo = dto.Tipo,
            SaldoInicial = dto.SaldoInicial,
            Ativo = true,
        };
        _db.Contas.Add(c);
        await _db.SaveChangesAsync();
        return CreatedAtAction(nameof(Obter), new { id = c.Id }, ToDto(c));
    }

    [HttpPut("{id}")]
    public async Task<ActionResult<ContaResponseDto>> Atualizar(int id, ContaUpdateDto dto)
    {
        var c = await _db.Contas.FindAsync(id);
        if (c == null) return NotFound();

        c.Nome = dto.Nome.Trim();
        c.Tipo = dto.Tipo;
        c.SaldoInicial = dto.SaldoInicial;
        c.Ativo = dto.Ativo;
        await _db.SaveChangesAsync();
        return Ok(ToDto(c));
    }

    [HttpDelete("{id}")]
    public async Task<IActionResult> Excluir(int id)
    {
        var c = await _db.Contas.FindAsync(id);
        if (c == null) return NotFound();

        // Soft delete: desativa em vez de excluir, para preservar histórico de Lançamentos
        c.Ativo = false;
        await _db.SaveChangesAsync();
        return NoContent();
    }

    private ContaResponseDto ToDto(Conta c) => new(
        c.Id, c.Nome, c.Tipo, c.SaldoInicial, c.Ativo,
        c.CriadoEm, c.AtualizadoEm,
        _saldo.CalcularSaldoAtual(c.Id));
}
