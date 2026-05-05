# Kube Starter

Exemplo full-stack com:

- backend em `Express + TypeScript`
- frontend em `React + Vite`
- `Dockerfile` para backend e frontend
- `docker-compose.yml` para ambiente local integrado
- chart Helm para Kubernetes
- exemplo de fluxo GitOps com Argo CD
- HPA com metricas de CPU e memoria via Metrics Server

## Objetivo

Este repositorio mostra, no mesmo projeto, quatro formas diferentes de empacotar e operar uma aplicacao:

- `Docker`: build e execucao manual de cada servico
- `Docker Compose`: sobe a stack local inteira com rede compartilhada
- `Helm`: instala a aplicacao no Kubernetes a partir de um chart
- `Argo CD`: aplica GitOps em cima do chart Helm versionado no Git
- `Metrics Server + HPA`: coleta metricas de recursos e escala replicas automaticamente

## Mapa da documentacao

- guia principal: [README.md](README.md)
- workflows e escolha de ferramenta: [docs/workflows-and-tooling.md](docs/workflows-and-tooling.md)
- fundamentos do Kubernetes: [docs/kubernetes-fundamentals.md](docs/kubernetes-fundamentals.md)
- GitOps com Argo CD: [docs/argocd-gitops.md](docs/argocd-gitops.md)
- debug e troubleshooting: [docs/debugging-cheatsheet.md](docs/debugging-cheatsheet.md)
- exemplo de `Application` do Argo CD: [argocd/kube-starter-application.yaml](argocd/kube-starter-application.yaml)
- exemplo de `Application` do Metrics Server: [argocd/metrics-server-application.yaml](argocd/metrics-server-application.yaml)

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

### Compatibilidade por sistema operacional

Os comandos principais deste guia usam sintaxe de shell POSIX, compativel com Linux, macOS e Windows via WSL2.

No Windows, prefira executar Docker, `kind`, `kubectl` e Helm pelo WSL2. O PowerShell tambem funciona, mas exige pequenas adaptacoes:

- troque `\` por crase quando quebrar comandos em varias linhas
- defina variaveis de ambiente com `$env:NOME = "valor"`
- quando possivel, use o comando em uma linha para evitar diferencas de shell

Exemplo com quebra de linha:

```bash
helm upgrade --install kube-starter ./helm/kube-starter \
  --namespace kube-starter \
  --create-namespace
```

```powershell
helm upgrade --install kube-starter ./helm/kube-starter `
  --namespace kube-starter `
  --create-namespace
```

Exemplo com variaveis de ambiente:

```bash
BACKEND_PORT=3002 FRONTEND_PORT=9081 docker compose up --build -d
```

```powershell
$env:BACKEND_PORT = "3002"
$env:FRONTEND_PORT = "9081"
docker compose up --build -d
```

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

### Responsabilidades

- frontend: entrega a UI e consome a API
- backend: responde `health`, `message` e `stats`
- docker: empacota cada servico como imagem
- docker compose: sobe os dois servicos juntos localmente
- helm: define os manifests parametrizados da aplicacao no cluster
- argo cd: observa o Git e reconcilia o cluster automaticamente
- metrics server: publica metricas para o HPA
- hpa: ajusta replicas conforme uso de CPU e memoria

## Endpoints

- `GET /api/health`
- `GET /api/message`
- `GET /api/stats`

## Como Criar Os Artefatos Do Zero

Esta secao mostra como criar os principais artefatos usados neste projeto: `Dockerfile`, chart Helm, `Chart.yaml`, `values.yaml` e templates Kubernetes.

### 1. Criando um Dockerfile para backend Node.js

Crie o arquivo `backend/Dockerfile`.

Exemplo produtivo com multi-stage build:

```dockerfile
FROM node:20-alpine AS dependencies
WORKDIR /app
COPY package.json package-lock.json* ./
RUN npm ci

FROM node:20-alpine AS build
WORKDIR /app
COPY --from=dependencies /app/node_modules ./node_modules
COPY package.json tsconfig.json ./
COPY src ./src
RUN npm run build

