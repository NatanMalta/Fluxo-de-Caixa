using Microsoft.Extensions.Logging;

namespace FluxoCaixa.Api.Logging;

/// <summary>
/// File logger provider minimalista. Escreve em
/// <c>{ContentRoot}/logs/fluxo-caixa.log</c>, append-only, sem rotação.
/// Volume de log esperado é baixo (single user, LAN, INFO+), então vira
/// prático abrir no bloco de notas e dar tail sem virar um pipeline.
///
/// Por que não Serilog/NLog: .NET não traz provedor de arquivo na caixa,
/// e pra um único sink a troca de 2-3 pacotes por 40 linhas de código
/// não compensa. Se a demanda por logging crescer (vários sinks,
/// rotação, enrichers), vale trocar por Serilog.
///
/// Para acompanhar em tempo real em qualquer terminal:
///   PowerShell:  Get-Content logs\fluxo-caixa.log -Wait
///   Git Bash:    tail -F logs/fluxo-caixa.log
/// </summary>
public sealed class FileLoggerProvider : ILoggerProvider
{
    private readonly string _filePath;
    private readonly object _writeLock = new();

    public FileLoggerProvider(string filePath)
    {
        _filePath = filePath;
        // Garante o diretório no construtor pra primeira linha não
        // correr risco de race com quem chamou CreateDirectory.
        var dir = Path.GetDirectoryName(_filePath);
        if (!string.IsNullOrEmpty(dir)) Directory.CreateDirectory(dir);
    }

    public ILogger CreateLogger(string categoryName) => new FileLogger(this, categoryName);

    public void Dispose() { }

    private void WriteLine(string line)
    {
        lock (_writeLock)
        {
            // AppendAllText abre, escreve e fecha a cada chamada.
            // Volume de log é baixo, então o custo é desprezível. A
            // alternativa (StreamWriter mantido aberto) complica o
            // Dispose e arrisca leak de handle em crash.
            try
            {
                File.AppendAllText(_filePath, line + Environment.NewLine);
            }
            catch
            {
                // Falha de logging NUNCA pode derrubar o host. Engolir
                // é a política certa — o operador vai notar que o
                // arquivo parou de crescer.
            }
        }
    }

    private sealed class FileLogger : ILogger
    {
        private const LogLevel MinLevel = LogLevel.Information;

        private readonly FileLoggerProvider _owner;
        private readonly string _category;

        public FileLogger(FileLoggerProvider owner, string category)
        {
            _owner = owner;
            _category = category;
        }

        public IDisposable? BeginScope<TState>(TState state) where TState : notnull => null;

        public bool IsEnabled(LogLevel logLevel) => logLevel >= MinLevel;

        public void Log<TState>(
            LogLevel logLevel,
            EventId eventId,
            TState state,
            Exception? exception,
            Func<TState, Exception?, string> formatter)
        {
            if (!IsEnabled(logLevel)) return;

            var message = formatter(state, exception);
            var line = $"{DateTime.Now:yyyy-MM-dd HH:mm:ss.fff} [{logLevel,-11}] {_category}: {message}";
            if (exception is not null)
            {
                line += Environment.NewLine + exception;
            }
            _owner.WriteLine(line);
        }
    }
}
