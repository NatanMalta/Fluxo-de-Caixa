# Daily summary granularity: one Lançamento per (date, conta, categoria)

A unidade atômica de registro é o **dia**, não a transação. Um Lançamento Comum corresponde à tupla `(data, conta, categoria, valor)`. Em outras palavras, se o mercadinho fizer 200 vendas em dinheiro no dia 05/07, isso vira **um único Lançamento** "Vendas em dinheiro: R$ 800" — não 200 linhas.

**Por que essa escolha:** digitar cada venda individualmente é inviável para o usuário (centenas de vendas por dia). O que importa para o fluxo de caixa é o **total apurado no fim do dia** por Conta e Categoria, e é isso que o usuário registra. Vendas individuais continuam existindo no PDV, fora do app novo.

**Consequência para o modelo de dados:** a tabela `lancamentos` é enxuta — espera-se um volume baixo de linhas (dezenas a centenas por mês, não milhares por dia). Não há `id_venda`, `id_produto` ou `quantidade` em Lançamento. A noção de "linha de venda" pertence ao PDV.

**Consequência para a UI:** a tela de cadastro é um formulário por dia (não por venda), com a possibilidade de adicionar várias linhas (uma por Categoria por Conta) no mesmo envio. O Balanço agrega por dia, mês e ano — não por venda.

**Relação com Transferência e Ajuste:** Transferência (entre duas Contas) e Ajuste (correção) seguem a mesma lógica — uma linha por ocorrência, não por evento atômico. Eles não têm Categoria, mas continuam respeitando a granularidade diária: o usuário registra uma Transferência "Caixa → Nubank, R$ 300" como uma única linha com a data em que o dinheiro foi transferido.
