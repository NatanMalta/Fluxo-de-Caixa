-- =============================================================================
-- Fluxo de Caixa do Mercadinho — Schema v1
-- Engine: SQLite 3
-- Documentação: ../CONTEXT.md
-- Decisões arquiteturais: ../docs/adr/
-- =============================================================================

PRAGMA foreign_keys = ON;
PRAGMA journal_mode = WAL;

-- =============================================================================
-- Tabela: contas
-- Lugares onde o mercadinho guarda dinheiro (caixa físico, conta-corrente,
-- poupança, conta digital etc.). Ver CONTEXT.md → "Conta".
-- =============================================================================
CREATE TABLE IF NOT EXISTS contas (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    nome            TEXT    NOT NULL,
    tipo            TEXT    NOT NULL CHECK (tipo IN ('banco', 'especie')),
    saldo_inicial   REAL    NOT NULL DEFAULT 0,
    ativo           INTEGER NOT NULL DEFAULT 1 CHECK (ativo IN (0, 1)),
    criado_em       TEXT    NOT NULL DEFAULT (datetime('now')),
    atualizado_em   TEXT    NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_contas_ativo ON contas(ativo);

-- =============================================================================
-- Tabela: categorias
-- Classificação de origens (entrada) e destinos (saída) de Lançamentos.
-- Ver CONTEXT.md → "Categoria".
-- =============================================================================
CREATE TABLE IF NOT EXISTS categorias (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    nome            TEXT    NOT NULL,
    tipo            TEXT    NOT NULL CHECK (tipo IN ('entrada', 'saida')),
    ativo           INTEGER NOT NULL DEFAULT 1 CHECK (ativo IN (0, 1)),
    criado_em       TEXT    NOT NULL DEFAULT (datetime('now')),
    atualizado_em   TEXT    NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_categorias_tipo ON categorias(tipo, ativo);

-- =============================================================================
-- Tabela: lancamentos
-- Registros de movimentação de dinheiro. Discriminator: tipo.
--   - 'comum'         → entrada/saída comum (usa conta_id, categoria_id, sentido)
--   - 'ajuste'        → correção de saldo (usa conta_id, sentido, descricao)
--   - 'transferencia' → entre duas contas (usa conta_origem_id, conta_destino_id)
-- Ver CONTEXT.md → "Lançamento".
-- =============================================================================
CREATE TABLE IF NOT EXISTS lancamentos (
    id                  INTEGER PRIMARY KEY AUTOINCREMENT,

    -- Campos comuns a todos os tipos
    data                TEXT    NOT NULL,   -- ISO 8601 'YYYY-MM-DD'
    tipo                TEXT    NOT NULL CHECK (tipo IN ('comum', 'ajuste', 'transferencia')),
    valor               REAL    NOT NULL CHECK (valor > 0),

    -- Usado por 'comum' e 'ajuste'
    conta_id            INTEGER,
    sentido             TEXT CHECK (sentido IS NULL OR sentido IN ('entrada', 'saida')),

    -- Usado só por 'comum'
    categoria_id        INTEGER,

    -- Usado só por 'ajuste'
    descricao           TEXT,

    -- Usado só por 'transferencia'
    conta_origem_id     INTEGER,
    conta_destino_id    INTEGER,

    -- Auditoria
    criado_em           TEXT    NOT NULL DEFAULT (datetime('now')),
    atualizado_em       TEXT    NOT NULL DEFAULT (datetime('now')),

    -- FKs
    FOREIGN KEY (conta_id)         REFERENCES contas(id)     ON DELETE RESTRICT,
    FOREIGN KEY (categoria_id)     REFERENCES categorias(id) ON DELETE RESTRICT,
    FOREIGN KEY (conta_origem_id)  REFERENCES contas(id)     ON DELETE RESTRICT,
    FOREIGN KEY (conta_destino_id) REFERENCES contas(id)     ON DELETE RESTRICT
);

CREATE INDEX IF NOT EXISTS idx_lancamentos_data      ON lancamentos(data);
CREATE INDEX IF NOT EXISTS idx_lancamentos_tipo      ON lancamentos(tipo);
CREATE INDEX IF NOT EXISTS idx_lancamentos_conta     ON lancamentos(conta_id);
CREATE INDEX IF NOT EXISTS idx_lancamentos_categoria ON lancamentos(categoria_id);
CREATE INDEX IF NOT EXISTS idx_lancamentos_origem    ON lancamentos(conta_origem_id);
CREATE INDEX IF NOT EXISTS idx_lancamentos_destino   ON lancamentos(conta_destino_id);

-- =============================================================================
-- Triggers: validação de campos obrigatórios por tipo
-- (SQLite não suporta CHECK complexos multi-coluna, então usamos triggers)
-- =============================================================================

-- -------- comum --------
CREATE TRIGGER IF NOT EXISTS trg_lancamentos_comum_insert
BEFORE INSERT ON lancamentos
FOR EACH ROW
WHEN NEW.tipo = 'comum'
BEGIN
    SELECT RAISE(ABORT, 'Lançamento comum exige conta_id, categoria_id e sentido')
    WHERE NEW.conta_id IS NULL OR NEW.categoria_id IS NULL OR NEW.sentido IS NULL;
    SELECT RAISE(ABORT, 'Lançamento comum não pode ter conta_origem_id, conta_destino_id ou descricao')
    WHERE NEW.conta_origem_id IS NOT NULL OR NEW.conta_destino_id IS NOT NULL OR NEW.descricao IS NOT NULL;
END;

CREATE TRIGGER IF NOT EXISTS trg_lancamentos_comum_update
BEFORE UPDATE ON lancamentos
FOR EACH ROW
WHEN NEW.tipo = 'comum'
BEGIN
    SELECT RAISE(ABORT, 'Lançamento comum exige conta_id, categoria_id e sentido')
    WHERE NEW.conta_id IS NULL OR NEW.categoria_id IS NULL OR NEW.sentido IS NULL;
    SELECT RAISE(ABORT, 'Lançamento comum não pode ter conta_origem_id, conta_destino_id ou descricao')
    WHERE NEW.conta_origem_id IS NOT NULL OR NEW.conta_destino_id IS NOT NULL OR NEW.descricao IS NOT NULL;
END;

-- -------- ajuste --------
CREATE TRIGGER IF NOT EXISTS trg_lancamentos_ajuste_insert
BEFORE INSERT ON lancamentos
FOR EACH ROW
WHEN NEW.tipo = 'ajuste'
BEGIN
    SELECT RAISE(ABORT, 'Ajuste exige conta_id, sentido e descricao')
    WHERE NEW.conta_id IS NULL OR NEW.sentido IS NULL
       OR NEW.descricao IS NULL OR TRIM(NEW.descricao) = '';
    SELECT RAISE(ABORT, 'Ajuste não pode ter categoria_id, conta_origem_id ou conta_destino_id')
    WHERE NEW.categoria_id IS NOT NULL
       OR NEW.conta_origem_id IS NOT NULL
       OR NEW.conta_destino_id IS NOT NULL;
END;

CREATE TRIGGER IF NOT EXISTS trg_lancamentos_ajuste_update
BEFORE UPDATE ON lancamentos
FOR EACH ROW
WHEN NEW.tipo = 'ajuste'
BEGIN
    SELECT RAISE(ABORT, 'Ajuste exige conta_id, sentido e descricao')
    WHERE NEW.conta_id IS NULL OR NEW.sentido IS NULL
       OR NEW.descricao IS NULL OR TRIM(NEW.descricao) = '';
    SELECT RAISE(ABORT, 'Ajuste não pode ter categoria_id, conta_origem_id ou conta_destino_id')
    WHERE NEW.categoria_id IS NOT NULL
       OR NEW.conta_origem_id IS NOT NULL
       OR NEW.conta_destino_id IS NOT NULL;
END;

-- -------- transferencia --------
CREATE TRIGGER IF NOT EXISTS trg_lancamentos_transferencia_insert
BEFORE INSERT ON lancamentos
FOR EACH ROW
WHEN NEW.tipo = 'transferencia'
BEGIN
    SELECT RAISE(ABORT, 'Transferência exige conta_origem_id e conta_destino_id')
    WHERE NEW.conta_origem_id IS NULL OR NEW.conta_destino_id IS NULL;
    SELECT RAISE(ABORT, 'Transferência não pode ter conta_id, categoria_id, sentido ou descricao')
    WHERE NEW.conta_id IS NOT NULL
       OR NEW.categoria_id IS NOT NULL
       OR NEW.sentido IS NOT NULL
       OR NEW.descricao IS NOT NULL;
    SELECT RAISE(ABORT, 'Origem e destino não podem ser a mesma conta')
    WHERE NEW.conta_origem_id = NEW.conta_destino_id;
END;

CREATE TRIGGER IF NOT EXISTS trg_lancamentos_transferencia_update
BEFORE UPDATE ON lancamentos
FOR EACH ROW
WHEN NEW.tipo = 'transferencia'
BEGIN
    SELECT RAISE(ABORT, 'Transferência exige conta_origem_id e conta_destino_id')
    WHERE NEW.conta_origem_id IS NULL OR NEW.conta_destino_id IS NULL;
    SELECT RAISE(ABORT, 'Transferência não pode ter conta_id, categoria_id, sentido ou descricao')
    WHERE NEW.conta_id IS NOT NULL
       OR NEW.categoria_id IS NOT NULL
       OR NEW.sentido IS NOT NULL
       OR NEW.descricao IS NOT NULL;
    SELECT RAISE(ABORT, 'Origem e destino não podem ser a mesma conta')
    WHERE NEW.conta_origem_id = NEW.conta_destino_id;
END;

-- =============================================================================
-- Observação: o campo `atualizado_em` é gerenciado pela camada de aplicação
-- (EF Core) em cada SaveChanges. Triggers no SQLite para isso são frágeis
-- (loop infinito em BEFORE UPDATE), então deixamos a regra na aplicação.
-- =============================================================================
