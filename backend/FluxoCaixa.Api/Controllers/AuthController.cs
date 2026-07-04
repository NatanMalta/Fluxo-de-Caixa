using FluxoCaixa.Api.Dtos;
using FluxoCaixa.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;

namespace FluxoCaixa.Api.Controllers;

/// Autenticação por PIN único (ver ADR 0007).
///
/// Rota **livre** de `[Authorize]` (a política global `RequireAuthenticatedUser`
/// não se aplica porque a action é marcada com `[AllowAnonymous]`).
/// Demais controllers exigem JWT válido para chamar qualquer endpoint.
[ApiController]
[Route("api/[controller]")]
[AllowAnonymous]
public class AuthController : ControllerBase
{
    private readonly TokenService _tokens;

    public AuthController(TokenService tokens)
    {
        _tokens = tokens;
    }

    /// `POST /api/auth/login` com `{ "pin": "1234" }`.
    /// Retorna `{ "token": "<jwt>", "expiresAt": "<iso>" }` em sucesso (200);
    /// retorna 401 sem corpo detalhado em PIN errado — mesma resposta
    /// genérica para evitar vazar se o usuário existe (não vaza nada aqui
    /// porque o app é single-user, mas a forma é a que se esperaria
    /// num app multi-user futuro).
    ///
    /// Rate limit: 5 requisições/minuto por IP (fixed window), configurado
    /// em `Program.cs` na política `login`. Acima disso, responde 429.
    [HttpPost("login")]
    [EnableRateLimiting("login")]
    public IActionResult Login([FromBody] LoginRequest req)
    {
        if (req is null || string.IsNullOrWhiteSpace(req.Pin))
        {
            return Unauthorized();
        }

        // PIN é numérico curto (4-6 dígitos). Validamos aqui para evitar
        // gastar ciclo de BCrypt em entradas absurdamente longas.
        var pin = req.Pin.Trim();
        if (pin.Length < 4 || pin.Length > 8 || !pin.All(char.IsDigit))
        {
            return Unauthorized();
        }

        if (!_tokens.ValidatePin(pin))
        {
            return Unauthorized();
        }

        var (token, expiresAt) = _tokens.IssueToken();
        return Ok(new LoginResponse(token, expiresAt));
    }
}
