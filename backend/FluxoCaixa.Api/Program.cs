using System.Net.NetworkInformation;
using System.Net.Sockets;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Threading.RateLimiting;
using FluxoCaixa.Api.Data;
using FluxoCaixa.Api.Logging;
using FluxoCaixa.Api.Services;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Authorization;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.FileProviders;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.IdentityModel.Tokens;

var builder = WebApplication.CreateBuilder(args);

builder.Host.UseWindowsService();

// Logging: provider de arquivo para que o operador possa inspecionar
// os logs em tempo real mesmo quando o app roda como Windows Service
// (onde o Console não é acessível). O Console continua ativo por
// padrão via WebApplication.CreateBuilder — em `dotnet run` o terminal
// mostra tudo normalmente. Ver Logging/FileLoggerProvider.cs.
//
//   PowerShell:  Get-Content logs\fluxo-caixa.log -Wait
//   Git Bash:    tail -F logs/fluxo-caixa.log
var logPath = Path.Combine(
    builder.Environment.ContentRootPath, "logs", "fluxo-caixa.log");
builder.Logging.AddProvider(new FileLoggerProvider(logPath));

// Services
// Enums serializados como strings (camelCase) tanto na entrada quanto na saída.
// A leitura é case-insensitive, então o cliente pode mandar "banco"/"Banco"/"BANCO"
// e todos viram TipoConta.Banco. Os valores canônicos (minúsculos) são os mesmos
// usados no schema SQLite, no CONTEXT.md e no Flutter.
builder.Services.AddControllers()
    .AddJsonOptions(options =>
    {
        options.JsonSerializerOptions.Converters.Add(
            new JsonStringEnumConverter(JsonNamingPolicy.CamelCase, allowIntegerValues: true));
    });
builder.Services.AddOpenApi();

// EF Core + SQLite
var connectionString = builder.Configuration.GetConnectionString("DefaultConnection")
    ?? "Data Source=fluxo_caixa.db";
builder.Services.AddDbContext<AppDbContext>(options =>
    options.UseSqlite(connectionString));

// Helpers
builder.Services.AddScoped<SaldoCalculator>();

// Auth: JWT bearer + PIN (ver ADR 0007)
//
// Lê `Jwt:*` e `Auth:Pin` de appsettings.json. O PIN em texto puro
// existe só no `IOptions<AuthOptions>` durante o bootstrap; o
// `TokenService` (singleton) consome o valor, hasheia com BCrypt e
// descarta a referência em claro.
var jwtSecret = builder.Configuration["Jwt:Secret"]
    ?? throw new InvalidOperationException(
        "Configuração ausente: 'Jwt:Secret' em appsettings.json.");
var jwtOptions = builder.Configuration.GetSection("Jwt").Get<JwtOptions>()
    ?? throw new InvalidOperationException(
        "Configuração ausente: seção 'Jwt' em appsettings.json.");
if (string.IsNullOrWhiteSpace(jwtSecret) || jwtSecret.Length < 32)
{
    throw new InvalidOperationException(
        "'Jwt:Secret' precisa ter pelo menos 32 caracteres. " +
        "Gere algo com `openssl rand -base64 48` e cole em appsettings.json.");
}
jwtOptions.Secret = jwtSecret;

var authOptions = builder.Configuration.GetSection("Auth").Get<AuthOptions>()
    ?? throw new InvalidOperationException(
        "Configuração ausente: seção 'Auth' em appsettings.json. " +
        "Defina ao menos { \"Pin\": \"1234\" }.");
if (string.IsNullOrWhiteSpace(authOptions.Pin))
{
    throw new InvalidOperationException(
        "'Auth:Pin' não pode ser vazio. Defina um PIN numérico em appsettings.json.");
}

builder.Services.AddSingleton(Microsoft.Extensions.Options.Options.Create(jwtOptions));
builder.Services.AddSingleton<TokenService>();

// Inicializa o hash do PIN no startup. O TokenService é singleton, então
// esta chamada é a única vez que ele vê o PIN em claro.
var tokenService = new TokenService(
    Microsoft.Extensions.Options.Options.Create(jwtOptions));
tokenService.InitializePinHash(authOptions.Pin);
authOptions.Pin = string.Empty; // Limpa a referência em texto puro da config.
builder.Services.AddSingleton(tokenService);

// JWT bearer authentication
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidateAudience = true,
            ValidateLifetime = true,
            ValidateIssuerSigningKey = true,
            ValidIssuer = jwtOptions.Issuer,
            ValidAudience = jwtOptions.Audience,
            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtOptions.Secret)),
            ClockSkew = TimeSpan.FromMinutes(1),
        };
    });

// Política global de autorização: exige JWT válido em **toda** action
// que não esteja marcada com `[AllowAnonymous]`. A AuthController é a
// única exceção.
builder.Services.AddAuthorization(options =>
{
    options.FallbackPolicy = new AuthorizationPolicyBuilder()
        .RequireAuthenticatedUser()
        .Build();
});

