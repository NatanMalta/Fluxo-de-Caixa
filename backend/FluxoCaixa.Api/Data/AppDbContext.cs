using FluxoCaixa.Api.Models;
using Microsoft.EntityFrameworkCore;

namespace FluxoCaixa.Api.Data;

public class AppDbContext : DbContext
{
    public AppDbContext(DbContextOptions<AppDbContext> options) : base(options) { }

    public DbSet<Conta> Contas => Set<Conta>();
    public DbSet<Categoria> Categorias => Set<Categoria>();
    public DbSet<Lancamento> Lancamentos => Set<Lancamento>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<Conta>(e =>
        {
            e.ToTable("contas");
            e.HasKey(c => c.Id);
            e.Property(c => c.Id).HasColumnName("id");
            e.Property(c => c.Nome).HasColumnName("nome").IsRequired();
            e.Property(c => c.Tipo).HasColumnName("tipo").HasConversion(EnumStringConverters.Conta).IsRequired();
            e.Property(c => c.SaldoInicial).HasColumnName("saldo_inicial").HasColumnType("REAL");
            e.Property(c => c.Ativo).HasColumnName("ativo");
            e.Property(c => c.CriadoEm).HasColumnName("criado_em").HasColumnType("TEXT");
            e.Property(c => c.AtualizadoEm).HasColumnName("atualizado_em").HasColumnType("TEXT");
        });

        modelBuilder.Entity<Categoria>(e =>
        {
            e.ToTable("categorias");
            e.HasKey(c => c.Id);
            e.Property(c => c.Id).HasColumnName("id");
            e.Property(c => c.Nome).HasColumnName("nome").IsRequired();
            e.Property(c => c.Tipo).HasColumnName("tipo").HasConversion(EnumStringConverters.Categoria).IsRequired();
            e.Property(c => c.Ativo).HasColumnName("ativo");
            e.Property(c => c.CriadoEm).HasColumnName("criado_em").HasColumnType("TEXT");
            e.Property(c => c.AtualizadoEm).HasColumnName("atualizado_em").HasColumnType("TEXT");
        });

        modelBuilder.Entity<Lancamento>(e =>
        {
            e.ToTable("lancamentos");
            e.HasKey(l => l.Id);
            e.Property(l => l.Id).HasColumnName("id");
            e.Property(l => l.Data).HasColumnName("data").HasColumnType("TEXT");
            e.Property(l => l.Tipo).HasColumnName("tipo").HasConversion(EnumStringConverters.Lancamento).IsRequired();
            e.Property(l => l.Valor).HasColumnName("valor").HasColumnType("REAL");
            e.Property(l => l.ContaId).HasColumnName("conta_id");
            e.Property(l => l.Sentido).HasColumnName("sentido").HasConversion(EnumStringConverters.Sentido);
            e.Property(l => l.CategoriaId).HasColumnName("categoria_id");
            e.Property(l => l.Descricao).HasColumnName("descricao");
            e.Property(l => l.ContaOrigemId).HasColumnName("conta_origem_id");
            e.Property(l => l.ContaDestinoId).HasColumnName("conta_destino_id");
            e.Property(l => l.CriadoEm).HasColumnName("criado_em").HasColumnType("TEXT");
            e.Property(l => l.AtualizadoEm).HasColumnName("atualizado_em").HasColumnType("TEXT");

            e.HasOne(l => l.Conta)
                .WithMany()
                .HasForeignKey(l => l.ContaId)
                .OnDelete(DeleteBehavior.Restrict);

            e.HasOne(l => l.Categoria)
                .WithMany()
                .HasForeignKey(l => l.CategoriaId)
                .OnDelete(DeleteBehavior.Restrict);

            e.HasOne(l => l.ContaOrigem)
                .WithMany()
                .HasForeignKey(l => l.ContaOrigemId)
                .OnDelete(DeleteBehavior.Restrict);

            e.HasOne(l => l.ContaDestino)
                .WithMany()
                .HasForeignKey(l => l.ContaDestinoId)
                .OnDelete(DeleteBehavior.Restrict);
        });
    }

    public override int SaveChanges()
    {
        AtualizarTimestamps();
        return base.SaveChanges();
    }

    public override Task<int> SaveChangesAsync(CancellationToken cancellationToken = default)
    {
        AtualizarTimestamps();
        return base.SaveChangesAsync(cancellationToken);
    }

    private void AtualizarTimestamps()
    {
        var now = DateTime.UtcNow;
        foreach (var entry in ChangeTracker.Entries<Conta>())
        {
            if (entry.State == EntityState.Added)
            {
                entry.Entity.CriadoEm = now;
                entry.Entity.AtualizadoEm = now;
            }
            else if (entry.State == EntityState.Modified)
            {
                entry.Entity.AtualizadoEm = now;
            }
        }
        foreach (var entry in ChangeTracker.Entries<Categoria>())
        {
            if (entry.State == EntityState.Added)
            {
                entry.Entity.CriadoEm = now;
                entry.Entity.AtualizadoEm = now;
            }
            else if (entry.State == EntityState.Modified)
            {
                entry.Entity.AtualizadoEm = now;
            }
        }
        foreach (var entry in ChangeTracker.Entries<Lancamento>())
        {
            if (entry.State == EntityState.Added)
            {
                entry.Entity.CriadoEm = now;
                entry.Entity.AtualizadoEm = now;
            }
            else if (entry.State == EntityState.Modified)
            {
                entry.Entity.AtualizadoEm = now;
            }
        }
    }
}
