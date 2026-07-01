# Fluxo de Caixa do Mercadinho

Aplicativo web/mobile em Flutter para registro e visualização do fluxo de caixa de um único mercadinho. Roda em servidor local dentro da loja, acessado pelo dono via Wi-Fi. Entrada de dados é 100% manual — o PDV legado é um sistema independente, sem integração na v1.

## Language

**PDV (Ponto de Venda)**:
Sistema legado em .NET WinForms com banco MySQL `db_pvd` (porta 3307). Mantém o registro de vendas, produtos, clientes, fornecedores, boletos e pendências de fiado. **Não tem integração com o app novo na v1.** O dono continua usando o PDV para o caixa do dia-a-dia, e usa o app novo como livro-caixa pessoal. Integração (leitura de boletos, por exemplo) é trabalho de v2.
_Avoid_: "sistema antigo", "sistema legado" (soa depreciativo), "PDV do Natan" (acoplado a uma pessoa).

**Boleto**:
Título de cobrança emitido por fornecedor, com data de vencimento, valor e código de barras. Existe na `tb_boletos` do PDV. Na v1, o dono consulta boletos direto no PDV — o app novo não tem tela de boletos. Quando a integração com o PDV entrar (v2+), boletos passarão a ser leitura do PDV exibida no app novo.
_Avoid_: "conta a pagar" (conceito mais amplo, inclui outras obrigações), "boleto bancário" (redundante).

**Pendência**:
Dívida de cliente (fiado) registrada no PDV a partir de uma venda a prazo. Tem valor restante, status e referencia a venda original. Existe na `tb_pendencia` do PDV. **Não usada na v1 do app novo** — o dono acompanha fiado no PDV. Candidato a integração futura.

**Conta**:
Qualquer lugar onde o mercadinho guarda dinheiro. Pode ser conta-corrente bancária, poupança, conta digital (Nubank, Inter etc.) ou dinheiro em espécie (caixa físico da loja). Cada Conta tem um nome, um tipo (banco / espécie), um `saldo_inicial` definido pelo dono no cadastro, e seu saldo corrente é derivado dos Lançamentos. O dono pode cadastrar quantas Contas quiser.
_Avoid_: "carteira" (pessoal, não de negócio), "conta contábil" (linguagem de contabilidade formal), "caixa" sozinho (ambíguo: pode significar o PDV ou o dinheiro em espécie).

**Lançamento**:
Registro de uma movimentação de dinheiro com data, valor e regras específicas conforme o tipo. Todo Lançamento afeta o saldo de uma ou duas Contas. Existem três tipos:

- **Lançamento Comum** — entrada ou saída de dinheiro em uma única Conta, classificada por uma Categoria. É o Lançamento do dia-a-dia ("vendas em dinheiro: R$ 480" no Caixa, "boleto pago: R$ 150" na Nubank).
- **Ajuste** — correção do saldo de uma Conta. Não tem Categoria; tem descrição livre. Serve para casos em que o valor real diverge do que está nos Lançamentos (esquecimento, tarifa bancária, rendimento, IOF, contagem errada do caixa).
- **Transferência** — movimentação de dinheiro entre duas Contas do dono (origem → destino). Não conta como entrada nem saída do negócio: aumenta o saldo do destino e diminui o saldo da origem pelo mesmo valor. Os totais de Entradas e Saídas do Balanço ignoram Transferências.

A periodicidade é diária: vários Lançamentos por dia são esperados (um por Categoria por Conta é o limite "natural", mas não há bloqueio técnico). Vistas agregadas são feitas por mês e por ano.
_Avoid_: "transação" (remete a banco de dados), "movimentação" (mais usado pra conta bancária, confunde com Transferência), "lançamento contábil" (linguagem formal de contabilidade).

**Categoria**:
Rótulo definido pelo próprio dono para classificar a origem (Categoria de Entrada) ou o destino (Categoria de Saída) de um Lançamento Comum. Exemplos de Entrada: "Vendas em dinheiro", "Vendas em PIX", "Recebimento de fiado". Exemplos de Saída: "Pagamento de Boleto", "Compra de Fornecedor", "Aluguel", "Retirada do Dono". O dono cadastra, edita e remove suas próprias Categorias — o app não impõe uma lista fixa nem diferencia Entrada e Saída via modelo (são dois campos `tipo` na mesma tabela, e a UI filtra por contexto). Categorias são geridas pelo dono, não pelos funcionários do caixa.
_Avoid_: "tipo de receita/despesa" (linguagem contábil), "tag" (linguagem de banco de dados), "subcategoria" (implica hierarquia que não temos), "centro de custo" (linguagem empresarial).

**Saldo**:
Valor em dinheiro de uma Conta em um instante no tempo. Calculado em tempo de leitura como `saldo_inicial + soma(entradas) − soma(saídas) + soma(ajustes positivos) − soma(ajustes negativos) − soma(transferências saindo) + soma(transferências entrando)`. O `saldo_inicial` é fixado no cadastro da Conta e representa "quanto tinha nessa conta no dia em que comecei a usar o app". Saldos por dia, mês e ano são derivados — não há coluna `saldo` em lugar nenhum do banco.
_Avoid_: "saldo atual" (data-dependente, melhor dizer "saldo em DD/MM"), "saldo contábil" (linguagem formal), "balanço" (conceito diferente — ver adiante).

**Balanço**:
Tela de visualização que resume o estado financeiro em um período. Tem seletor de período (dia / mês / ano) e mostra: total de Entradas no período, total de Saídas, Resultado (Entradas − Saídas, sem contar Transferências), Saldo de cada Conta no fim do período, e detalhamento por Categoria (quais Categorias de Entrada trouxeram mais, quais Categorias de Saída pesaram mais). Filtros por Conta e por Categoria ficam disponíveis.
_Avoid_: "DRE" (linguagem contábil formal, fora do escopo), "fluxo de caixa" (sinônimo do app inteiro, não de uma tela), "relatório" (genérico demais).

**Loja**:
O mercadinho opera em **uma loja única**. Não há dimensão "loja" no modelo de dados — todas as Contas, Lançamentos, Ajustes e Categorias pertencem implicitamente a essa única loja. Se no futuro houver expansão, a dimensão Loja será adicionada como parte de uma migração de modelo, não como adaptação do schema atual.
_Avoid_: "filial" (sugere rede), "unidade" (linguagem de rede), "PDV" (sistema, não loja física).

**Usuário**:
A aplicação tem **um único usuário** — o dono do mercadinho. Não há tela de login, não há cadastro de usuários, não há papéis. O acesso é protegido opcionalmente por um PIN local no dispositivo (pra não abrir acidentalmente no celular), mas todos os dados são de uma única pessoa.
_Avoid_: "admin" (papel), "operador" (papel), "conta de usuário" (sugere múltiplos).