// Rate limiter nativo do .NET 7+: política "login" usa fixed window
// de 5 req/min por IP. Sem persistência, sem DB. Mais detalhes em
// https://learn.microsoft.com/aspnet/core/performance/rate-limit
builder.Services.AddRateLimiter(options =>
{
    options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
    options.AddPolicy("login", httpContext =>
        RateLimitPartition.GetFixedWindowLimiter(
            partitionKey: httpContext.Connection.RemoteIpAddress?.ToString() ?? "unknown",
            factory: _ => new FixedWindowRateLimiterOptions
            {
                PermitLimit = 5,
                Window = TimeSpan.FromMinutes(1),
                QueueLimit = 0,
                QueueProcessingOrder = QueueProcessingOrder.OldestFirst,
                AutoReplenishment = true,
            }));
});

// CORS: liberar para o app Flutter web e mobile (que vai rodar via emulador ou IP local)
builder.Services.AddCors(options =>
{
    options.AddDefaultPolicy(policy =>
    {
        policy.AllowAnyOrigin()
              .AllowAnyHeader()
              .AllowAnyMethod();
    });
});

// Configurar URL fixa para acesso pela LAN
// (PC local + celular/tablet via Wi-Fi)
builder.WebHost.UseUrls("http://0.0.0.0:5000");

var app = builder.Build();

// Aplica o schema na primeira execução (idempotente — usa IF NOT EXISTS)
await DatabaseInitializer.InitializeAsync(app);

// Loga as URLs em que o servidor está acessível na LAN. Útil pra descobrir
// o IP depois de instalar como Windows Service (o stdout não aparece no
// terminal nesse caso — ver appsettings.json pra configurar log em arquivo).
// O bind em UseUrls é 0.0.0.0, então enumeramos as interfaces IPv4 reais
// e mostramos a URL concreta que cada dispositivo da loja deve usar.
{
    var urls = new List<string>();
    foreach (var ni in NetworkInterface.GetAllNetworkInterfaces())
    {
        if (ni.OperationalStatus != OperationalStatus.Up) continue;
        if (ni.NetworkInterfaceType == NetworkInterfaceType.Loopback) continue;
        foreach (var addr in ni.GetIPProperties().UnicastAddresses)
        {
            if (addr.Address.AddressFamily == AddressFamily.InterNetwork)
            {
                urls.Add($"http://{addr.Address}:5000/");
            }
        }
    }
    if (urls.Count > 0)
    {
        app.Logger.LogInformation("FluxoCaixa acessível em: {Urls}", string.Join(", ", urls));
    }
    else
    {
        app.Logger.LogWarning("Nenhuma interface de rede IPv4 ativa — o servidor pode estar offline.");
    }
}

if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
}

// Frontend Flutter web: serve o conteúdo de wwwroot/ (materializado pelo
// scripts/deploy-frontend.ps1 a partir de `flutter build web`). O
// UseDefaultFiles antes do UseStaticFiles reescreve "/" -> "/index.html".
// Tem que vir ANTES do auth/cors/rate-limiter para que /index.html e
// /main.dart.js sejam servidos sem precisar de JWT. O MapFallbackToFile
// no final captura deep links do Flutter Router (/lancar, /balanco,
// /config) e devolve index.html para o roteador client-side assumir.
app.UseDefaultFiles();

// Workaround do Flutter web: assets declarados no pubspec como
// `assets/config.json` são bundleados em `wwwroot/assets/assets/<file>`
// (a pasta `assets/` duplica). Mas o AssetManifest.bin (que o app
// consulta em runtime para resolver o asset) mapeia
// `assets/config.json` -> `/assets/config.json` (SEM o duplicado).
// Sem este alias, a request do ApiClient.init() para /assets/config.json
// cai no fallback (que tem constraint :nonfile e rejeita paths com
// extensão), retornando 401, e o baseUrl cai silenciosamente no
// default http://localhost:5000. O login então vai para o localhost
// do browser, não para o servidor, e falha com "não foi possível
// conectar". O segundo UseStaticFiles abaixo serve /assets/* a partir
// de wwwroot/assets/assets/, e o primeiro (logo embaixo) cobre o resto
// de wwwroot/ (incluindo /assets/AssetManifest.bin que fica 1 nível
// acima).
app.UseStaticFiles(new StaticFileOptions
{
    FileProvider = new PhysicalFileProvider(
        Path.Combine(builder.Environment.WebRootPath, "assets", "assets")),
    RequestPath = "/assets",
});
app.UseStaticFiles();

app.UseCors();
app.UseRateLimiter();
app.UseAuthentication();
app.UseAuthorization();
app.MapControllers();
// O fallback captura deep links do Flutter Router (/lancar, /balanco,
// /config) servindo index.html. .AllowAnonymous() é OBRIGATÓRIO: sem
// isso, a FallbackPolicy global (RequireAuthenticatedUser) mata o
// request com 401 antes de o index.html chegar ao browser — o usuário
// jamais veria a tela de PIN. O controller de /api/* continua exigindo
// JWT (política por controller) e o frontend, ao logar, recebe o token
// e adiciona em todos os requests subsequentes via ApiClient.
app.MapFallbackToFile("index.html").AllowAnonymous();

app.Run();

public partial class Program { }