FROM node:20-alpine AS runtime
WORKDIR /app
ENV NODE_ENV=production
COPY package.json package-lock.json* ./
RUN npm ci --omit=dev
COPY --from=build /app/dist ./dist
EXPOSE 3000
CMD ["npm", "run", "start"]
```

Motivo da estrutura:

- `dependencies`: instala dependencias de forma reproduzivel com `npm ci`
- `build`: compila TypeScript sem levar arquivos desnecessarios para runtime
- `runtime`: instala apenas dependencias de producao e executa o codigo compilado

Build e teste:

```bash
docker build -t kube-backend:latest ./backend
docker run --rm -p 3000:3000 kube-backend:latest
curl http://localhost:3000/api/health
```

### 2. Criando um Dockerfile para frontend React/Vite

Crie o arquivo `frontend/Dockerfile`.

Exemplo produtivo com build em Node.js e runtime em nginx:

```dockerfile
FROM node:20-alpine AS build
WORKDIR /app
COPY package.json package-lock.json* ./
RUN npm ci
COPY index.html tsconfig.json tsconfig.node.json vite.config.ts ./
COPY src ./src
RUN npm run build

FROM nginx:1.27-alpine AS runtime
ENV BACKEND_SERVICE_URL=http://backend:3000
COPY nginx/default.conf.template /etc/nginx/templates/default.conf.template
COPY --from=build /app/dist /usr/share/nginx/html
EXPOSE 80
```

Motivo da estrutura:

- o build usa Node.js porque Vite precisa do toolchain JavaScript
- o runtime usa nginx porque entrega arquivo estatico com menos overhead
- `BACKEND_SERVICE_URL` permite apontar o proxy para o backend correto em Docker, Compose ou Kubernetes

Build e teste:

```bash
docker build -t kube-frontend:latest ./frontend
docker run --rm -p 8080:80 -e BACKEND_SERVICE_URL=http://host.docker.internal:3000 kube-frontend:latest
curl http://localhost:8080
```

### 3. Criando um chart Helm

Um chart Helm e um pacote de manifests Kubernetes parametrizados.

Crie a estrutura:

```bash
mkdir -p helm/kube-starter/templates
touch helm/kube-starter/Chart.yaml
touch helm/kube-starter/values.yaml
touch helm/kube-starter/templates/_helpers.tpl
touch helm/kube-starter/templates/backend-deployment.yaml
touch helm/kube-starter/templates/backend-service.yaml
touch helm/kube-starter/templates/frontend-deployment.yaml
touch helm/kube-starter/templates/frontend-service.yaml
touch helm/kube-starter/templates/ingress.yaml
```

Estrutura esperada:

```text
helm/kube-starter/
|-- Chart.yaml
|-- values.yaml
`-- templates/
    |-- _helpers.tpl
    |-- backend-deployment.yaml
    |-- backend-service.yaml
    |-- frontend-deployment.yaml
    |-- frontend-service.yaml
    `-- ingress.yaml
```

Tambem e possivel iniciar com:

```bash
helm create kube-starter
```

Neste repositorio, a estrutura foi mantida manual e enxuta para deixar cada recurso visivel.

### 4. Criando o Chart.yaml

O `Chart.yaml` descreve o pacote Helm.

Exemplo:

```yaml
apiVersion: v2
name: kube-starter
description: Full-stack starter com frontend, backend e configuracao Kubernetes
type: application
version: 0.2.0
appVersion: "1.0.0"
```

Campos principais:

- `apiVersion`: `v2` para charts Helm 3
- `name`: nome do chart
- `description`: resumo do pacote
- `type`: `application` para aplicacoes instalaveis
- `version`: versao do chart, muda quando os manifests/valores mudam
- `appVersion`: versao da aplicacao empacotada

### 5. Criando o values.yaml

O `values.yaml` centraliza configuracoes por ambiente.

Exemplo base:

```yaml
frontend:
  replicaCount: 1
  image:
    repository: kube-frontend
    tag: latest
    pullPolicy: IfNotPresent
  service:
    type: ClusterIP
    port: 80

