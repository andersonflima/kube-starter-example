# Debugging Cheatsheet

Comandos uteis para inspecionar a stack local, o release Helm e a app no Argo CD.

## Docker

Containers:

```bash
docker ps
docker logs backend
docker logs frontend
```

Rede:

```bash
docker network ls
docker inspect kube-starter
```

## Docker Compose

Status:

```bash
docker compose ps
```

Logs:

```bash
docker compose logs -f
docker compose logs -f backend
docker compose logs -f frontend
```

Rebuild:

```bash
docker compose up --build --force-recreate
```

## Helm

Templates:

```bash
helm template kube-starter ./helm/kube-starter
```

Lint:

```bash
helm lint ./helm/kube-starter
```

Historico:

```bash
helm history kube-starter
```

Rollback:

```bash
helm rollback kube-starter 1
```

## Kubernetes

Objetos:

```bash
kubectl get pods,deployments,services,ingresses -A
```

Detalhes:

```bash
kubectl describe deployment kube-starter-kube-starter-backend
kubectl describe service kube-starter-kube-starter-frontend
```

Logs:

```bash
kubectl logs deployment/kube-starter-kube-starter-backend
kubectl logs deployment/kube-starter-kube-starter-frontend
```

Port-forward:

```bash
kubectl port-forward service/kube-starter-kube-starter-frontend 8080:80
kubectl port-forward service/kube-starter-kube-starter-backend 3000:3000
```

## Argo CD

Applications:

```bash
kubectl get applications.argoproj.io -n argocd
kubectl describe applications.argoproj.io kube-starter -n argocd
```

Pods do Argo CD:

```bash
kubectl get pods -n argocd
```

Logs do controller:

```bash
kubectl logs deployment/argocd-application-controller -n argocd
```

UI local:

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

## Sinais comuns de problema

### Backend nao responde

- imagem nao foi publicada
- `Service` aponta para labels erradas
- container nao escuta na porta esperada

### Frontend nao enxerga backend

- `BACKEND_SERVICE_URL` incorreta
- `Service` do backend inexistente
- backend falhando readiness

### Helm instala, mas app nao sobe

- imagem errada
- probes falhando
- porta divergente entre container e service

### Argo CD fica OutOfSync

- houve drift manual no cluster
- o repositorio mudou e o sync ainda nao rodou
- a `Application` aponta para path ou branch errados
