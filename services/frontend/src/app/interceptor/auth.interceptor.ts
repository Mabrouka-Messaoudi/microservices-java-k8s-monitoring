import {HttpInterceptorFn} from "@angular/common/http";
import {inject} from "@angular/core";
import {OidcSecurityService} from "angular-auth-oidc-client";
import {switchMap, take} from "rxjs";

export const authInterceptor: HttpInterceptorFn = (req, next) => {
  const authService = inject(OidcSecurityService);

  return authService.getAccessToken().pipe(
    take(1),
    switchMap(token => {
      // DEBUG — remove after fixing
      console.log('🔑 Token received by interceptor:', token ? token.substring(0, 30) + '...' : 'EMPTY/NULL');
      console.log('📡 Request URL:', req.url);

      if (token) {
        const clonedReq = req.clone({
          headers: req.headers.set('Authorization', 'Bearer ' + token)
        });
        return next(clonedReq);
      }
      return next(req);
    })
  );
};
