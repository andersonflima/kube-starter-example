# Kube Starter

Exemplo full-stack com:

- backend em `Express + TypeScript`
- frontend em `React + Vite`
- `Dockerfile` para backend e frontend
- `docker-compose.yml` para ambiente local integrado
- chart Helm para Kubernetes
- exemplo de fluxo GitOps com Argo CD

## Objetivo

Este repositorio mostra, no mesmo projeto, quatro formas diferentes de empacotar e operar uma aplicacao:

- `Docker`: build e execucao manual de cada servico
- `Docker Compose`: sobe a stack local inteira com rede compartilhada
- `Helm`: instala a aplicacao no Kubernetes a partir de um chart
- `Argo CD`: aplica GitOps em cima do chart Helm versionado no Git

## Mapa da documentacao

- guia principal: [README.md](/Users/andersonespindola/snippets/kube/README.md)
- workflows e escolha de ferramenta: [docs/workflows-and-tooling.md](/Users/andersonespindola/snippets/kube/docs/workflows-and-tooling.md)
- fundamentos do Kubernetes: [docs/kubernetes-fundamentals.md](/Users/andersonespindola/snippets/kube/docs/kubernetes-fundamentals.md)
- GitOps com Argo CD: [docs/argocd-gitops.md](/Users/andersonespindola/snippets/kube/docs/argocd-gitops.md)
- debug e troubleshooting: [docs/debugging-cheatsheet.md](/Users/andersonespindola/snippets/kube/docs/debugging-cheatsheet.md)
- exemplo de `Application` do Argo CD: [argocd/kube-starter-application.yaml](/Users/andersonespindola/snippets/kube/argocd/kube-starter-application.yaml)

## Pre-Requisitos

### Ferramentas base

- `node` e `npm`
- `docker`
- `docker compose`
- `helm`
- `kubectl`

### Para cluster local

- `kind`

### Para fluxo GitOps

- cluster Kubernetes com acesso ao GitHub
- `Argo CD` instalado no cluster
- opcional: `argocd` CLI

## Estrutura do projeto

```text
.
|-- backend/
|-- frontend/
|-- helm/kube-starter/
|-- argocd/
`-- docs/
```

## Endpoints

- `GET /api/health`
- `GET /api/message`
- `GET /api/stats`

## Execucao Local

### 1. Build de aplicacao

Backend:

```bash
cd backend
npm install
npm run build
```

Frontend:

```bash
cd frontend
npm install
npm run build
```

### 2. Rodando com Docker

Build do backend:

```bash
docker build -t kube-backend ./backend
```

Build do frontend:

```bash
docker build -t kube-frontend ./frontend
```

Criando rede local:

```bash
docker network create kube-starter
```

Subindo backend:

```bash
docker run -d --name backend --network kube-starter -p 3000:3000 kube-backend
```

Validando backend:

```bash
curl http://localhost:3000/api/health
curl http://localhost:3000/api/message
curl http://localhost:3000/api/stats
```

Subindo frontend:

```bash
docker run -d --name frontend --network kube-starter \
  -e BACKEND_SERVICE_URL=http://backend:3000 \
  -p 8080:80 kube-frontend
```

Validando frontend:

```bash
curl http://localhost:8080
curl http://localhost:8080/api/health
```

Limpando:

```bash
docker stop frontend backend
docker rm frontend backend
docker network rm kube-starter
```

### 3. Rodando com Docker Compose

Subida padrao:

```bash
docker compose up --build
```

Subida em background:

```bash
docker compose up --build -d
```

Parada:

```bash
docker compose down
```

Frontend: `http://localhost:8080`  
Backend: `http://localhost:3000`

Subida com portas alternativas:

```bash
BACKEND_PORT=3002 FRONTEND_PORT=9081 docker compose up --build -d
```

Validacao:

```bash
curl http://localhost:3002/api/health
curl http://localhost:9081
curl http://localhost:9081/api/stats
```

Observacao: o [docker-compose.yml](/Users/andersonespindola/snippets/kube/docker-compose.yml) aceita `BACKEND_PORT` e `FRONTEND_PORT`.

## Execucao Com Cluster

### 1. Rodando com kind

Criando cluster:

```bash
kind create cluster --name kube-starter
kubectl config use-context kind-kube-starter
```

Carregando imagens locais:

```bash
kind load docker-image kube-backend:latest --name kube-starter
kind load docker-image kube-frontend:latest --name kube-starter
```

Verificando cluster:

```bash
kubectl get nodes
```

Removendo cluster:

```bash
kind delete cluster --name kube-starter
```

### 2. Rodando com Helm

Validacao estatica:

```bash
helm lint ./helm/kube-starter
helm template kube-starter ./helm/kube-starter
```

Instalacao:

```bash
helm upgrade --install kube-starter ./helm/kube-starter \
  --namespace kube-starter \
  --create-namespace
```

Instalacao com override:

```bash
helm upgrade --install kube-starter ./helm/kube-starter \
  --namespace kube-starter \
  --create-namespace \
  --set backend.image.repository=seu-registry/kube-backend \
  --set backend.image.tag=latest \
  --set frontend.image.repository=seu-registry/kube-frontend \
  --set frontend.image.tag=latest
```

Habilitando ingress:

```bash
helm upgrade --install kube-starter ./helm/kube-starter \
  --namespace kube-starter \
  --create-namespace \
  --set ingress.enabled=true \
  --set ingress.hosts[0].host=kube-starter.local
```

Inspecao:

```bash
kubectl get deployments,services,ingress -n kube-starter
kubectl get pods -n kube-starter
```

Teste por port-forward:

```bash
kubectl port-forward service/kube-starter-kube-starter-backend -n kube-starter 3003:3000
kubectl port-forward service/kube-starter-kube-starter-frontend -n kube-starter 9082:80
```

