# NexShop – Frontend Angular

Interface web de NexShop : liste des produits, commande, ajout de produit et de stock.
Authentification via Keycloak (OpenID Connect, flux *Authorization Code* avec PKCE).

Angular 18 (composants standalone) · TypeScript · Tailwind CSS · angular-auth-oidc-client

## Configuration à l'exécution

L'application lit ses URLs dans `window.__ENV__`, un fichier `env.js` généré au démarrage du conteneur par
`docker-entrypoint.sh` à partir de variables d'environnement :

| Variable | Rôle | Valeur par défaut |
|----------|------|-------------------|
| `API_GATEWAY_URL` | URL de l'API Gateway | `http://localhost:30900` |
| `KEYCLOAK_URL` | URL de Keycloak | `http://localhost:30818` |

Ainsi la même image Docker fonctionne dans n'importe quel environnement. Sur Kubernetes, ces variables sont
définies dans `k8s/apps/frontend/frontend.yaml` (l'adresse du noeud est injectée par `scripts/deploy.sh`).

## Développement local

```bash
npm install
npm start        # http://localhost:4200
```

Sans `env.js`, les URLs par défaut ci-dessus sont utilisées. Pour pointer vers un autre backend en local,
créer un fichier `public/env.js` (à ne pas commiter) :

```js
window.__ENV__ = { API_GATEWAY_URL: "http://localhost:9000", KEYCLOAK_URL: "http://localhost:8181" };
```

## Build et image Docker

```bash
npx ng build --configuration=production
docker build -t <compte>/frontend:latest .
```

L'image est construite en deux étapes (build Angular puis nginx). La configuration nginx (HTTPS sur 443,
redirection HTTP vers HTTPS, route `/health`) est fournie par le ConfigMap `configmap.yaml` ; le certificat
TLS est monté depuis le secret `frontend-tls`.

## Structure

```
src/app/
├── config/        configuration OIDC (Keycloak)
├── interceptor/   ajout du token Bearer aux requêtes vers l'API
├── model/         interfaces Product et Order
├── pages/         home-page, add-product, add-inventory
├── services/      product, order, inventory
└── shared/        header
```
