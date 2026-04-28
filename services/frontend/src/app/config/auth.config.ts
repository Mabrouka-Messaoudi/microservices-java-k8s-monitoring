import { PassedInitialConfig } from 'angular-auth-oidc-client';

const env = (window as any).__ENV__ || {};
const keycloakUrl = env.KEYCLOAK_URL || 'http://192.168.100.113:30818';
const apiGatewayUrl = env.API_GATEWAY_URL || 'https://192.168.100.113:30200';

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

    // ✅ Fix authenticated: false causé par sub mismatch
    disableIdTokenValidation: true,
    allowUnsafeReuseRefreshToken: true,

    triggerAuthorizationResultEvent: true,
    customParamsAuthRequest: {
      prompt: 'login'
    }
  }
};
