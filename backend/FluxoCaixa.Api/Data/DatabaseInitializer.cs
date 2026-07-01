using Microsoft.Data.Sqlite;

namespace FluxoCaixa.Api.Data;

/// <summary>
/// Aplica o schema SQL (incluindo triggers) na primeira inicialização do app.
/// Idempotente — usa IF NOT EXISTS e CREATE OR REPLACE para triggers.
/// </summary>
public static class DatabaseInitializer
{
    public static async Task InitializeAsync(WebApplication app)
    {
        var config = app.Configuration;
        var connectionString = config.GetConnectionString("DefaultConnection")
            ?? "Data Source=fluxo_caixa.db";

        // Extrai o caminho do banco a partir da connection string
        var builder = new SqliteConnectionStringBuilder(connectionString);
        var dbPath = builder.DataSource;

        // Garante que o diretório do banco existe
        var dir = Path.GetDirectoryName(Path.GetFullPath(dbPath));
        if (!string.IsNullOrEmpty(dir) && !Directory.Exists(dir))
        {
            Directory.CreateDirectory(dir);
        }

        // Aplica o schema
        var schemaPath = Path.Combine(AppContext.BaseDirectory, "db", "schema.sql");
        if (!File.Exists(schemaPath))
        {
            // Em modo `dotnet run`, o arquivo está em <project>/db/schema.sql,
            // não no diretório de output. Procurar a partir do CWD como fallback.
            var alt = Path.Combine(Directory.GetCurrentDirectory(), "..", "..", "..", "..", "db", "schema.sql");
            if (File.Exists(alt)) schemaPath = Path.GetFullPath(alt);
        }

        if (!File.Exists(schemaPath))
        {
            throw new FileNotFoundException(
                $"schema.sql não encontrado. Procurado em: {schemaPath}. " +
                "Copie db/schema.sql para a raiz do projeto ou para o diretório de output.");
        }

        var sql = await File.ReadAllTextAsync(schemaPath);

        await using var conn = new SqliteConnection(connectionString);
        await conn.OpenAsync();

        await using var cmd = conn.CreateCommand();
        cmd.CommandText = sql;
        await cmd.ExecuteNonQueryAsync();

        app.Logger.LogInformation("Schema aplicado em {DbPath}", dbPath);
    }
}
