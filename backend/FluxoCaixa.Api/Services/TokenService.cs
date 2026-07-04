using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using Microsoft.IdentityModel.Tokens;

namespace FluxoCaixa.Api.Services;

/// Opções de configuração do JWT, lidas de `appsettings.json` em
/// `Jwt: { Secret, ExpiryDays, Issuer, Audience }`. Mapeadas em
/// `Program.cs` via `builder.Services.Configure<JwtOptions>(...)`.
public class JwtOptions
{
    public string Secret { get; set; } = string.Empty;
    public int ExpiryDays { get; set; } = 30;
    public string Issuer { get; set; } = "FluxoCaixa.Api";
    public string Audience { get; set; } = "FluxoCaixa.Client";
}

/// Opções do PIN de autenticação, lidas de `appsettings.json` em
/// `Auth: { Pin }`. O PIN é texto puro no config (decisão do ADR 0007);
/// o backend hasheia com BCrypt em memória no startup e descarta o
/// texto puro.
public class AuthOptions
{
    public string Pin { get; set; } = string.Empty;
}

/// Mantém o hash BCrypt do PIN e emite JWTs de 30 dias.
///
/// Carregado como **singleton**: o hash do PIN é calculado uma vez no
/// startup (ver `Program.cs`) e reusado em todos os logins. O texto
/// puro do PIN nunca é persistido em lugar nenhum — fica só no
/// `AuthOptions` durante a fase de bootstrap, sendo zerado logo
/// após o `InitializeAsync` por `TokenService`.
public class TokenService
{
    private readonly JwtOptions _jwt;
    private string _pinHash = string.Empty;

    public TokenService(Microsoft.Extensions.Options.IOptions<JwtOptions> jwt)
    {
        _jwt = jwt.Value;
    }

    /// Chamado uma vez no startup pelo `Program.cs` depois de ler
    /// `Auth:Pin` de `appsettings.json`. Recebe o PIN em texto puro
    /// apenas para gerar o hash; o caller deve descartar a string
    /// original em seguida.
    public void InitializePinHash(string plainPin)
    {
        if (string.IsNullOrEmpty(plainPin))
        {
            throw new InvalidOperationException(
                "PIN não pode ser vazio. Defina 'Auth:Pin' em appsettings.json.");
        }
        _pinHash = BCrypt.Net.BCrypt.HashPassword(plainPin, workFactor: 11);
    }

    /// Valida o PIN tentado contra o hash armazenado. Constant-time
    /// via `BCrypt.Verify`.
    public bool ValidatePin(string attemptedPin)
    {
        if (string.IsNullOrEmpty(_pinHash) || string.IsNullOrEmpty(attemptedPin))
        {
            return false;
        }
        try
        {
            return BCrypt.Net.BCrypt.Verify(attemptedPin, _pinHash);
        }
        catch (BCrypt.Net.SaltParseException)
        {
            // Hash corrompido na memória (não deveria acontecer).
            return false;
        }
    }

    /// Emite um JWT assinado com HS256. O único claim útil é o `sub`
    /// (sempre "owner" — app de usuário único) e timestamps padrão.
    public (string token, DateTime expiresAt) IssueToken()
    {
        var now = DateTime.UtcNow;
        var expires = now.AddDays(_jwt.ExpiryDays);
        var keyBytes = Encoding.UTF8.GetBytes(_jwt.Secret);
        var key = new SymmetricSecurityKey(keyBytes);
        var creds = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);

        var token = new JwtSecurityToken(
            issuer: _jwt.Issuer,
            audience: _jwt.Audience,
            claims: new[]
            {
                new Claim(JwtRegisteredClaimNames.Sub, "owner"),
                new Claim(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString()),
            },
            notBefore: now,
            expires: expires,
            signingCredentials: creds);

        return (new JwtSecurityTokenHandler().WriteToken(token), expires);
    }
}
