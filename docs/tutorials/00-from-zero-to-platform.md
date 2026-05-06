# Tutorial Do Zero Ate A Plataforma Kubernetes

Este guia mostra a construcao incremental do projeto. A ideia e entender cada camada antes de automatizar tudo.

Mapas complementares:

- [onde alterar cada configuracao](01-where-to-change-what.md)
- [criando os arquivos do zero](02-file-by-file-from-zero.md)
- [setup e comandos para Windows, macOS e Linux](03-cross-platform-setup.md)

## 1. Aplicacao

A stack tem dois servicos:

- `backend`: API HTTP em Express + TypeScript
- `frontend`: aplicacao React/Vite servida por nginx

Endpoints do backend:

```text
GET /api/health
GET /api/message
GET /api/stats
GET /metrics
```

O endpoint `/metrics` expoe metricas em formato Prometheus.

## 2. Backend Do Zero

Criacao base:

```bash
mkdir -p backend/src
cd backend
npm init -y
npm install express cors prom-client
npm install -D typescript tsx @types/node @types/express @types/cors
npx tsc --init
```

Scripts esperados em `backend/package.json`:

```json
{
  "scripts": {
    "dev": "tsx watch src/server.ts",
    "build": "tsc -p tsconfig.json",
    "start": "node dist/server.js"
  }
}
```

Validacao:

```bash
cd backend
npm ci
npm run build
npm run start
```

Em outro terminal:

```bash
curl http://localhost:3000/api/health
curl http://localhost:3000/metrics
```

## 3. Frontend Do Zero

Criacao base:

```bash
npm create vite@latest frontend -- --template react-ts
cd frontend
npm install
```

Validacao:

```bash
cd frontend
npm run build
npm run preview
```

O nginx de runtime faz proxy de `/api` para o backend usando `BACKEND_SERVICE_URL`.

## 4. Dockerfile Do Backend

O backend usa multi-stage build:

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
USER node
EXPOSE 3000
CMD ["npm", "run", "start"]
```

Motivo:

- `dependencies`: instalacao reproduzivel
- `build`: compilacao TypeScript
- `runtime`: imagem final menor, sem dependencias de desenvolvimento

Build:

```bash
docker build -t kube-backend:latest ./backend
```

Execucao:

```bash
docker run --rm -p 3000:3000 kube-backend:latest
```

## 5. Dockerfile Do Frontend

O frontend compila com Node.js e roda com nginx:

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

Build:

```bash
docker build -t kube-frontend:latest ./frontend
```

Execucao apontando para um backend local:

```bash
docker run --rm -p 8080:80 \
  -e BACKEND_SERVICE_URL=http://host.docker.internal:3000 \
  kube-frontend:latest
```

## 6. Docker Manual

Crie uma rede:

```bash
docker network create kube-starter
```

Suba backend e frontend:

```bash
docker run -d --name backend --network kube-starter -p 3000:3000 kube-backend:latest
docker run -d --name frontend --network kube-starter \
  -e BACKEND_SERVICE_URL=http://backend:3000 \
  -p 8080:80 kube-frontend:latest
```

Valide:

```bash
curl http://localhost:3000/api/health
curl http://localhost:8080/api/stats
```

Limpe:

```bash
docker stop frontend backend
docker rm frontend backend
docker network rm kube-starter
```

## 7. Docker Compose

`docker-compose.yml` sobe os dois servicos na mesma rede:

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

Parada:

```bash
docker compose down
```

## 8. Cluster Local Com kind

O arquivo [clusters/local/kind-config.yaml](../../clusters/local/kind-config.yaml) cria um control plane com portas locais para Ingress:

```text
localhost:8080 -> ingress HTTP
localhost:8443 -> ingress HTTPS
```

Crie o cluster:

```bash
kind create cluster --name kube-starter --config clusters/local/kind-config.yaml
kubectl config use-context kind-kube-starter
kubectl get nodes
```

Ou use a automacao:

```bash
make cluster-create
```

## 9. Carregar Imagens No kind

O Docker local e o runtime dentro do cluster kind nao compartilham imagens automaticamente. Carregue as imagens:

```bash
docker build -t kube-backend:latest ./backend
docker build -t kube-frontend:latest ./frontend
kind load docker-image kube-backend:latest --name kube-starter
kind load docker-image kube-frontend:latest --name kube-starter
```

Ou:

```bash
make build-images
make images-load
```

## 10. Instalar Dependencias Do Cluster

Adicione repos Helm:

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
```

Instale ingress-nginx:

```bash
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --values platform/ingress-nginx/values.yaml
```

Instale Metrics Server:

```bash
helm upgrade --install metrics-server metrics-server/metrics-server \
  --namespace kube-system \
  --values platform/metrics-server/values.yaml
```

Instale kube-prometheus-stack:

```bash
helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --values platform/monitoring/values.yaml
```

## 11. Kubernetes Com Manifests Puros

Os manifests em `manifests/kube-starter/base` sao a forma mais explicita de aprender:

```bash
kubectl apply -f manifests/kube-starter/base
```

Eles criam:

- `Namespace`
- `Deployment` do backend
- `Service` do backend
- `Deployment` do frontend
- `Service` do frontend
- `HorizontalPodAutoscaler` do backend
- `HorizontalPodAutoscaler` do frontend
- `Ingress`

Valide:

```bash
kubectl get pods,svc,hpa,ingress -n kube-starter
curl http://kube-starter.localhost:8080/api/health
```

