# Kube Starter

Tutorial pratico para sair do zero e chegar em uma stack Kubernetes local com:

- backend `Express + TypeScript`
- frontend `React + Vite + nginx`
- imagens Docker produtivas
- ambiente local com Docker Compose
- manifests Kubernetes puros
- chart Helm da aplicacao
- cluster local com `kind`
- GitOps com Argo CD usando app-of-apps
- ingress-nginx
- Metrics Server para HPA
- Prometheus, Alertmanager e Grafana via kube-prometheus-stack

## Objetivo

Este repositorio ensina a evoluir uma aplicacao simples ate uma estrutura operacional robusta, sem esconder as camadas.

O fluxo recomendado e:

```text
Dockerfile -> Docker Compose -> manifests -> Helm chart -> Argo CD -> observabilidade
```

Cada etapa funciona sozinha. O caminho completo sobe um cluster local pronto para estudo e experimentacao.

## Pre-requisitos

- `node`
- `npm`
- `docker`
- `docker compose`
- `kind`
- `kubectl`
- `helm`
- `curl`

Verificacao rapida:

macOS/Linux:

```bash
make check
```

Windows PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\check-tools.ps1
```

Veja o guia completo por sistema operacional em [docs/tutorials/03-cross-platform-setup.md](docs/tutorials/03-cross-platform-setup.md).

## Estrutura

```text
.
|-- backend/                 # API Express em TypeScript
|-- frontend/                # UI React/Vite servida por nginx
|-- helm/kube-starter/       # chart Helm da aplicacao
|-- manifests/kube-starter/  # manifests Kubernetes educacionais
|-- clusters/local/          # configuracao kind
|-- platform/                # values dos charts operacionais
|-- argocd/                  # AppProject, root app e Applications
|-- scripts/                 # automacoes locais
`-- docs/                    # guias complementares
```

## Arquitetura

```text
[ Browser ]
    |
    v
[ ingress-nginx :8080 ]
    |
    v
[ frontend Service -> nginx Pod ]
    |
    v
[ backend Service -> Node.js Pod ]
    |
    v
[/api/* e /metrics]
```

Camada operacional:

```text
[ Git repository ]
      |
      v
[ Argo CD root Application ]
      |
      v
[ ingress-nginx | metrics-server | kube-prometheus-stack | kube-starter ]
      |
      v
[ Prometheus coleta /metrics | Grafana visualiza | HPA usa Metrics Server ]
```

## Caminho Rapido

Sobe tudo: imagens, cluster kind, Argo CD e plataforma GitOps.

macOS/Linux:

```bash
make up
```

Windows PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\up.ps1
```

O fluxo GitOps le o repositorio remoto declarado em `argocd/`. Antes de usar `make up` com alteracoes ainda nao integradas, publique a branch e ajuste `targetRevision`, ou faca merge para a branch declarada.

Depois acompanhe:

macOS/Linux:

```bash
make status
```

Windows PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\status.ps1
```

Teste HTTP:

macOS/Linux:

```bash
make smoke
```

Windows PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\smoke-test.ps1
```

URLs locais quando o sync terminar:

- aplicacao: `http://kube-starter.localhost:8080`
- Grafana: `http://grafana.localhost:8080` (`admin` / `admin`)
- Prometheus: `http://prometheus.localhost:8080`
- Alertmanager: `http://alertmanager.localhost:8080`

A senha do Grafana e didatica para ambiente local. Em producao, use segredo externo ou sealed/encrypted secrets.

Argo CD UI:

```bash
kubectl port-forward svc/argocd-server -n argocd 8081:443
```

Senha inicial:

```bash
argocd admin initial-password -n argocd
```

Acesse `https://localhost:8081`.

Para destruir o cluster local:

macOS/Linux:

```bash
make down
```