backend:
  replicaCount: 1
  image:
    repository: kube-backend
    tag: latest
    pullPolicy: IfNotPresent
  service:
    type: ClusterIP
    port: 3000
```

Exemplo com recursos e HPA:

```yaml
backend:
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      cpu: 500m
      memory: 256Mi
  autoscaling:
    enabled: true
    minReplicas: 1
    maxReplicas: 4
    targetCPUUtilizationPercentage: 70
    targetMemoryUtilizationPercentage: 80
```

Regra pratica:

- coloque no `values.yaml` tudo que muda por ambiente
- mantenha nomes, labels e estrutura dos manifests nos templates
- defina `resources.requests` quando usar HPA
- evite hardcode de imagem, tag, porta, replicas e ingress nos templates

### 6. Criando helpers do Helm

O arquivo `templates/_helpers.tpl` concentra nomes e labels reutilizaveis.

Exemplo:

```yaml
{{- define "kube-starter.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "kube-starter.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "kube-starter.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "kube-starter.labels" -}}
app.kubernetes.io/name: {{ include "kube-starter.name" . }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}
```

Motivo:

- evita repetir regra de nome em todos os manifests
- padroniza labels para seletores, observabilidade e operacao
- reduz risco de Service apontar para Pods errados

### 7. Criando um Deployment template

Exemplo simplificado de backend:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "kube-starter.backendFullname" . }}
  labels:
    {{- include "kube-starter.labels" . | nindent 4 }}
    app.kubernetes.io/component: backend
spec:
  replicas: {{ .Values.backend.replicaCount }}
  selector:
    matchLabels:
      app.kubernetes.io/instance: {{ .Release.Name }}
      app.kubernetes.io/component: backend
  template:
    metadata:
      labels:
        {{- include "kube-starter.labels" . | nindent 8 }}
        app.kubernetes.io/component: backend
    spec:
      containers:
        - name: backend
          image: "{{ .Values.backend.image.repository }}:{{ .Values.backend.image.tag }}"
          imagePullPolicy: {{ .Values.backend.image.pullPolicy }}
          ports:
            - name: http
              containerPort: {{ .Values.backend.service.port }}
```

Pontos importantes:

- `selector.matchLabels` precisa bater com `template.metadata.labels`
- imagem, tag e pull policy devem vir de `values.yaml`
- portas nomeadas facilitam `Service`, probes e leitura operacional

### 8. Criando um Service template

Exemplo:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: {{ include "kube-starter.backendFullname" . }}
  labels:
    {{- include "kube-starter.labels" . | nindent 4 }}
    app.kubernetes.io/component: backend
spec:
  type: {{ .Values.backend.service.type }}
  selector:
    app.kubernetes.io/instance: {{ .Release.Name }}
    app.kubernetes.io/component: backend
  ports:
    - name: http
      port: {{ .Values.backend.service.port }}
      targetPort: http
```

Pontos importantes:

- `selector` deve apontar para labels dos Pods
- `targetPort: http` usa a porta nomeada do container
- `ClusterIP` e o padrao recomendado para comunicacao interna

### 9. Criando um HPA template

Exemplo:

```yaml
{{- if .Values.backend.autoscaling.enabled }}
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: {{ include "kube-starter.backendFullname" . }}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: {{ include "kube-starter.backendFullname" . }}
  minReplicas: {{ .Values.backend.autoscaling.minReplicas }}
  maxReplicas: {{ .Values.backend.autoscaling.maxReplicas }}
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: {{ .Values.backend.autoscaling.targetCPUUtilizationPercentage }}
{{- end }}
```

Pontos importantes:

- HPA precisa de Metrics Server no cluster
- os containers precisam de `resources.requests`
- quando HPA esta ativo, evite controlar `replicas` manualmente no `Deployment`

### 10. Validando o chart

Valide sintaxe e renderizacao:

```bash
helm lint ./helm/kube-starter
helm template kube-starter ./helm/kube-starter
```

Renderize com overrides:

```bash
helm template kube-starter ./helm/kube-starter \
  --set backend.image.repository=kube-backend \
  --set backend.image.tag=latest \
  --set frontend.image.repository=kube-frontend \
  --set frontend.image.tag=latest
```

Instale ou atualize no cluster:

```bash
helm upgrade --install kube-starter ./helm/kube-starter \
  --namespace kube-starter \
  --create-namespace
```

Remova:

```bash
helm uninstall kube-starter -n kube-starter
```

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

Observacao: o [docker-compose.yml](docker-compose.yml) aceita `BACKEND_PORT` e `FRONTEND_PORT`.

## Execucao Com Cluster

### 1. Fluxo completo com imagens locais no kind

Este fluxo cria imagens Docker locais, carrega essas imagens no cluster `kind` e sobe a aplicacao no Kubernetes.

#### 1.1 Validar ferramentas

```bash
docker version
kind version
kubectl version --client
helm version
```

#### 1.2 Buildar aplicacao localmente

Backend:

```bash
cd backend
npm ci
npm run build
cd ..
```

Frontend:

```bash
cd frontend
npm ci
npm run build
cd ..
```

#### 1.3 Buildar imagens Docker locais

```bash
docker build -t kube-backend:latest ./backend
docker build -t kube-frontend:latest ./frontend
```

Conferencia:

```bash
docker images kube-backend
docker images kube-frontend
```

#### 1.4 Criar cluster kind

```bash
kind create cluster --name kube-starter
kubectl config use-context kind-kube-starter
```

Se o cluster ja existir:

```bash
kind get clusters
kubectl config use-context kind-kube-starter
```

#### 1.5 Verificar cluster

```bash
kubectl get nodes
kubectl cluster-info --context kind-kube-starter
```

#### 1.6 Carregar imagens locais no kind

O `kind` roda o Kubernetes dentro de containers Docker. Por isso, uma imagem existente no Docker local ainda precisa ser carregada para dentro do cluster.

```bash
kind load docker-image kube-backend:latest --name kube-starter
kind load docker-image kube-frontend:latest --name kube-starter
```

Conferencia opcional dentro do node do `kind`:

```bash
docker exec kube-starter-control-plane crictl images | grep kube-
```

#### 1.7 Instalar Metrics Server para HPA

O chart cria HPAs por padrao. Para o HPA enxergar CPU e memoria, o cluster precisa do Metrics Server.

```bash
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server
helm repo update metrics-server
helm upgrade --install metrics-server metrics-server/metrics-server \
  --namespace kube-system \
  --set args[0]=--kubelet-insecure-tls
```

Se o repositorio Helm ja existir localmente, execute apenas:

```bash
helm repo update metrics-server
```

Verificacao:

```bash
kubectl rollout status deployment/metrics-server -n kube-system --timeout=300s
kubectl get apiservice v1beta1.metrics.k8s.io
```

#### 1.8 Subir aplicacao no cluster com Helm

```bash
helm lint ./helm/kube-starter
helm template kube-starter ./helm/kube-starter
helm upgrade --install kube-starter ./helm/kube-starter \
  --namespace kube-starter \
  --create-namespace \
  --set backend.image.repository=kube-backend \
  --set backend.image.tag=latest \
  --set frontend.image.repository=kube-frontend \
  --set frontend.image.tag=latest
```

#### 1.9 Esperar rollout

```bash
kubectl rollout status deployment/kube-starter-kube-starter-backend -n kube-starter --timeout=300s
kubectl rollout status deployment/kube-starter-kube-starter-frontend -n kube-starter --timeout=300s
```

#### 1.10 Inspecionar recursos

```bash
kubectl get pods -n kube-starter
kubectl get deployments,services,hpa -n kube-starter
kubectl describe hpa -n kube-starter
```

As metricas podem demorar alguns segundos para aparecer:

```bash
kubectl top pods -n kube-starter
```

#### 1.11 Testar backend e frontend

Em um terminal:

```bash
kubectl port-forward service/kube-starter-kube-starter-backend -n kube-starter 3003:3000
```

Em outro terminal:

```bash
curl http://localhost:3003/api/health
curl http://localhost:3003/api/message
curl http://localhost:3003/api/stats
```

Para o frontend, em um terminal:

```bash
kubectl port-forward service/kube-starter-kube-starter-frontend -n kube-starter 9082:80
```

Em outro terminal:

```bash
curl http://localhost:9082
curl http://localhost:9082/api/health
curl http://localhost:9082/api/stats
```

#### 1.12 Atualizar imagem depois de alterar codigo

Sempre que backend ou frontend mudar, faca novo build e recarregue a imagem no `kind`.

Backend:

```bash
docker build -t kube-backend:latest ./backend
kind load docker-image kube-backend:latest --name kube-starter
kubectl rollout restart deployment/kube-starter-kube-starter-backend -n kube-starter
kubectl rollout status deployment/kube-starter-kube-starter-backend -n kube-starter --timeout=300s
```

Frontend:

```bash
docker build -t kube-frontend:latest ./frontend
kind load docker-image kube-frontend:latest --name kube-starter
kubectl rollout restart deployment/kube-starter-kube-starter-frontend -n kube-starter
kubectl rollout status deployment/kube-starter-kube-starter-frontend -n kube-starter --timeout=300s
```

#### 1.13 Limpar ambiente

Remover somente a aplicacao:

```bash
helm uninstall kube-starter -n kube-starter
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

O chart cria HPA por padrao para backend e frontend. Para desabilitar:

```bash
helm upgrade --install kube-starter ./helm/kube-starter \
  --namespace kube-starter \
  --create-namespace \
  --set backend.autoscaling.enabled=false \
  --set frontend.autoscaling.enabled=false
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
kubectl get deployments,services,hpa,ingresses -n kube-starter
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

No `kind`, o Argo CD tambem usa as imagens locais carregadas no cluster. Antes de aplicar as `Applications`, execute os passos `1.2` ate `1.6` deste guia para buildar `kube-backend:latest`, buildar `kube-frontend:latest` e carregar as duas imagens no cluster.

O Argo CD nao builda imagem. Ele renderiza o chart Helm a partir do Git e pede ao Kubernetes para rodar as imagens declaradas no `values.yaml`.

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
kubectl apply -f argocd/metrics-server-application.yaml
kubectl apply -f argocd/kube-starter-application.yaml
```

Esperando sincronizacao:

```bash
argocd app wait metrics-server --health --sync --timeout 300
argocd app wait kube-starter --health --sync --timeout 300
```

Se estiver sem login no CLI do Argo CD, acompanhe via `kubectl`:

```bash
kubectl get applications.argoproj.io -n argocd
kubectl get pods -n kube-system -l app.kubernetes.io/name=metrics-server
kubectl get pods -n kube-starter
```

Verificando status:

```bash
kubectl get applications.argoproj.io -A
kubectl get apiservice v1beta1.metrics.k8s.io
kubectl get hpa -n kube-starter
kubectl get applications.argoproj.io kube-starter -n argocd \
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

Atualizando imagens locais com Argo CD:

```bash
docker build -t kube-backend:latest ./backend
docker build -t kube-frontend:latest ./frontend
kind load docker-image kube-backend:latest --name kube-starter
kind load docker-image kube-frontend:latest --name kube-starter
kubectl rollout restart deployment/kube-starter-kube-starter-backend -n kube-starter
kubectl rollout restart deployment/kube-starter-kube-starter-frontend -n kube-starter
kubectl rollout status deployment/kube-starter-kube-starter-backend -n kube-starter --timeout=300s
kubectl rollout status deployment/kube-starter-kube-starter-frontend -n kube-starter --timeout=300s
```

## Validacao

### O que foi validado

- `backend`: `npm run build`
- `frontend`: `npm run build`
- `Docker Compose`: build, subida e teste real com `curl`
- `Helm`: `helm lint`, `helm template`, deploy em `kind` e teste real com `curl`
- `Argo CD`: instalacao no `kind`, `Application` com status `Synced Healthy` e teste real com `curl`
- `HPA`: renderizacao dos objetos `HorizontalPodAutoscaler` para frontend e backend

### Checklist rapido

```bash
cd backend && npm run build
cd ../frontend && npm run build
cd .. && docker compose build
docker build -t kube-backend:latest ./backend
docker build -t kube-frontend:latest ./frontend
kind load docker-image kube-backend:latest --name kube-starter
kind load docker-image kube-frontend:latest --name kube-starter
helm lint ./helm/kube-starter
helm template kube-starter ./helm/kube-starter
```

### Sinais de sucesso

- backend responde `/api/health`
- frontend responde `/`
- `kubectl get pods -n kube-starter` mostra pods `Running`
- `kubectl get applications.argoproj.io -A` mostra `kube-starter` como `Synced Healthy`
- `kubectl get hpa -n kube-starter` mostra metricas quando o Metrics Server esta saudavel

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

### HPA sem metricas

Verifique se o Metrics Server esta instalado e publicando a API de metricas:

```bash
kubectl get apiservice v1beta1.metrics.k8s.io
kubectl top pods -n kube-starter
kubectl describe hpa -n kube-starter
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

- [docs/debugging-cheatsheet.md](docs/debugging-cheatsheet.md)

## Diferencas Entre As Ferramentas

### Docker

- Use `Docker` quando voce quer montar e executar cada servico manualmente.
- escopo: container individual
- entrada: `Dockerfile`
- estado desejado: controlado por voce no terminal
- melhor uso: teste isolado de backend ou frontend

### Docker Compose

- Use `Docker Compose` quando voce quer um ambiente local integrado sem precisar subir os containers um por um.
- escopo: varios containers relacionados
- entrada: `docker-compose.yml`
- estado desejado: controlado por um arquivo unico local
- melhor uso: desenvolvimento local e smoke test da stack

### Helm

- Use `Helm` quando voce quer empacotar manifests Kubernetes com valores configuraveis.
- escopo: aplicacao no Kubernetes
- entrada: chart Helm
- estado desejado: aplicado quando voce executa `helm install` ou `helm upgrade`
- melhor uso: deploy manual ou automatizado no cluster

### Argo CD

- Use `Argo CD` quando voce quer GitOps de verdade: o repositorio Git vira a fonte de verdade e o cluster e reconciliado continuamente.
- escopo: operacao continua no Kubernetes
- entrada: Git como fonte de verdade
- estado desejado: mantido automaticamente pelo controller
- melhor uso: GitOps com reconciliacao continua

Resumo pratico:

- `Docker` nao substitui `Compose`: ele e a base de imagem e execucao individual
- `Docker Compose` nao substitui `Helm`: ele resolve ambiente local, nao cluster Kubernetes
- `Helm` nao substitui `Argo CD`: Helm empacota e instala; Argo CD observa Git e reconcilia continuamente
- `Argo CD` pode usar `Helm` como fonte. Neste projeto, essa e a combinacao mais natural para GitOps

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
    ^
    |
[ HPA + Metrics Server ]
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
[ Metrics Server Application + kube-starter Application ]
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

## Fundamentos Kubernetes

### Componentes principais

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

- `kube-apiserver`: porta de entrada do cluster. Recebe, valida e expoe a API
- `etcd`: banco chave-valor que persiste o estado do cluster
- `controller-manager`: reconcilia estado desejado e estado atual
- `scheduler`: escolhe em qual node cada Pod pendente vai rodar
- `kubelet`: agente do node que materializa os Pods em execucao

### Objetos principais

- `Pod`: unidade minima executavel
- `Deployment`: garante replicas, rollout e recriacao de Pods
- `Service`: endpoint estavel para acessar Pods
- `Ingress`: entrada HTTP/HTTPS na frente de um ou mais Services
- `HorizontalPodAutoscaler`: escala replicas a partir de metricas
- `Metrics Server`: fornece metricas de CPU e memoria para o HPA

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
    ^
    |
[ HPA ]
    ^
    |
[ Metrics Server ]
```

Detalhes:

- [docs/kubernetes-fundamentals.md](docs/kubernetes-fundamentals.md)
