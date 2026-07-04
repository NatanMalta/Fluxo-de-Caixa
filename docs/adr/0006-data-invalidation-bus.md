# Per-data invalidation bus for cross-screen state propagation

A camada de dados do app é estritamente HTTP: cada tela chama `ApiClient.listarX()` no `initState` e guarda o `Future` resultante em um campo `late Future<X> _futureX` que o `FutureBuilder` consome. Refetch manual é feito por métodos públicos das telas (`atualizar`, `_carregar`, `_recalcular`) chamados pelo próprio usuário (botão de refresh, pull-to-refresh) ou por uma única ponte entre tabs (ver ADR 0004).

Esse modelo funcionou enquanto a única ponte cross-screen era a volta da aba **Lançar (1)** para a aba **Início (0)** — o `HomeScreen` chamava `Dashboard.atualizar()` e só. A partir do momento em que a edição em qualquer tela precisa refletir em qualquer outra (Conta nova cadastrada em **Config** deve aparecer no dropdown de **Lançar**; Lançamento criado em **Lançar** deve mudar os totais de **Balanço**; Categoria renomeada em **Config** deve atualizar a quebra por categoria em **Balanço** e o widget de últimos lançamentos no **Dashboard**), a ponte atual cobre só uma das 12 transições possíveis entre as 4 abas e silenciosamente deixa o resto stale.

## Decision

Adicionamos um barramento de invalidação por tipo de dado, com 4 `ValueNotifier<int>` morando em uma classe estática `DataInvalidator` em `lib/services/data_invalidator.dart`. As telas ouvem os notifiers relevantes via `ListenableBuilder` envolvendo o `FutureBuilder` (não `addListener`/`setState`); mutações chamam `value++` no notifier apropriado **depois** do `await` da chamada HTTP ter sucesso.

### Os 4 notifiers

```dart
class DataInvalidator {
  static final ValueNotifier<int> contas = ValueNotifier<int>(0);
  static final ValueNotifier<int> categorias = ValueNotifier<int>(0);
  static final ValueNotifier<int> lancamentos = ValueNotifier<int>(0);
  static final ValueNotifier<int> balanco = ValueNotifier<int>(0);
}
```

A escolha de classe estática é consistente com o estilo do `ApiClient` (que também é uma classe de métodos estáticos) e evita prop drilling através dos construtores das 4 telas (ver ADR 0004 para a regra "setState for v1"). O custo de "menos testável por ser global" não pesa nesta v1 porque o app não tem testes de unidade ainda e não há troca dinâmica do barramento em runtime.

### Listeners por tela

| Tela | Notifiers ouvidos |
|------|-------------------|
| `DashboardScreen` | `contas`, `lancamentos` |
| `LancarScreen` | `contas`, `categorias`, `lancamentos` |
| `BalancoScreen` | `balanco` |
| `ConfigScreen` | (nenhum — ela só muta e refaz o próprio `_carregar`) |

Padrão de wiring, substituindo o `late Future` que existia:

```dart
// Antes
late Future<List<Conta>> _futureContas;
@override
void initState() {
  super.initState();
  _futureContas = ApiClient.listarContas();
}
// ...
return FutureBuilder<List<Conta>>(future: _futureContas, builder: ...);

// Depois
return ListenableBuilder(
  listenable: DataInvalidator.contas,
  builder: (ctx, _) => FutureBuilder<List<Conta>>(
    future: ApiClient.listarContas(),
    builder: ...,
  ),
);
```

`ListenableBuilder` é o widget correto (não `ValueListenableBuilder`): ele reconstrói quando o `Listenable` notifica, e o `_` no segundo parâmetro do builder deixa explícito que o valor do contador é irrelevante — só o evento importa. O `Future` é recriado a cada notificação, exatamente como o `atualizar()` faz hoje.

### Tabela de bumps por mutação

A mutação acontece na **tela onde o usuário está**, e essa tela é quem sabe o que bump-ar. O bump vai **depois** do `await` bem-sucedido — falha de API não invalida nada.

| Mutação | Counters a incrementar |
|---------|------------------------|
| Conta criar/editar/excluir (em Config) | `contas`, `balanco` |
| Categoria criar/editar/excluir (em Config) | `categorias`, `balanco`, `lancamentos` |
| Lançamento criar/editar/excluir (em Lançar) | `lancamentos`, `balanco` |

Justificativas não-óbvias:

- **Conta bumpa `balanco`** porque `saldosPorConta` e `saldoTotal` no Balanço derivam de Conta.
- **Categoria bumpa `lancamentos`** porque Dashboard e Lançar exibem `categoriaNome` joined em cada Lançamento (vem do backend na resposta de `GET /api/Lancamentos`). Renomear uma Categoria exige refetch da lista de Lançamentos para o nome joined atualizar.
- **Lançamento bumpa `balanco`** porque totais, resultado e saldo de período derivam de Lançamentos.
- **Quase tudo bumpa `balanco`**: é a tela que mais depende de dados derivados.

