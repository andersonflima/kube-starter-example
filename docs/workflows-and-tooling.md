# Workflows E Ferramentas

Este documento ajuda a decidir quando usar Docker, Docker Compose, manifests, Helm e Argo CD.

## 1. Docker

Use Docker para empacotar e executar um servico isolado.

Resolve:

- runtime previsivel
- build reproduzivel
- distribuicao por imagem

Nao resolve:

- orquestracao de varios servicos
- rollout declarativo
- auto-healing
- GitOps

Comandos:

```bash
docker build -t kube-backend:latest ./backend
docker build -t kube-frontend:latest ./frontend
docker network create kube-starter
docker run -d --name backend --network kube-starter -p 3000:3000 kube-backend:latest
docker run -d --name frontend --network kube-starter \
  -e BACKEND_SERVICE_URL=http://backend:3000 \
  -p 8080:80 kube-frontend:latest
```

## 2. Docker Compose

Use Docker Compose para desenvolvimento local integrado em uma maquina.

Resolve:

- subida de multiplos containers
- rede local compartilhada
- configuracao local centralizada

Nao resolve:

- cluster
- scheduling
- HPA
- Ingress
- GitOps

Comandos:

```bash
docker compose up --build
docker compose up --build -d
docker compose down
```

## 3. Manifests Kubernetes

Use manifests puros para aprender e depurar os objetos base.

Resolve:

- visibilidade total dos objetos Kubernetes
- aplicacao direta com `kubectl`
- excelente material didatico

Nao resolve:

- parametrizacao elegante por ambiente
- composicao de templates
- gerenciamento de release

Comandos:

```bash
kubectl apply -f manifests/kube-starter/base
kubectl get pods,svc,hpa,ingress -n kube-starter
```

O `ServiceMonitor` fica separado porque depende das CRDs do Prometheus Operator:

```bash
kubectl apply -f manifests/kube-starter/observability
```

## 4. Helm

Use Helm para empacotar a aplicacao e trocar valores por ambiente.

Resolve:

- templates
- `values.yaml`
- instalacao e upgrade com historico
- reuso do pacote

Nao resolve sozinho:

- reconciliacao continua
- deteccao de drift
- politica GitOps

Comandos:

```bash
helm lint ./helm/kube-starter
helm template kube-starter ./helm/kube-starter
helm upgrade --install kube-starter ./helm/kube-starter \
  --namespace kube-starter \
  --create-namespace
```

Com observabilidade:

```bash
helm upgrade --install kube-starter ./helm/kube-starter \
  --namespace kube-starter \
  --create-namespace \
  --values helm/kube-starter/values.yaml \
  --values helm/kube-starter/values-observability.yaml
```

## 5. Argo CD

Use Argo CD quando Git deve ser a fonte de verdade do cluster.

Resolve:

- sync continuo
- self-heal
- prune
- visualizacao de health/sync
- reducao de deploy manual

Nao resolve:

- build de imagem
- publicacao em registry
- testes automatizados

Comandos:

```bash
make argocd-install
make platform-bootstrap
kubectl get applications.argoproj.io -n argocd
```

## 6. Plataforma Operacional

Este projeto usa Argo CD para reconciliar:

- `ingress-nginx`
- `metrics-server`
- `kube-prometheus-stack`
- `kube-starter`

Os values da plataforma ficam em:

```text
platform/ingress-nginx/values.yaml
platform/metrics-server/values.yaml
platform/monitoring/values.yaml
```

## 7. Regra Pratica

- Docker: imagem e container individual
- Compose: stack local sem Kubernetes
- manifests: aprendizado e debug explicito
- Helm: pacote da aplicacao
- Argo CD: reconciliacao continua a partir do Git
- kube-prometheus-stack: observabilidade do cluster

## 8. Fluxo Recomendado

Para estudar:

```text
Docker -> Compose -> manifests -> Helm -> Argo CD
```

Para operar:

```text
CI builda imagem -> Git recebe tag nova -> Argo CD sincroniza o cluster
```
