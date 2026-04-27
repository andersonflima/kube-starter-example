# Kube Starter

Exemplo full-stack com:

- backend em `Express + TypeScript`
- frontend em `React + Vite`
- `Dockerfile` para backend e frontend
- `docker-compose.yml` para ambiente local integrado
- chart Helm para Kubernetes
- exemplo de fluxo GitOps com Argo CD

## Objetivo

Este repositorio existe para mostrar, no mesmo projeto, quatro formas diferentes de empacotar e operar uma aplicacao:

- `Docker`: build e execucao manual de cada servico
- `Docker Compose`: sobe a stack local inteira com rede compartilhada
- `Helm`: instala a aplicacao no Kubernetes a partir de um chart
- `Argo CD`: aplica GitOps em cima do chart Helm versionado no Git

## Mapa da documentacao

- guia principal: [README.md](/Users/andersonespindola/snippets/kube/README.md)
- workflows e escolha de ferramenta: [docs/workflows-and-tooling.md](/Users/andersonespindola/snippets/kube/docs/workflows-and-tooling.md)
- fundamentos do Kubernetes: [docs/kubernetes-fundamentals.md](/Users/andersonespindola/snippets/kube/docs/kubernetes-fundamentals.md)
- GitOps com Argo CD: [docs/argocd-gitops.md](/Users/andersonespindola/snippets/kube/docs/argocd-gitops.md)
- comandos de debug e operacao: [docs/debugging-cheatsheet.md](/Users/andersonespindola/snippets/kube/docs/debugging-cheatsheet.md)
- exemplo de `Application` do Argo CD: [argocd/kube-starter-application.yaml](/Users/andersonespindola/snippets/kube/argocd/kube-starter-application.yaml)

## Endpoints

- `GET /api/health`
- `GET /api/message`
- `GET /api/stats`

## Estrutura do projeto

```text
.
|-- backend/
|-- frontend/
|-- helm/kube-starter/
|-- argocd/
`-- docs/
```

## Arquitetura da solucao

### Visao geral

O frontend serve a interface para o navegador e faz proxy de `/api` para o backend. O backend concentra a logica HTTP e responde os tres endpoints da aplicacao.

### Fluxo local com Docker ou Docker Compose

```text
[ Navegador ]
      |
      v
[ Frontend container | nginx ]
      |
      v
[ Backend container | Node.js + Express ]
```

### Fluxo no Kubernetes com Helm

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

### Fluxo com Argo CD + Helm + Kubernetes

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
[ etcd / controllers / scheduler / kubelet ]
      |
      v
[ Pods e Services em execucao ]
```

### Responsabilidades

- frontend: entrega a UI e consome a API
- backend: responde `health`, `message` e `stats`
- docker: empacota cada servico como imagem
- docker compose: sobe os dois servicos juntos localmente
- helm: define os manifests parametrizados da aplicacao no cluster
- argo cd: observa o Git e reconcilia o cluster automaticamente

## Diferencas entre Docker, Docker Compose, Helm e Argo CD

### Docker

Use `Docker` quando voce quer montar e executar cada servico manualmente.

- escopo: container individual
- entrada: `Dockerfile`
- estado desejado: controlado por voce no terminal
- melhor uso: teste isolado de backend ou frontend

### Docker Compose

Use `Docker Compose` quando voce quer um ambiente local integrado sem precisar subir os containers um por um.

- escopo: varios containers relacionados
- entrada: `docker-compose.yml`
- estado desejado: controlado por um arquivo unico local
- melhor uso: desenvolvimento local e smoke test da stack

### Helm

Use `Helm` quando voce quer empacotar manifests Kubernetes com valores configuraveis.

- escopo: aplicacao no Kubernetes
- entrada: chart Helm
- estado desejado: aplicado quando voce executa `helm install` ou `helm upgrade`
- melhor uso: deploy manual ou automatizado no cluster

### Argo CD

Use `Argo CD` quando voce quer GitOps de verdade: o repositorio Git vira a fonte de verdade e o cluster e reconciliado continuamente.

- escopo: operacao continua no Kubernetes
- entrada: manifests puros, Kustomize ou Helm versionados no Git
- estado desejado: mantido automaticamente pelo controller
- melhor uso: homologacao, staging e producao com trilha auditavel

### Resumo pratico

- `Docker` nao substitui `Compose`: ele e a base de imagem e execucao individual.
- `Docker Compose` nao substitui `Helm`: ele resolve ambiente local, nao cluster Kubernetes.
- `Helm` nao substitui `Argo CD`: Helm empacota e instala; Argo CD observa Git e reconcilia continuamente.
- `Argo CD` pode usar `Helm` como fonte. Neste projeto, essa e a combinacao mais natural para GitOps.

