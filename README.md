# NexShop – Microservices sur Kubernetes avec observabilité

Application e-commerce en microservices (Spring Boot + Angular), déployée sur un cluster Kubernetes
et instrumentée pour l'observabilité (métriques, logs, traces). Ce dépôt fait partie de mon PFE :
*plateforme Kubernetes hybride avec supervision par IA/ML (AIOps)*.

## Architecture

```
Navigateur ──► Frontend Angular (nginx, HTTPS :30200)
                    │  JWT (OIDC / PKCE)
                    ▼
              API Gateway (:30900) ──► Product Service   ──► MongoDB
                    │              ──► Order Service     ──► MySQL ──► Kafka ──► Notification Service ──► Mailtrap (SMTP)
                    │              ──► Inventory Service ──► MySQL        ▲
                    ▼                                        Order ──────┘ (appel REST à Inventory)
              Keycloak (:30818) – OAuth2 / OpenID Connect
```

| Service | Rôle | Stockage / dépendances |
|---------|------|------------------------|
| `frontend` | Interface web Angular servie par nginx (HTTPS) | Keycloak, API Gateway |
| `api-gateway` | Point d'entrée, routage, validation des JWT, circuit breaker | Keycloak |
| `product-service` | Catalogue de produits | MongoDB |
| `order-service` | Passage de commandes, publication d'événements | MySQL, Kafka (Avro), Inventory |
| `inventory-service` | Stock par SKU | MySQL |
| `notification-service` | Envoi d'e-mails à la réception d'un événement de commande | Kafka, SMTP Mailtrap |

**Observabilité** : chaque service expose `/actuator/prometheus`, envoie ses traces à Tempo (Zipkin) et
ses logs à Loki (via `logback-spring.xml`).

## Contenu du dépôt

```
services/     code source des microservices Java et du frontend (un Dockerfile par service)
k8s/          manifests Kubernetes : namespaces, infrastructure, applications, monitoring
scripts/      build-push.sh, deploy.sh, teardown.sh, test-nexshop.sh, secrets.env.example
.github/      workflow GitHub Actions (build et push des images Docker)
```

## Prérequis

- Un cluster Kubernetes fonctionnel (testé avec 1 master + 3 workers, créé avec le dépôt
  [`cluster-k8s`](https://github.com/Mabrouka-Messaoudi/cluster-k8s)) et `kubectl` configuré
- Docker et un compte Docker Hub
- `openssl` (génération du certificat TLS auto-signé du frontend)
- Un compte [Mailtrap](https://mailtrap.io) (inbox de test pour le service de notification)
- Les composants Prometheus, Grafana et Loki dans le namespace `monitoring`
  *(à compléter : indiquer ici comment ils sont installés, par exemple chart Helm et fichier de values)*

## Configuration des secrets

```bash
cp scripts/secrets.env.example scripts/secrets.env
# renseigner MAIL_USERNAME / MAIL_PASSWORD (Mailtrap) et TEST_USERNAME / TEST_PASSWORD (utilisateur Keycloak de test)
```

`scripts/secrets.env` est ignoré par Git. Les mots de passe de MySQL, MongoDB et Keycloak définis dans
`k8s/infrastructure/secrets-and-config.yaml` sont des **valeurs de démonstration** : à changer hors d'un
environnement de test.

## Build et déploiement

```bash
# 1. Construire et pousser les images (Docker Hub)
export DOCKER_USERNAME=mon-compte-dockerhub
bash scripts/build-push.sh

# 2. Déployer toute la plateforme
export NODE_IP=192.168.100.113                 # IP d'un noeud du cluster
export APP_NODES="k8s2-worker2 k8s2-worker3"   # noeuds applicatifs (voir : kubectl get nodes)
export MONITORING_NODE=k8s2-worker1            # noeud qui héberge le monitoring (exemple : adapter)
bash scripts/deploy.sh
```

`deploy.sh` étiquette les noeuds (`role=app`, `role=monitoring`), crée les namespaces, les secrets
(y compris `mail-secret` et le certificat TLS du frontend), déploie l'infrastructure, Tempo puis les
microservices, et attend que chaque déploiement soit prêt. Les images peuvent aussi être construites par la
CI (voir plus bas).

## Accès aux services

| Service | URL |
|---------|-----|
| Frontend | `https://<NODE_IP>:30200` (certificat auto-signé : accepter l'avertissement du navigateur) |
| API Gateway | `http://<NODE_IP>:30900` (Swagger : `/swagger-ui.html`) |
| Keycloak | `http://<NODE_IP>:30818` |
| Kafka UI | `http://<NODE_IP>:30886` |
| Grafana | `http://<IP du noeud de monitoring>:30300` |

## Tests

- **Test de bout en bout du backend** : `NODE_IP=<ip> bash scripts/test-nexshop.sh`
  (vérifie les pods, obtient un JWT Keycloak puis appelle produits, stock et commandes ;
  nécessite `TEST_USERNAME` et `TEST_PASSWORD` dans `scripts/secrets.env`).
- **Tests unitaires et d'intégration Java** (Testcontainers, Docker requis) : `./mvnw test` ou `mvn test`
  dans chaque dossier `services/<service>`.

## Intégration continue

Le workflow `.github/workflows/build-push.yml` construit les images Docker de tous les services
(y compris le frontend) et les pousse sur Docker Hub à chaque push sur `main`. Secrets GitHub requis :
`DOCKER_USERNAME` et `DOCKER_PASSWORD`. Les tests ne sont pas exécutés par ce workflow.

## Développement local (hors Kubernetes)

Les fichiers `application.properties` de chaque service sont configurés pour un environnement local
(`localhost`) : MySQL `3306` (order) et `3316` (inventory), MongoDB `27017`, Kafka `9092`, Schema Registry
`8085`, Zipkin `9411`, Keycloak `8181`, API Gateway `9000`. Dans Kubernetes, ces valeurs sont remplacées
par des variables d'environnement définies dans les manifests (`k8s/apps/*`) et dans le ConfigMap
`nexshop-config`.


## Nettoyage

```bash
bash scripts/teardown.sh
```
