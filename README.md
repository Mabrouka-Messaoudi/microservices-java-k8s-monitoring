# NexShop – Kubernetes Deployment

Microservices e-commerce platform deployed on a 3-node Kubernetes cluster.

## Cluster Layout

| Node | Role | Workloads |
|------|------|-----------|
| k8s-master | control-plane | — |
| k8s-worker1 | app | Microservices + Infrastructure (Kafka, MySQL, MongoDB, Keycloak) |
| k8s-worker2 | monitoring | Prometheus, Grafana, Loki, Tempo |

## Quick Start

### 1. Prerequisites
```bash
# Label nodes (run once)
kubectl label node k8s-worker1 role=app
kubectl label node k8s-worker2 role=monitoring
```

### 2. Configure secrets
```bash
cp scripts/secrets.env.example scripts/secrets.env
# Edit scripts/secrets.env with your values
```

### 3. Build & Push images
```bash
# Set your Docker Hub username
export DOCKER_USERNAME=your-dockerhub-username
bash scripts/build-push.sh
```

### 4. Deploy everything
```bash
export DOCKER_USERNAME=your-dockerhub-username
bash scripts/deploy.sh
```

### 5. Access services
| Service | URL |
|---------|-----|
| Grafana | http://10.10.10.12:30300 |
| Keycloak | http://10.10.10.11:30818 |
| API Gateway | http://10.10.10.11:30900 |
| Kafka UI | http://10.10.10.11:30886 |

## Architecture
```
Angular (localhost:4200)
    │
    ▼
API Gateway (:30900)
    ├──► Product Service  ──► MongoDB
    ├──► Order Service    ──► MySQL ──► Kafka ──► Notification Service
    └──► Inventory Service──► MySQL
         │
         ▼
      Keycloak (OAuth2)
```
