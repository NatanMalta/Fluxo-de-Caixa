# Contas section: in-memory substring filter on `nome` with a child widget owning the controller; no debounce, no isolate, no accent normalization

A aba de Contas (`_SecaoContas` em `config_screen.dart`) é uma lista curta (5-20 contas típicas de um mercadinho) e precisava de busca local por nome. O usuário pediu que a busca fosse "extremamente performática", e o receio concreto era consumo de RAM no Android — o app roda num device com RAM limitada. O diagnóstico: com 5-20 itens, o **filtro** em si é invisível para RAM (kilobytes, não megabytes); o que **realmente** consome é a **árvore de widgets** renderizada, não os dados filtrados.

## Decision

A busca é **inteiramente no front, em memória**, sobre a lista que o `FutureBuilder` já carregou. Critério: `nome.toLowerCase().contains(query.toLowerCase())` — `contains`, case-insensitive, acento-sensível, apenas no campo `nome`. Sem endpoint novo no backend.

A arquitetura segue o princípio de **rebuild isolado**: o `TextEditingController` mora em um `StatefulWidget` filho extraído (`_ContasList`), criado em `initState` e descartado em `dispose`. O card pai (`_SecaoContas`) continua `StatelessWidget` e não é notificado das mudanças do campo. A lista filtrada e o `TextField` ficam dentro de um `ValueListenableBuilder<TextEditingValue>` escutando o controller — só esse subárvore reconstrói a cada keystroke. O título "Contas" e o botão "Nova" ficam intactos durante a digitação.

A lista renderizada troca de `Column(... .map().toList())` (que constrói um `ListTile` para **cada** conta, mesmo fora da tela) para `ListView.builder(shrinkWrap: true, physics: NeverScrollableScrollPhysics(), itemExtent: 56, ...)`. O `itemExtent` informa a altura fixa do `ListTile` para o framework, pulando o cálculo de layout por item e mantendo a virtualização ativa.

UX do campo: dentro do card, entre o título e a lista. Sem `autofocus` (teclado cobriria metade da tela no celular). `suffixIcon` com `IconButton(Icons.close)` que aparece **apenas** quando o controller tem texto, dando ao usuário uma saída óbvia para limpar. Dois empty states distintos: `"Nenhuma conta cadastrada."` (lista realmente vazia) vs `"Nenhuma conta encontrada para '<termo>'."` (filtro sem matches). O termo persiste entre recarregamentos da lista (pull-to-refresh, criar/editar conta) — o `State` do `_ContasList` sobrevive ao rebuild do `FutureBuilder`, então a persistência vem "de graça".

**Explicitamente fora de escopo**, por serem otimização prematura ou feature creep a essa escala:

- **Sem debounce.** Filtrar 20 strings leva microssegundos. Debounce de 150-250ms adicionaria latência perceptível e faria a UI parecer menos snappy, não mais.
- **Sem `compute()` / `Isolate.run`.** O custo de serialização entre isolates domina qualquer ganho em `String.contains` sobre 5-20 strings.
- **Sem busca por `tipo` (banco/espécie).** Se virar requisito, deve ser um `FilterChip` explícito, não string mágica dentro do mesmo campo de busca.
- **Sem normalização de acentos** — "especie" não casa com "Espécie". Decidido conscientemente.
- **Sem fuzzy match, sem histórico de buscas, sem atalhos de teclado, sem analytics.**

## Alternatives considered

- **`setState` no card pai a cada keystroke.** Mais curto, mas reconstrói o `Card` inteiro (incluindo título "Contas" e botão "Nova") a cada tecla. Desperdício real de trabalho, mesmo sendo rápido no wall clock.
- **Debounce de 150-250ms.** Padrão de tutoriais, mas a latência adicionada é pior que o trabalho economizado a 5-20 itens. Usuário sentiria como "travado", não como "performático".
- **`compute()` ou `Isolate.run` para o filtro.** Justificável para listas grandes ou filtros caros (regex, busca fonética). Para `String.contains` em 5-20 strings, o custo de serialização supera o ganho em várias ordens de grandeza.
- **Filtrar no backend via query string.** Round-trip HTTP a cada keystroke. Pior em latência, carga no servidor e comportamento offline. Só faria sentido se a lista fosse grande demais para caber no front, o que não é o caso.
- **Manter `Column.map.toList()`.** A 5-20 itens é invisível, mas é exatamente o caminho que estoura a árvore de widgets se a lista crescer. Trocar agora é barato; esperar pra trocar é caro.
- **Estado global (`ChangeNotifier` / `Provider`).** Exagero para um campo de busca local. Só vale se a busca for compartilhada entre telas, o que não é o caso.

## Consequences

- **Zero dependência nova.** Apenas `flutter/material` e `dart:core`.
- **Termo de busca persiste "de graça"** entre `setState` no pai, pull-to-refresh, criar e editar contas — comportamento que o usuário espera de qualquer campo de busca.
- **Árvore de widgets virtualizada** porque a `ConfigScreen` mora dentro de um `ListView` vertical (o `body` da `Scaffold`). Itens fora do viewport não são construídos, independente do tamanho da lista.
- **Custo por keystroke: O(N) sobre 5-20 strings.** Não há nada para otimizar a essa escala.
- **Backend intocado.** Sem rota nova, sem DTO, sem migration. O ADR é puramente frontend.
- **Acoplamento mínimo.** `_ContasList` recebe `List<Conta>` por construtor e não conhece o `FutureBuilder`, o `_carregar()`, nem o `_abrirDialogConta`. O card pai também não conhece o controller.

## When to revisit

- **Se a lista passar de ~200 contas** (improvável para um mercadinho, mas o mesmo padrão pode ser reaproveitado em outras telas com volumes maiores), considerar pré-computar um índice por token (ex: `Map<String, List<Conta>>`) para evitar varrer a lista inteira a cada keystroke.
- **Se o filtro ganhar critérios não-textuais** (tipo, faixa de saldo, "só inativas"), o `TextField` sozinho não basta. A UI provavelmente migra para `SearchAnchor` (Material 3) com facets, ou para um sheet de filtros explícitos. Nessa altura o widget atual ainda serve como ponto de partida, mas a forma muda.
- **Se a busca virar requisito de outra tela** (ex: buscar Categoria na seção correspondente), extrair um `_SearchableList<T>` genérico. Hoje é cedo — YAGNI.
- **Se o usuário relatar jank perceptível ao digitar** (improvável, mas vale medir), rodar com `flutter run --profile` + DevTools antes de assumir que está tudo bem. O primeiro suspeito é o `ListView.builder` não virtualizando como esperado; o segundo é o `FutureBuilder` reconstruindo mais do que deveria.