Depois que o Prometheus Operator estiver instalado, aplique o `ServiceMonitor`:

```bash
kubectl apply -f manifests/kube-starter/observability
```

## 12. Helm Chart

O chart em `helm/kube-starter` parametriza os mesmos objetos:

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

Com Ingress:

```bash
helm upgrade --install kube-starter ./helm/kube-starter \
  --namespace kube-starter \
  --create-namespace \
  --set ingress.enabled=true \
  --set ingress.className=nginx \
  --set ingress.hosts[0].host=kube-starter.localhost
```

Com observabilidade:

```bash
helm upgrade --install kube-starter ./helm/kube-starter \
  --namespace kube-starter \
  --create-namespace \
  --values helm/kube-starter/values.yaml \
  --values helm/kube-starter/values-observability.yaml
```

## 13. Argo CD

Instale Argo CD:

```bash
kubectl create namespace argocd
kubectl apply -n argocd --server-side --force-conflicts \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl wait --for=condition=Established crd/applications.argoproj.io --timeout=180s
```

Espere os componentes:

```bash
kubectl rollout status deployment/argocd-server -n argocd --timeout=300s
kubectl rollout status deployment/argocd-repo-server -n argocd --timeout=300s
kubectl rollout status deployment/argocd-redis -n argocd --timeout=300s
kubectl rollout status statefulset/argocd-application-controller -n argocd --timeout=300s
```

Ou use:

```bash
make argocd-install
```

## 14. AppProject E App-Of-Apps

Primeiro aplique o projeto:

```bash
kubectl apply -f argocd/projects/kube-starter-project.yaml
```

Depois aplique a root application:

```bash
kubectl apply -f argocd/root-application.yaml
```

Ou:

```bash
make platform-bootstrap
```

A root application sincroniza os arquivos em `argocd/applications`.

O Argo CD le o repositorio remoto. Se voce estiver trabalhando em uma branch ainda nao integrada, publique a branch e ajuste `targetRevision` nos manifests de `argocd/`, ou sincronize depois que a mudanca estiver na branch declarada.

## 15. O Que O Argo CD Reconcila

```text
argocd/root-application.yaml
  -> argocd/applications/ingress-nginx-application.yaml
  -> argocd/applications/metrics-server-application.yaml
  -> argocd/applications/kube-prometheus-stack-application.yaml
  -> argocd/applications/kube-starter-application.yaml
```

Os values dos charts externos ficam no repositorio:

```text
platform/ingress-nginx/values.yaml
platform/metrics-server/values.yaml
platform/monitoring/values.yaml
```

Essa separacao deixa claro o que e chart externo e o que e configuracao propria.

## 16. Acessos Locais

Aplicacao:

```bash
curl http://kube-starter.localhost:8080/api/health
```

Grafana:

```text
http://grafana.localhost:8080
usuario: admin
senha: admin
```

Essa senha e apenas para laboratorio local. Em producao, use um segredo externo ou sealed/encrypted secrets.

Prometheus:

```text
http://prometheus.localhost:8080
```

Alertmanager:

```text
http://alertmanager.localhost:8080
```

Argo CD:

```bash
kubectl port-forward svc/argocd-server -n argocd 8081:443
argocd admin initial-password -n argocd
```

Abra `https://localhost:8081`.

## 17. Validacao Operacional

Applications:

```bash
kubectl get applications.argoproj.io -n argocd
```

Pods:

```bash
kubectl get pods -n ingress-nginx
kubectl get pods -n monitoring
kubectl get pods -n kube-starter
```

HPA:

```bash
kubectl get hpa -n kube-starter
kubectl top pods -n kube-starter
```

Prometheus:

```bash
kubectl get servicemonitors.monitoring.coreos.com -A
curl http://prometheus.localhost:8080/-/ready
```

Smoke test:

```bash
make smoke
```

## 18. Atualizacao De Imagem

Fluxo local com kind:

```bash
make build-images
make images-load
kubectl rollout restart deployment/kube-starter-backend -n kube-starter
kubectl rollout restart deployment/kube-starter-frontend -n kube-starter
```

Fluxo real:

```text
commit -> CI -> build -> push da imagem -> update da tag no Git -> Argo CD sync
```

O Argo CD nao builda imagem. Ele reconcilia o estado declarado no Git.

Resumo de onde alterar:

- Docker local: tag usada no comando `docker build -t`.
- Scripts: variaveis `BACKEND_IMAGE`, `FRONTEND_IMAGE` e `IMAGE_TAG`.
- Manifests puros: campo `image` nos Deployments em `manifests/kube-starter/base`.
- Helm: `backend.image.*` e `frontend.image.*` em `helm/kube-starter/values.yaml`.
- Argo CD: altere o values versionado no Git ou adicione um values especifico na Application.

Detalhes completos: [01-where-to-change-what.md](01-where-to-change-what.md).

## 19. Limpeza

Remover aplicacao Helm:

```bash
helm uninstall kube-starter -n kube-starter
```

Destruir cluster local:

```bash
make down
```

## 20. Decisao Tecnica

Use manifests puros quando o objetivo e aprender os objetos base.

Use Helm quando o objetivo e empacotar a aplicacao com parametros por ambiente.

Use Argo CD quando o objetivo e manter o cluster reconciliado a partir do Git.

Use kube-prometheus-stack quando o objetivo e ter observabilidade pronta com Prometheus Operator, Prometheus, Alertmanager, Grafana, exporters, rules e dashboards.
