using FluxoCaixa.Api.Data;
using FluxoCaixa.Api.Dtos;
using FluxoCaixa.Api.Models;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace FluxoCaixa.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class CategoriasController : ControllerBase
{
    private readonly AppDbContext _db;

    public CategoriasController(AppDbContext db)
    {
        _db = db;
    }

    [HttpGet]
    public async Task<ActionResult<IEnumerable<CategoriaResponseDto>>> Listar(
        TipoCategoria? tipo = null,
        bool? incluirInativas = false)
    {
        var query = _db.Categorias.AsQueryable();
        if (incluirInativas != true) query = query.Where(c => c.Ativo);
        if (tipo.HasValue) query = query.Where(c => c.Tipo == tipo.Value);
        var cats = await query.OrderBy(c => c.Nome).ToListAsync();
        return Ok(cats.Select(ToDto));
    }

    [HttpGet("{id}")]
    public async Task<ActionResult<CategoriaResponseDto>> Obter(int id)
    {
        var c = await _db.Categorias.FindAsync(id);
        if (c == null) return NotFound();
        return Ok(ToDto(c));
    }

    [HttpPost]
    public async Task<ActionResult<CategoriaResponseDto>> Criar(CategoriaCreateDto dto)
    {
        if (string.IsNullOrWhiteSpace(dto.Nome)) return BadRequest("Nome é obrigatório.");

        var c = new Categoria
        {
            Nome = dto.Nome.Trim(),
            Tipo = dto.Tipo,
            Ativo = true,
        };
        _db.Categorias.Add(c);
        await _db.SaveChangesAsync();
        return CreatedAtAction(nameof(Obter), new { id = c.Id }, ToDto(c));
    }

    [HttpPut("{id}")]
    public async Task<ActionResult<CategoriaResponseDto>> Atualizar(int id, CategoriaUpdateDto dto)
    {
        var c = await _db.Categorias.FindAsync(id);
        if (c == null) return NotFound();

        c.Nome = dto.Nome.Trim();
        c.Tipo = dto.Tipo;
        c.Ativo = dto.Ativo;
        await _db.SaveChangesAsync();
        return Ok(ToDto(c));
    }

    [HttpDelete("{id}")]
    public async Task<IActionResult> Excluir(int id)
    {
        var c = await _db.Categorias.FindAsync(id);
        if (c == null) return NotFound();

        c.Ativo = false;
        await _db.SaveChangesAsync();
        return NoContent();
    }

    private static CategoriaResponseDto ToDto(Categoria c) =>
        new(c.Id, c.Nome, c.Tipo, c.Ativo, c.CriadoEm, c.AtualizadoEm);
}