Windows PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\destroy-kind-cluster.ps1
```

## Tutorial Do Zero

O guia completo esta em [docs/tutorials/00-from-zero-to-platform.md](docs/tutorials/00-from-zero-to-platform.md).

Guias de apoio:

- [onde alterar imagem, porta, tag, HPA, host e GitOps](docs/tutorials/01-where-to-change-what.md)
- [criando os arquivos do zero e entendendo os padroes](docs/tutorials/02-file-by-file-from-zero.md)
- [setup e comandos para Windows, macOS e Linux](docs/tutorials/03-cross-platform-setup.md)

Ele cobre:

1. criar o backend
2. criar o frontend
3. criar Dockerfiles produtivos
4. buildar e rodar containers manualmente
5. subir a stack com Docker Compose
6. criar cluster local com kind
7. aplicar namespaces e manifests puros
8. criar e instalar o chart Helm
9. instalar Argo CD
10. configurar app-of-apps
11. instalar ingress-nginx, Metrics Server, Prometheus e Grafana
12. validar HPA, metricas e endpoints

## Docker

Build das imagens:

macOS/Linux:

```bash
docker build -t kube-backend:latest ./backend
docker build -t kube-frontend:latest ./frontend
```

Windows PowerShell:

```powershell
docker build -t kube-backend:latest .\backend
docker build -t kube-frontend:latest .\frontend
```

Rede e containers:

macOS/Linux:

```bash
docker network create kube-starter
docker run -d --name backend --network kube-starter -p 3000:3000 kube-backend:latest
docker run -d --name frontend --network kube-starter \
  -e BACKEND_SERVICE_URL=http://backend:3000 \
  -p 8080:80 kube-frontend:latest
```

Windows PowerShell:

```powershell
docker network create kube-starter
docker run -d --name backend --network kube-starter -p 3000:3000 kube-backend:latest
docker run -d --name frontend --network kube-starter -e BACKEND_SERVICE_URL=http://backend:3000 -p 8080:80 kube-frontend:latest
```

Validacao:

macOS/Linux:

```bash
curl http://localhost:3000/api/health
curl http://localhost:8080/api/stats
```

Windows PowerShell:

```powershell
Invoke-WebRequest -UseBasicParsing http://localhost:3000/api/health
Invoke-WebRequest -UseBasicParsing http://localhost:8080/api/stats
```

Limpeza:

```bash
docker stop frontend backend
docker rm frontend backend
docker network rm kube-starter
```

## Docker Compose

Subida local integrada:

```bash
docker compose up --build
```

Em background:

```bash
docker compose up --build -d
```

Validacao:

```bash
curl http://localhost:3000/api/health
curl http://localhost:8080/api/stats
```

Portas alternativas:

macOS/Linux:

```bash
BACKEND_PORT=3002 FRONTEND_PORT=9081 docker compose up --build -d
```

Windows PowerShell:

```powershell
$env:BACKEND_PORT = "3002"
$env:FRONTEND_PORT = "9081"
docker compose up --build -d
```

Parada:

```bash
docker compose down
```

## Kubernetes Com Manifests

Crie o cluster e carregue as imagens:

macOS/Linux:

```bash
make build-images
make cluster-create
make images-load
```

Windows PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build-images.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\create-kind-cluster.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\load-kind-images.ps1
```

Instale ingress-nginx e Metrics Server via Helm para dar suporte ao Ingress e ao HPA:

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server
helm repo update

helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --values platform/ingress-nginx/values.yaml

helm upgrade --install metrics-server metrics-server/metrics-server \
  --namespace kube-system \
  --values platform/metrics-server/values.yaml
```

Aplique os manifests puros:

```bash
kubectl apply -f manifests/kube-starter/base
```

Validacao:

```bash
kubectl get pods,svc,hpa,ingress -n kube-starter
curl http://kube-starter.localhost:8080/api/health
```

O `ServiceMonitor` fica separado porque depende das CRDs do Prometheus Operator:

```bash
kubectl apply -f manifests/kube-starter/observability
```

Use esse caminho para aprender os objetos Kubernetes sem Helm.

## Kubernetes Com Helm

Valide o chart:

```bash
make helm-lint
make helm-template
```

Instale:

```bash
helm upgrade --install kube-starter ./helm/kube-starter \
  --namespace kube-starter \
  --create-namespace
```

Com Ingress local:

```bash
helm upgrade --install kube-starter ./helm/kube-starter \
  --namespace kube-starter \
  --create-namespace \
  --values helm/kube-starter/values.yaml \
  --values helm/kube-starter/values-local.yaml
