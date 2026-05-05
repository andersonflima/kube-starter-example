# Workflows And Tooling

Este documento aprofunda a diferenca entre `Docker`, `Docker Compose`, `Helm` e `Argo CD`.

## 1. Docker

### O que e

`Docker` empacota uma aplicacao em imagem e executa essa imagem como container.

### O que ele resolve

- padrao de runtime previsivel
- build repetivel
- isolamento de processo
- distribuicao por imagem

### O que ele nao resolve sozinho

- orquestracao de varios servicos
- descoberta de servicos em cluster
- rollout e auto-healing no Kubernetes
- reconciliacao automatica entre Git e cluster

### Exemplo neste projeto

- `backend/Dockerfile`: imagem do backend Node.js
- `frontend/Dockerfile`: imagem do frontend com build Vite e runtime em nginx

### Quando usar

- quando voce quer validar um servico isolado
- quando voce quer publicar uma imagem em registry
- quando a proxima etapa do pipeline depende da imagem pronta

### Comandos detalhados

Build do backend:

```bash
docker build -t kube-backend ./backend
```

Build do frontend:

```bash
docker build -t kube-frontend ./frontend
```

Execucao:

```bash
docker network create kube-starter
docker run -d --name backend --network kube-starter -p 3000:3000 kube-backend
docker run -d --name frontend --network kube-starter \
  -e BACKEND_SERVICE_URL=http://backend:3000 \
  -p 8080:80 kube-frontend
```

Validacao:

```bash
curl http://localhost:3000/api/health
curl http://localhost:8080/api/stats
```

## 2. Docker Compose

### O que e

`Docker Compose` coordena multiplos containers relacionados em uma maquina local ou host unico.

### O que ele resolve

- subida integrada de varios servicos
- rede compartilhada
- configuracao local centralizada
- facilidade para desenvolvimento

### O que ele nao resolve

- alta disponibilidade real
- escalonamento nativo de cluster
- declaracao de objetos Kubernetes
- GitOps

### Exemplo neste projeto

O [docker-compose.yml](../docker-compose.yml) sobe:

- `backend`
- `frontend`

com o frontend apontando para `http://backend:3000`.

### Quando usar

- desenvolvimento local
- smoke tests
- demos rapidas

### Comandos detalhados

Subida padrao:

```bash
docker compose up --build
```

Subida em background:

```bash
docker compose up --build -d
```

Subida com portas alternativas:

```bash
BACKEND_PORT=3002 FRONTEND_PORT=9081 docker compose up --build -d
```

Validacao:

```bash
curl http://localhost:3002/api/health
curl http://localhost:9081/api/stats
```

Parada:

```bash
docker compose down
```

### Windows PowerShell

O fluxo recomendado no Windows e usar WSL2, mantendo os mesmos comandos de Linux. Se estiver usando PowerShell diretamente, ajuste a declaracao de variaveis:

```powershell
$env:BACKEND_PORT = "3002"
$env:FRONTEND_PORT = "9081"
docker compose up --build -d
```

## 3. Helm

### O que e

`Helm` e um package manager para Kubernetes. Ele organiza manifests em chart e permite parametrizacao via `values.yaml`.

### O que ele resolve

- empacotamento dos manifests
- reutilizacao de templates
- configuracao por ambiente
- instalacao e upgrade previsiveis

### O que ele nao resolve sozinho

- observacao continua do Git
- reconciliacao automatica apos drift
- politica GitOps

### Exemplo neste projeto

O chart em [helm/kube-starter](../helm/kube-starter) cria:

- `Deployment` do backend
- `Service` do backend
- `HorizontalPodAutoscaler` do backend
- `Deployment` do frontend
- `Service` do frontend
- `HorizontalPodAutoscaler` do frontend
- `Ingress` opcional

### Quando usar

- quando voce quer empacotar aplicacoes para Kubernetes
- quando precisa de valores por ambiente
- quando ainda prefere deploy manual ou controlado pelo CI

### Comandos detalhados

Validacao estatica:

```bash
helm lint ./helm/kube-starter
helm template kube-starter ./helm/kube-starter
```

Deploy:

```bash
helm upgrade --install kube-starter ./helm/kube-starter
```

Deploy com override:

```bash
helm upgrade --install kube-starter ./helm/kube-starter \
  --set backend.image.repository=seu-registry/kube-backend \
  --set backend.image.tag=latest \
  --set frontend.image.repository=seu-registry/kube-frontend \
  --set frontend.image.tag=latest
```

No PowerShell, use crase para continuar comandos em varias linhas:

```powershell
helm upgrade --install kube-starter ./helm/kube-starter `
  --set backend.image.repository=seu-registry/kube-backend `
  --set backend.image.tag=latest `
  --set frontend.image.repository=seu-registry/kube-frontend `
  --set frontend.image.tag=latest
```

Inspecao:

```bash
kubectl get deployments,services,ingresses
kubectl get pods
```

### HPA e metricas

O HPA depende de duas coisas:

- `resources.requests` nos containers
- Metrics Server publicando a API `metrics.k8s.io`

Neste projeto, o chart define requests/limits e cria HPAs por padrao. O Metrics Server pode ser instalado pelo manifesto GitOps em [argocd/metrics-server-application.yaml](../argocd/metrics-server-application.yaml).

Validacao:

```bash
kubectl get apiservice v1beta1.metrics.k8s.io
kubectl top pods -n kube-starter
kubectl get hpa -n kube-starter
```

## 4. Argo CD

### O que e

`Argo CD` e um controller GitOps para Kubernetes. Ele observa um repositorio Git e garante que o cluster reflita o estado versionado ali.

### O que ele resolve

- reconciliacao continua
- auditoria baseada em Git
- visibilidade de drift
- auto-sync opcional
- self-heal opcional

### O que ele nao substitui

- nao substitui o Docker para build de imagem
- nao substitui o Helm como mecanismo de template
- nao substitui pipeline de testes

### Exemplo neste projeto

O arquivo [argocd/kube-starter-application.yaml](../argocd/kube-starter-application.yaml) manda o Argo CD usar:

- repositorio: `https://github.com/andersonflima/kube-starter-example.git`
- path: `helm/kube-starter`
- namespace de destino: `kube-starter`

### Quando usar

- homologacao e producao
- times que querem rastreabilidade
- multiplos ambientes
- operacao baseada em pull e nao em push manual

### Comandos detalhados

Instalacao do Argo CD:

```bash
kubectl create namespace argocd
kubectl apply -n argocd --server-side --force-conflicts \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

Acesso:

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
argocd admin initial-password -n argocd
argocd login localhost:8080 --insecure
```

Aplicacao deste projeto:

```bash
kubectl apply -f argocd/kube-starter-application.yaml
argocd app get kube-starter
argocd app sync kube-starter
argocd app wait kube-starter --health --sync
```

### Exemplo com kind

```bash
kind create cluster --name kube-starter
kind load docker-image kube-backend:latest --name kube-starter
kind load docker-image kube-frontend:latest --name kube-starter
kubectl create namespace argocd
kubectl apply -n argocd --server-side --force-conflicts \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl apply -f argocd/kube-starter-application.yaml
kubectl get applications.argoproj.io -n argocd
```

## Diferencas praticas

### Docker vs Docker Compose

- `Docker` opera imagem e container individual
- `Docker Compose` opera a stack local inteira

### Docker Compose vs Helm

- `Docker Compose` descreve runtime local em host unico
- `Helm` descreve recursos Kubernetes para cluster

### Helm vs Argo CD

- `Helm` empacota e instala
- `Argo CD` observa Git e reconcilia continuamente
- `Argo CD` pode usar `Helm` como fonte

## Como escolher

### Use Docker

- quando seu problema e build e runtime de um servico

### Use Docker Compose

- quando seu problema e integrar servicos localmente

### Use Helm

- quando seu problema e parametrizar e instalar no Kubernetes

### Use Argo CD

- quando seu problema e governanca, drift, historico e automacao continua

## Exemplo de linha evolutiva real

Em muitos times, a maturidade segue este caminho:

1. `Docker` para empacotar cada servico
2. `Docker Compose` para subir tudo localmente
3. `Helm` para padronizar o deploy no cluster
4. `Argo CD` para automatizar a reconciliacao a partir do Git

Essa sequencia faz sentido porque cada ferramenta resolve um problema diferente, e nao porque uma elimina a outra.