## Consequences

- **Propagação universal.** Qualquer mutação em qualquer tela invalida tudo que depende dela em todas as outras, sem o shell precisar conhecer o nome dos métodos das filhas. O `HomeScreen` perde o observador de troca de aba do ADR 0004 (vira código morto), mas o `GlobalKey<LancarScreenState>` e a callback `onTapLancamento` continuam valendo — eles cuidam de uma direção diferente (saltar para a aba Lançar com o form pré-preenchido), não de refresh.
- **Sem nova dependência.** Continua no envelope "setState for v1" do `AGENTS.md`. Não precisa de Provider, Riverpod, Bloc, MobX, etc.
- **Esquecer um bump = tela stale silenciosamente.** É o ônus real deste modelo. Mitigação: a tabela de bumps acima vira seção de teste manual no `AGENTS.md` ("para cada linha da tabela, abra a tela X, faça a mutação, abra a tela Y, confirme que o dado mudou"). São 9 cenários. Aceitável para v1, insustentável se o app passar de ~20 call-sites de mutação.
- **O `ListenableBuilder` recria o `Future` em todo rebuild, mesmo quando o notifier ainda não mudou.** Isso é equivalente ao `atualizar()` atual (que também recria o `Future` em todo `setState`) — não há regressão de comportamento. O custo extra é zero, porque o `Future` é só um handle para um `Task` em voo, não o corpo da resposta.
- **Estado de formulário mid-edit.** Se uma Conta for excluída em **Config** enquanto o usuário está com o form de Lançar pré-preenchido com aquela Conta selecionada, o `ListenableBuilder` re-fira, refaz o `Future` de Contas, e o `DropdownButtonFormField` renderiza com a lista nova; a `_contaId` (que está em `State`) é preservada, mas o dropdown não consegue exibir um item que não existe mais — ele mostra `null` na seleção. Validação subsequente falha com "Escolha a conta." Comportamento correto, e na v1 isso só acontece via edição externa ou multi-device, que o usuário declarou fora de escopo.
- **IndexedStack continua montando as 4 telas.** Telas inaudíveis reagem a bumps da mesma forma; no pior caso, gastam um round-trip HTTP extra por mutação. Em LAN local com 4 telas e 5–20 itens por lista, isso é ruído.

## Alternatives considered

- **Expandir o `GlobalKey` + observador de troca de aba (status quo, escalado).** Cobriria as 12 transições com 4 chaves e 12 cláusulas `if`. A própria ADR 0004 diz que com 3+ chaves "o custo de 'uma GlobalKey por filho' para de pagar". Chegamos a 4 chaves sem entrar no mérito do que cada uma faz.
- **Subir os dados para o shell (`HomeScreen`).** As telas receberiam listas via construtor e emitiriam callbacks; o shell refaz o fetch e reempurra. É o caminho "puro" de Flutter, mas exigiria refatorar as 4 telas (saindo de `FutureBuilder` para `ListView.builder` puro) e o shell passaria a ser dono de 4–5 listas + 4 `setState` orchestration. Mais correto arquiteturalmente, mas é exatamente o padrão que Provider/Riverpod resolve com menos cerimônia — preferimos não pagar essa conta agora e revisitarmos se o app crescer.
- **Polling (`Timer.periodic` em cada tela).** Zero coordenação, mas gasta requisições mesmo quando nada mudou e fica até N segundos atrás de uma edição. Em LAN com o dataset pequeno, a ineficiência é desprezível; a falta de determinismo ("mudei e não atualizou") não compensa.
- **Provider/Riverpod.** Resolve o problema geral de estado, mas o `AGENTS.md` adia explicitamente para depois da v1, e trazer para resolver um problema que dá para resolver com 30 linhas de barramento estático é desproporcional.

## When to revisit

- Se o app passar de ~20 call-sites de mutação, o risco de "esqueci o bump" domina. Subir para um estado gerenciado (Provider scoped) vira a alternativa real, e esta ADR vira o motivo de por que esperamos.
- Se o app passar a rodar em mais de um dispositivo com edições concorrentes, polling com backoff sobre o `etag`/`Last-Modified` das listas do backend vira o complemento natural — o `DataInvalidator` continuaria sendo o hub, mas com bumps vindos do servidor (long-polling, SSE) em vez de vir da própria UI.
- Se uma das 4 telas for removida ou fundida (ex.: Dashboard e Balanço virarem uma), o `balanco` notifier vira candidato a ser absorvido por um dos outros três, e esta ADR vira a justificativa do porquê ele existia.
