using System.Text.Json;
using System.Text.Json.Serialization;
using FluxoCaixa.Api.Data;
using FluxoCaixa.Api.Services;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);

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

if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
}

app.UseCors();
app.MapControllers();

app.Run();

public partial class Program { }
