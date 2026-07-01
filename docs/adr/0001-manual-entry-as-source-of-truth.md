# Manual entry as source of truth; PDV is independent in v1

O mercadinho já roda um PDV (Ponto de Venda) em .NET WinForms com MySQL, que registra vendas, despesas e caixas. Decidimos que o app novo de fluxo de caixa **não integra com o PDV na v1**: o usuário digita manualmente os resumos diários, e o PDV continua sendo operado em paralelo. A motivação é que o caixa físico do PDV já apresentou divergências entre o valor esperado e o valor efetivamente recebido, então o usuário prefere re-confirmar os valores manualmente no app novo em vez de confiar no espelho do PDV.

A integração com o PDV (leitura de `tb_boletos` para exibir boletos em aberto, por exemplo) é trabalho de v2, registrada como follow-up.

**Consequência para o modelo de dados:** não há referências cruzadas, chaves estrangeiras nem jobs de sincronização entre o banco do app novo e o `db_pvd`. Os dois sistemas podem ser operados, versionados e backupados de forma totalmente independente. O `AGENTS.md` do app novo não menciona o PDV.
