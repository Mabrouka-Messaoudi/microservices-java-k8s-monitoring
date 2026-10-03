import { PassedInitialConfig } from 'angular-auth-oidc-client';

const env = (window as any).__ENV__ || {};
const keycloakUrl = env.KEYCLOAK_URL || 'http://localhost:30818';
const apiGatewayUrl = env.API_GATEWAY_URL || 'http://localhost:30900';

export const authConfig: PassedInitialConfig = {
  config: {
    authority: `${keycloakUrl}/realms/spring-microservices-security-realm`,
    redirectUrl: window.location.origin,
    postLogoutRedirectUri: window.location.origin,
    clientId: 'angular-client',
    scope: 'openid profile email offline_access',
    responseType: 'code',
    silentRenew: false,
    useRefreshToken: true,
    ignoreNonceAfterRefresh: true,
    secureRoutes: [apiGatewayUrl],
    disablePkce: false,

    // Limite connue : la validation de l'ID token est désactivée pour contourner une
    // incohérence du claim « sub » avec Keycloak accessible en HTTP sur NodePort.
    // En production : activer HTTPS partout (Keycloak inclus) et supprimer ces deux options.
    disableIdTokenValidation: true,
    allowUnsafeReuseRefreshToken: true,

    triggerAuthorizationResultEvent: true,
    customParamsAuthRequest: {
      prompt: 'login'
    }
  }
};