Em outro terminal:

```bash
curl http://localhost:3003/api/health
curl http://localhost:9082
curl http://localhost:9082/api/stats
```

Remocao:

```bash
helm uninstall kube-starter -n kube-starter
```

### 3. Rodando com Argo CD

Instalando Argo CD:

```bash
kubectl create namespace argocd
kubectl apply -n argocd --server-side --force-conflicts \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

Esperando componentes principais:

```bash
kubectl rollout status deployment/argocd-server -n argocd --timeout=300s
kubectl rollout status deployment/argocd-repo-server -n argocd --timeout=300s
kubectl rollout status deployment/argocd-redis -n argocd --timeout=300s
kubectl rollout status statefulset/argocd-application-controller -n argocd --timeout=300s
```

Acesso local opcional:

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Senha inicial:

```bash
argocd admin initial-password -n argocd
```

Aplicando a `Application`:

```bash
kubectl apply -f argocd/kube-starter-application.yaml
```

Verificando status:

```bash
kubectl get applications -A
kubectl get application kube-starter -n argocd \
  -o jsonpath='{.status.sync.status} {.status.health.status}{"\n"}'
```

Teste por port-forward:

```bash
kubectl port-forward service/kube-starter-kube-starter-backend -n kube-starter 3004:3000
kubectl port-forward service/kube-starter-kube-starter-frontend -n kube-starter 9083:80
```

Em outro terminal:

```bash
curl http://localhost:3004/api/health
curl http://localhost:3004/api/message
curl http://localhost:9083
curl http://localhost:9083/api/stats
```

## Validacao

### O que foi validado

- `backend`: `npm run build`
- `frontend`: `npm run build`
- `Docker Compose`: build, subida e teste real com `curl`
- `Helm`: `helm lint`, `helm template`, deploy em `kind` e teste real com `curl`
- `Argo CD`: instalacao no `kind`, `Application` com status `Synced Healthy` e teste real com `curl`

### Checklist rapido

```bash
cd backend && npm run build
cd ../frontend && npm run build
cd .. && docker compose build
helm lint ./helm/kube-starter
helm template kube-starter ./helm/kube-starter
```

### Sinais de sucesso

- backend responde `/api/health`
- frontend responde `/`
- `kubectl get pods -n kube-starter` mostra pods `Running`
- `kubectl get applications -A` mostra `kube-starter` como `Synced Healthy`

## Troubleshooting

### Porta local ocupada

Use portas alternativas no Compose:

```bash
BACKEND_PORT=3002 FRONTEND_PORT=9081 docker compose up --build -d
```

### Pod com `ImagePullBackOff`

Em `kind`, carregue as imagens locais antes do deploy:

```bash
kind load docker-image kube-backend:latest --name kube-starter
kind load docker-image kube-frontend:latest --name kube-starter
```

### Argo CD nao reconhece `Application`

As CRDs do Argo CD precisam estar instaladas:

```bash
kubectl get crd applications.argoproj.io
```

### App nao fica `Healthy`

Verifique:

```bash
kubectl get pods -n kube-starter
kubectl describe pods -n kube-starter
kubectl logs deployment/kube-starter-kube-starter-backend -n kube-starter
kubectl logs deployment/kube-starter-kube-starter-frontend -n kube-starter
```

Mais comandos:

- [docs/debugging-cheatsheet.md](/Users/andersonespindola/snippets/kube/docs/debugging-cheatsheet.md)

## Diferencas Entre As Ferramentas

### Docker

- escopo: container individual
- entrada: `Dockerfile`
- melhor uso: teste isolado de backend ou frontend

### Docker Compose

- escopo: varios containers relacionados
- entrada: `docker-compose.yml`
- melhor uso: desenvolvimento local e smoke test da stack

### Helm

- escopo: aplicacao no Kubernetes
- entrada: chart Helm
- melhor uso: deploy manual ou automatizado no cluster

### Argo CD

- escopo: operacao continua no Kubernetes
- entrada: Git como fonte de verdade
- melhor uso: GitOps com reconciliacao continua

Resumo pratico:

- `Docker` nao substitui `Compose`
- `Docker Compose` nao substitui `Helm`
- `Helm` nao substitui `Argo CD`
- `Argo CD` pode usar `Helm` como fonte

## Arquitetura

### Fluxo local

```text
[ Navegador ]
      |
      v
[ Frontend container | nginx ]
      |
      v
[ Backend container | Node.js + Express ]
```

### Fluxo com Helm

```text
[ Usuario ]
    |
    v
[ Ingress opcional ]
    |
    v
[ Service do Frontend ]
    |
    v
[ Pod do Frontend ]
    |
    v
[ Service do Backend ]
    |
    v
[ Pod do Backend ]
```

### Fluxo com Argo CD

```text
[ Developer ]
      |
      v
[ Git push ]
      |
      v
[ GitHub repository ]
      |
      v
[ Argo CD ]
      |
      v
[ Helm chart em helm/kube-starter ]
      |
      v
[ kube-apiserver ]
      |
      v
[ Pods e Services em execucao ]
```

## Fundamentos Kubernetes

### Componentes principais

- `kube-apiserver`: entrada da API do cluster
- `etcd`: persistencia do estado
- `controller-manager`: reconciliacao
- `scheduler`: escolha do node
- `kubelet`: execucao no node

### Objetos principais

- `Pod`: unidade minima executavel
- `Deployment`: replicas e rollout
- `Service`: endpoint estavel
- `Ingress`: entrada HTTP/HTTPS

Detalhes:

- [docs/kubernetes-fundamentals.md](/Users/andersonespindola/snippets/kube/docs/kubernetes-fundamentals.md)