## Componentes principais do Kubernetes

Quando voce instala este projeto com `Helm` ou deixa o `Argo CD` sincronizar o chart, o fluxo passa por estes componentes:

```text
[ Helm ou Argo CD ]
        |
        v
[ kube-apiserver ]
        |
        v
[ etcd ]
        |
        v
[ controller-manager ]
        |
        v
[ scheduler ]
        |
        v
[ kubelet ]
```

- `kube-apiserver`: porta de entrada do cluster. Recebe, valida e expoe a API.
- `etcd`: banco chave-valor que persiste o estado do cluster.
- `controller-manager`: reconcilia estado desejado e estado atual.
- `scheduler`: escolhe em qual node cada Pod pendente vai rodar.
- `kubelet`: agente do node que materializa os Pods em execucao.

Explicacao detalhada: [docs/kubernetes-fundamentals.md](/Users/andersonespindola/snippets/kube/docs/kubernetes-fundamentals.md)

## Diferenca entre Pod, Deployment, Service e Ingress

- `Pod`: unidade minima executavel
- `Deployment`: garante replicas, rollout e recriacao de Pods
- `Service`: endpoint estavel para acessar Pods
- `Ingress`: entrada HTTP/HTTPS na frente de um ou mais Services

```text
[ Usuario ]
    |
    v
[ Ingress opcional ]
    |
    v
[ Service ]
    |
    v
[ Pods ]
    ^
    |
[ Deployment ]
```

Explicacao detalhada: [docs/kubernetes-fundamentals.md](/Users/andersonespindola/snippets/kube/docs/kubernetes-fundamentals.md)

## Comandos

### 0. Rodando com kind

Criando um cluster local:

```bash
kind create cluster --name kube-starter
kubectl config use-context kind-kube-starter
```

Carregando as imagens locais no node do kind:

```bash
kind load docker-image kube-backend:latest --name kube-starter
kind load docker-image kube-frontend:latest --name kube-starter
```

Verificando o cluster:

```bash
kubectl get nodes
```

Removendo o cluster ao final:

```bash
kind delete cluster --name kube-starter
```

### 1. Rodando com Docker

Build do backend:

```bash
docker build -t kube-backend ./backend
```

Build do frontend:

```bash
docker build -t kube-frontend ./frontend
```

Criando uma rede local:

```bash
docker network create kube-starter
```

Subindo backend:

```bash
docker run -d --name backend --network kube-starter -p 3000:3000 kube-backend
```

Verificando backend:

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

Verificando frontend:

```bash
curl http://localhost:8080
curl http://localhost:8080/api/health
```

Parando e removendo:

```bash
docker stop frontend backend
docker rm frontend backend
docker network rm kube-starter
```

### 2. Rodando com Docker Compose

Subindo com portas padrao:

```bash
docker compose up --build
```

Rodando em background:

```bash
docker compose up --build -d
```

Parando:

```bash
docker compose down
```

Frontend: `http://localhost:8080`  
Backend: `http://localhost:3000`

Subindo com portas alternativas sem editar o arquivo:

```bash
BACKEND_PORT=3002 FRONTEND_PORT=9081 docker compose up --build -d
```

Verificando a stack:

```bash
curl http://localhost:3002/api/health
curl http://localhost:9081
curl http://localhost:9081/api/stats
```

Observacao: o [docker-compose.yml](/Users/andersonespindola/snippets/kube/docker-compose.yml) agora aceita `BACKEND_PORT` e `FRONTEND_PORT` para evitar conflito local.

### 3. Rodando com Helm

Renderizando manifests:

```bash
helm template kube-starter ./helm/kube-starter
```

Validando chart:

```bash
helm lint ./helm/kube-starter
```

Instalando:

```bash
helm upgrade --install kube-starter ./helm/kube-starter
```

Instalando com override de imagens:

```bash
helm upgrade --install kube-starter ./helm/kube-starter \
  --set backend.image.repository=seu-registry/kube-backend \
  --set backend.image.tag=latest \
  --set frontend.image.repository=seu-registry/kube-frontend \
  --set frontend.image.tag=latest
```

Habilitando ingress:

```bash
helm upgrade --install kube-starter ./helm/kube-starter \
  --set ingress.enabled=true \
  --set ingress.hosts[0].host=kube-starter.local
```

Removendo:

```bash
helm uninstall kube-starter
```

Fluxo completo de validacao local do chart:

