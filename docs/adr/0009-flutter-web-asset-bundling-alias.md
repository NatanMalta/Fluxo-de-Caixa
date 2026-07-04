# Flutter web bundles pubspec assets under `<webroot>/assets/assets/` but the runtime fetches them from `/assets/`

Quando `assets/config.json` é declarado em `pubspec.yaml` sob `flutter.assets`, o build do Flutter web (`flutter build web`) produz um `AssetManifest.bin` descrevendo o asset, e coloca o conteúdo do arquivo em `<webroot>/assets/assets/config.json` — note o segmento `assets/` **duplicado**. O `AssetManifest.bin` declara o asset como `assets/config.json` e diz para o runtime fazer fetch a partir da URL `/assets/config.json` (sem duplicação).

O middleware default `app.UseStaticFiles()` mapeia paths de request para `<webroot>/<path>`. Ele procura `wwwroot/assets/config.json`, que **não existe** (o arquivo está em `wwwroot/assets/assets/config.json`). A request erra, e o `MapFallbackToFile` normalmente pegaria — mas o pattern default dele é `"{*path:nonfile}"`, e a constraint `:nonfile` rejeita paths com extensão de arquivo (`.json`). Então o fallback não match, nenhum endpoint é selecionado, e a `FallbackPolicy = RequireAuthenticatedUser()` global (ADR 0007 + 0008) retorna 401.

No fluxo do `ApiClient.init()`, esse 401 é engolido pelo `try/catch` existente, deixando `_loadedBaseUrl = null` e caindo no default `http://localhost:5000`. O login então POSTa para localhost (que no browser do usuário é a própria máquina dele, não o servidor), e o HTTP client do Flutter surface "could not connect to server". O usuário vê a tela de PIN corretamente (ela não depende do `baseUrl`), mas não consegue passar dela.

Isso foi descoberto em produção quando a mesma máquina tentou acessar o serviço de uma rede Tailscale: o usuário mudou o `config.json` para o IP Tailscale, rebuildou o Flutter app, e o login ainda falhou com "could not connect to server". O login na LAN funcionava porque a mesma máquina usava `http://192.168.1.105:5000` e o bundle também tinha esse IP — ambos apontavam para um endereço alcançável. O caso Tailscale tornou a configuração visível: o IP no bundle estava certo, a URL que o Flutter app realmente estava usando é que não estava.

## Decision

Adicionar um segundo `UseStaticFiles` no `Program.cs`, **antes** do default, que mapeia o prefixo de URL `/assets/` para o diretório duplicado `<webroot>/assets/assets/` no disco:

```csharp
app.UseStaticFiles(new StaticFileOptions
{
    FileProvider = new PhysicalFileProvider(
        Path.Combine(builder.Environment.WebRootPath, "assets", "assets")),
    RequestPath = "/assets",
});
app.UseStaticFiles();
```

A ordem importa: o alias precisa rodar primeiro para que `GET /assets/config.json` resolva para o arquivo bundleado pelo Flutter antes do middleware default ter a chance de procurar `wwwroot/assets/config.json` (que não existe). O `UseStaticFiles` default continua tratando todos os outros paths, incluindo `/assets/AssetManifest.bin` (que vive em `<webroot>/assets/AssetManifest.bin`, um nível acima do diretório duplicado).

Qualquer asset futuro declarado em `pubspec.yaml` é servido automaticamente por este alias, sem mudanças no `Program.cs`.

## Consequences

- Dois middlewares `UseStaticFiles` na pipeline. A duplicação é intencional, não é oportunidade de refactor.
- O bloco de comentário em `Program.cs` documenta o quirk do Flutter web, a interação com `:nonfile`, e a cascata que leva o usuário para `localhost:5000` se o alias sumir. PRs futuros que toquem nessa linha devem preservar tanto a chamada quanto o comentário.
- `MapFallbackToFile` continua na pipeline (com `.AllowAnonymous()`) tratando deep links da SPA. Os dois `UseStaticFiles` mais o fallback cobrem os três casos: arquivo estático conhecido, asset do pubspec, deep link para uma rota do Flutter Router.
- A convenção de bundling do Flutter web é um **comportamento do Flutter SDK, não uma escolha do projeto**. Não há mudança em `pubspec.yaml` que faça o Flutter colocar o asset em `<webroot>/assets/config.json` em vez de `<webroot>/assets/assets/config.json`. O alias server-side é a única solução estável.

## Alternatives considered

- **Declarar o asset em `pubspec.yaml` sem o prefixo `assets/`** (ex.: `- config.json` com o arquivo em `frontend/config.json`). Isso mudaria a localização do bundle para `<webroot>/config.json`, e o runtime faria fetch de `/config.json`, que o `UseStaticFiles` default já serve. Considerado e rejeitado: exige mover o arquivo para fora de `frontend/assets/`, o que quebra a convenção do projeto de "todos os recursos bundleados vivem em `frontend/assets/`". Além disso, o `ApiClient` precisaria ser atualizado para `rootBundle.loadString('config.json')`, que é uma chave menos óbvia.
- **Servir o arquivo via um endpoint dedicado** (ex.: `GET /api/config` retornando o conteúdo JSON). O `ApiClient.init()` faria fetch de lá em vez de `rootBundle`. Considerado e rejeitado: faz da configuração uma preocupação de API, o que ela não é. O config é um asset build-time do Flutter web app, e `rootBundle` é o lugar certo para carregá-lo. Adicionar um endpoint para fazer bridge de um quirk de bundling do Flutter web inverte o layering.
- **URL rewrite no nível do static-files** (ex.: uma regra que mapeia `/assets/config.json` para o arquivo `assets/assets/config.json`). Efetivamente a mesma coisa que o alias, mas menos explícita. Considerado e rejeitado: o `UseStaticFiles` com `RequestPath` é mais descobrível e o bloco de comentário explica o porquê em um lugar só.
- **Trocar a policy do fallback** (`MapFallbackToFile(...).AllowAnonymous()`) para usar `"{*path}"` em vez do default `"{*path:nonfile}"`, para que paths com extensão caiam no fallback e o Flutter app receba `index.html` para eles. Considerado e rejeitado: o Flutter app espera JSON, não HTML, para `/assets/config.json`. Retornar HTML causaria falha de parse no `ApiClient.init()` e a mesma queda para localhost. A constraint `:nonfile` fica.

## When to revisit

- Se o Flutter SDK mudar a convenção de bundling de assets (ex.: para um layout plano `<webroot>/<asset_path>`). O alias vira redundante e deve ser removido; o comentário em `Program.cs` deve ser atualizado para registrar a mudança.
- Se adicionarmos assets que precisam burlar o diretório duplicado (ex.: um `index.html` customizado). O `UseDefaultFiles()` atual já trata `index.html` em `<webroot>/index.html`; esse path não é afetado pelo alias. Nenhuma mudança necessária a menos que o layout mude.
- Se migrarmos o output do Flutter web build para um CDN ou host externo de arquivos estáticos. O alias vira responsabilidade do CDN, e o `Program.cs` fica só com a API. Nesse ponto, o invariante "Kestrel serve o frontend" (AGENTS.md) quebra e deve ser revisitado no nível da arquitetura, não só desta ADR.
