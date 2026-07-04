namespace FluxoCaixa.Api.Dtos;

/// Body do `POST /api/auth/login`. O PIN é numérico curto (4-6 dígitos),
/// validado no `AuthController` antes de chamar o `TokenService`.
public record LoginRequest(string Pin);

/// Resposta do login bem-sucedido. O frontend guarda o `token` em
/// memória no `ApiClient` e usa `expiresAt` apenas para telemetria
/// (a verificação real da expiração fica a cargo do JWT bearer
/// middleware no backend).
public record LoginResponse(string Token, DateTime ExpiresAt);