```bash
helm lint ./helm/kube-starter
helm template kube-starter ./helm/kube-starter
```

Fluxo completo em cluster:

```bash
helm upgrade --install kube-starter ./helm/kube-starter
kubectl get deployments,services,ingress
kubectl get pods
```

Fluxo completo em kind:

```bash
kind create cluster --name kube-starter
kind load docker-image kube-backend:latest --name kube-starter
kind load docker-image kube-frontend:latest --name kube-starter
helm upgrade --install kube-starter ./helm/kube-starter \
  --namespace kube-starter \
  --create-namespace
kubectl rollout status deployment/kube-starter-kube-starter-backend -n kube-starter
kubectl rollout status deployment/kube-starter-kube-starter-frontend -n kube-starter
kubectl port-forward service/kube-starter-kube-starter-frontend -n kube-starter 9082:80
```

### 4. Rodando com Argo CD

Instalando Argo CD no cluster:

```bash
kubectl create namespace argocd
kubectl apply -n argocd --server-side --force-conflicts \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

Acessando localmente a UI:

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Obtendo a senha inicial:

```bash
argocd admin initial-password -n argocd
```

Fazendo login no CLI:

```bash
argocd login localhost:8080 --insecure
```

Aplicando a `Application` deste projeto:

```bash
kubectl apply -f argocd/kube-starter-application.yaml
```

Verificando sincronizacao:

```bash
kubectl get applications -n argocd
argocd app get kube-starter
argocd app sync kube-starter
argocd app wait kube-starter --health --sync
```

Fluxo completo em kind:

```bash
kind create cluster --name kube-starter
kind load docker-image kube-backend:latest --name kube-starter
kind load docker-image kube-frontend:latest --name kube-starter
kubectl create namespace argocd
kubectl apply -n argocd --server-side --force-conflicts \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl rollout status deployment/argocd-server -n argocd --timeout=300s
kubectl rollout status deployment/argocd-repo-server -n argocd --timeout=300s
kubectl rollout status statefulset/argocd-application-controller -n argocd --timeout=300s
kubectl apply -f argocd/kube-starter-application.yaml
kubectl get application kube-starter -n argocd
```

Explicacao detalhada: [docs/argocd-gitops.md](/Users/andersonespindola/snippets/kube/docs/argocd-gitops.md)

## Matriz de validacao

Os fluxos abaixo foram validados localmente neste repositorio:

- `backend`: `npm run build`
- `frontend`: `npm run build`
- `Docker`: `docker build` do backend e do frontend, seguido de teste real com `docker run`
- `Docker Compose`: `docker compose config` e `docker compose build`
- `Helm`: `helm lint` e `helm template`
- `kind + Helm`: cluster criado, imagens carregadas, release instalado e endpoints testados
- `kind + Argo CD`: Argo CD instalado, `Application` sincronizada e endpoints testados

Limitacao importante:

- o fluxo `Argo CD` depende de acesso do cluster ao GitHub para buscar o repositorio remoto
- antes do primeiro push com as correcoes do chart, a validacao local usou tags compatíveis tambem para provar o funcionamento do ciclo completo

Como repetir a validacao manual:

```bash
cd backend && npm run build
cd ../frontend && npm run build
cd .. && docker compose build
helm lint ./helm/kube-starter
helm template kube-starter ./helm/kube-starter
```

## Desenvolvimento

Backend:

```bash
cd backend
npm install
npm run dev
```

Frontend:

```bash
cd frontend
npm install
npm run dev
```

## Exemplos rapidos de uso

### Testando o backend localmente

```bash
curl http://localhost:3000/api/health
curl http://localhost:3000/api/message
curl http://localhost:3000/api/stats
```

### Renderizando a home do frontend publicado em container

```bash
curl http://localhost:8080
```

### Inspecionando objetos do release Helm

```bash
kubectl get deployments,services,ingress
```

### Inspecionando uma app no Argo CD

```bash
kubectl describe application kube-starter -n argocd
```

## Proximos documentos

- detalhes de quando escolher cada ferramenta: [docs/workflows-and-tooling.md](/Users/andersonespindola/snippets/kube/docs/workflows-and-tooling.md)
- fundamentos do cluster: [docs/kubernetes-fundamentals.md](/Users/andersonespindola/snippets/kube/docs/kubernetes-fundamentals.md)
- GitOps e Argo CD: [docs/argocd-gitops.md](/Users/andersonespindola/snippets/kube/docs/argocd-gitops.md)
- troubleshooting: [docs/debugging-cheatsheet.md](/Users/andersonespindola/snippets/kube/docs/debugging-cheatsheet.md)