```

Atalho equivalente:

```bash
make helm-install-local
```

Com ServiceMonitor:

```bash
helm upgrade --install kube-starter ./helm/kube-starter \
  --namespace kube-starter \
  --create-namespace \
  --values helm/kube-starter/values.yaml \
  --values helm/kube-starter/values-observability.yaml
```

Remocao:

```bash
make helm-uninstall
```

## GitOps Com Argo CD

A estrutura GitOps usa app-of-apps:

```text
argocd/root-application.yaml
argocd/projects/kube-starter-project.yaml
argocd/applications/ingress-nginx-application.yaml
argocd/applications/metrics-server-application.yaml
argocd/applications/kube-prometheus-stack-application.yaml
argocd/applications/kube-starter-application.yaml
```

Instalacao manual:

macOS/Linux:

```bash
make cluster-create
make build-images
make images-load
make argocd-install
make platform-bootstrap
```

Windows PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\create-kind-cluster.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\build-images.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\load-kind-images.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\install-argocd.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\bootstrap-platform.ps1
```

O Argo CD passa a reconciliar:

- `ingress-nginx` no namespace `ingress-nginx`
- `metrics-server` no namespace `kube-system`
- `kube-prometheus-stack` no namespace `monitoring`
- `kube-starter` no namespace `kube-starter`

Se voce estiver usando um fork ou branch diferente, ajuste `repoURL` e `targetRevision` nos arquivos em `argocd/`.

## Observabilidade

O backend expoe:

- `GET /api/health`
- `GET /api/message`
- `GET /api/stats`
- `GET /metrics`

O chart Helm tem `ServiceMonitor` opcional. No fluxo GitOps ele e habilitado por `helm/kube-starter/values-observability.yaml`.

Checagens:

```bash
kubectl get servicemonitors.monitoring.coreos.com -A
kubectl get hpa -n kube-starter
kubectl top pods -n kube-starter
curl http://prometheus.localhost:8080/-/ready
```

## Atualizar Codigo

Depois de alterar backend ou frontend:

macOS/Linux:

```bash
make build-images
make images-load
kubectl rollout restart deployment/kube-starter-backend -n kube-starter
kubectl rollout restart deployment/kube-starter-frontend -n kube-starter
kubectl rollout status deployment/kube-starter-backend -n kube-starter --timeout=300s
kubectl rollout status deployment/kube-starter-frontend -n kube-starter --timeout=300s
```

Windows PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build-images.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\load-kind-images.ps1
kubectl rollout restart deployment/kube-starter-backend -n kube-starter
kubectl rollout restart deployment/kube-starter-frontend -n kube-starter
kubectl rollout status deployment/kube-starter-backend -n kube-starter --timeout=300s
kubectl rollout status deployment/kube-starter-frontend -n kube-starter --timeout=300s
```

Em ambiente real, o pipeline deve publicar as imagens em um registry e atualizar a tag usada pelo chart.

Para detalhes de onde alterar imagem em Docker, manifests, Helm e Argo CD, veja [docs/tutorials/01-where-to-change-what.md](docs/tutorials/01-where-to-change-what.md).

## Documentacao

- [Tutorial do zero ate a plataforma](docs/tutorials/00-from-zero-to-platform.md)
- [Onde alterar cada configuracao](docs/tutorials/01-where-to-change-what.md)
- [Criando os arquivos do zero](docs/tutorials/02-file-by-file-from-zero.md)
- [Setup cross-platform](docs/tutorials/03-cross-platform-setup.md)
- [Workflows e ferramentas](docs/workflows-and-tooling.md)
- [Fundamentos Kubernetes](docs/kubernetes-fundamentals.md)
- [GitOps com Argo CD](docs/argocd-gitops.md)
- [Debugging cheatsheet](docs/debugging-cheatsheet.md)

## Referencias Oficiais

- Argo CD Getting Started: https://argo-cd.readthedocs.io/en/stable/getting_started/
- ingress-nginx: https://kubernetes.github.io/ingress-nginx/deploy/
- Metrics Server: https://github.com/kubernetes-sigs/metrics-server
- kube-prometheus-stack: https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack
- kind ingress: https://kind.sigs.k8s.io/docs/user/ingress/
