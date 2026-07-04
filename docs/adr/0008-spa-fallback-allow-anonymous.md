# SPA fallback to file requires explicit AllowAnonymous under global auth

A política global `FallbackPolicy = RequireAuthenticatedUser()` (ADR 0007) se aplica a **todo** endpoint que não declara uma política própria. O SPA fallback do Kestrel — `MapFallbackToFile("index.html")` — registra um endpoint que match qualquer path não tratado, incluindo os deep links que o Flutter Router espera (`/lancar`, `/balanco`, `/config`). Sem `.AllowAnonymous()` explícito nesse endpoint, o `AuthorizationMiddleware` aplica a política fallback e retorna 401 em todo deep link, deixando o usuário com "401 Unauthorized" no browser em vez da tela de PIN.

Isso foi descoberto em produção quando o Flutter web foi adicionado ao mesmo pipeline do Kestrel: as probes de deep link (`GET /lancar`, `GET /balanco`) voltavam 401, enquanto o `GET /` estático voltava 200. A tela de PIN nunca aparecia, então o usuário não conseguia logar.

## Decision

Marcar o SPA fallback como anônimo:

```csharp
app.MapFallbackToFile("index.html").AllowAnonymous();
```

O `.AllowAnonymous()` adiciona o `AllowAnonymousAttribute` ao metadata do endpoint, que o `AuthorizationMiddleware` checa **antes** de aplicar qualquer política (incluindo a fallback). O handler então roda, serve `index.html`, o Flutter app boota e o Router assume.

O pattern default do `MapFallbackToFile` é `"{*path:nonfile}"`, que rejeita paths com extensão de arquivo. Isso é aceitável no caso atual porque a SPA só navega para paths como `/lancar`, `/balanco` (sem extensão). Requests para paths com extensão que não existem em `wwwroot/` caem no caminho 404/401; isso é aceitável porque o Flutter app não gera essas requests e o comportamento catch-all da SPA não é afetado.

## Consequences

- O `.AllowAnonymous()` no fallback é **a única linha que distingue "deep links funcionam" de "deep links retornam 401"**. Removê-lo quebra silenciosamente toda a navegação da SPA.
- O bloco de comentário em `Program.cs` acima de `MapFallbackToFile(...).AllowAnonymous()` documenta isso. Qualquer PR futuro que toque nessa linha deve preservar tanto a chamada quanto o comentário.
- Os endpoints `/api/*` continuam protegidos pela política global. Eles têm metadata próprio nos controllers e não matcham o `{*path:nonfile}`, então o fallback não está no caminho de avaliação deles.
- Se uma feature futura precisar de endpoint público adicional (ex.: um `/health` para os scripts de deploy fazerem ping), vai precisar do mesmo tratamento `.AllowAnonymous()`. O comentário deve ser atualizado ou generalizado.
- A constraint `:nonfile` do pattern default interage com o alias do `UseStaticFiles` descrito no ADR 0009. Os dois juntos definem o que serve como asset estático vs. o que cai no SPA fallback.

## Alternatives considered

- **Mover o serviço do frontend para um reverse proxy separado (nginx, IIS).** O frontend seria servido por um processo sem auth nenhuma, e só `/api/*` chegaria no Kestrel. Considerado e rejeitado: a arquitetura do AGENTS.md é "Kestrel único, sem servidor extra" (ver ADR 0002). Adicionar um reverse proxy dobra a superfície de deploy para um app LAN de usuário único.
- **Trocar a `FallbackPolicy` global por `[Authorize]` por controller.** Cada controller carregaria seu próprio `[Authorize]`, e o fallback não estaria sujeito a nenhuma política por default. Considerado e rejeitado: inverte a postura "default-deny" (todo controller novo tem que lembrar de adicionar `[Authorize]`, fácil de esquecer), e a política global atual é o default explícito e mais seguro. O custo do `.AllowAnonymous()` em um único endpoint público é menor que o custo de auditar cada controller novo.
- **Usar middleware que faz match em `/api/*` e pula a pipeline de auth para todo o resto.** A extensão `UseWhen` pode ramificar a pipeline por path. Considerado e rejeitado: esconde o modelo de segurança na ordem de middleware em vez de metadata de endpoint, que é mais difícil de raciocinar e mais fácil de quebrar ao adicionar rotas.

## When to revisit

- Se mais de 2 ou 3 endpoints precisarem ser públicos (ex.: um `/health`, um `/metrics`, um `/public-banner`), o padrão `AllowAnonymous()` começa a ficar repetitivo e uma branch de middleware por path pode ficar mais limpa. Nesse ponto, o trade-off vira.
- Se a política global for afrouxada (ex.: um esquema de auth por usuário), o `.AllowAnonymous()` no fallback vira redundante mas inofensivo. Vale deletar por clareza.
- Se o Flutter Router passar a gerar paths com extensão (ex.: `/lancar.json` para data fetching do server-side), a constraint `:nonfile` do fallback começa a rejeitar paths legítimos. Aí precisa migrar o pattern para `"{*path}"` (com `.AllowAnonymous()`) — e a interaction com o alias do ADR 0009 precisa ser revalidada.
