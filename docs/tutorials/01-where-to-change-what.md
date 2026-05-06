# Onde Alterar Cada Coisa

Este guia e o mapa operacional do repositorio. Use quando precisar mudar imagem, tag, porta, host, namespace, replicas, HPA, observabilidade ou fonte GitOps.

Para comandos especificos de Windows, macOS e Linux, veja [03-cross-platform-setup.md](03-cross-platform-setup.md).

## 1. Modelo Mental

Antes de editar arquivos, separe os conceitos:

- `Dockerfile`: receita para construir uma imagem.
- `Imagem`: pacote versionado da aplicacao, por exemplo `kube-backend:latest`.
- `Container`: processo rodando a partir de uma imagem.
- `Pod`: unidade de execucao no Kubernetes, normalmente com um container principal.
- `Deployment`: objeto que mantem Pods rodando e controla rollout.
- `Service`: endereco estavel para acessar Pods.
- `Ingress`: regra HTTP externa para chegar em um Service.
- `Helm chart`: pacote parametrizado que gera manifests.
- `values.yaml`: arquivo de configuracao do chart.
- `Argo CD Application`: declaracao GitOps que diz de onde ler manifests/charts e onde aplicar no cluster.

A regra pratica:

```text
Imagem muda no values/manifests.
Build muda no Dockerfile.
Rede local muda no Compose.
Entrada HTTP muda no Ingress.
Reconciliacao muda no Argo CD.
```

## 2. Mapa Rapido De Alteracoes

| Quero alterar | Arquivo principal | Campo |
| --- | --- | --- |
| imagem do backend no Helm | `helm/kube-starter/values.yaml` | `backend.image.repository`, `backend.image.tag` |
| imagem do frontend no Helm | `helm/kube-starter/values.yaml` | `frontend.image.repository`, `frontend.image.tag` |
| imagem nos manifests puros | `manifests/kube-starter/base/*-deployment.yaml` | `spec.template.spec.containers[].image` |
| tag local usada pelos scripts | ambiente do shell | `IMAGE_TAG`, `BACKEND_IMAGE`, `FRONTEND_IMAGE` |
| porta local do Compose | ambiente do shell | `BACKEND_PORT`, `FRONTEND_PORT` |
| URL do backend usada pelo nginx no Compose | `docker-compose.yml` | `frontend.environment.BACKEND_SERVICE_URL` |
| porta do backend no Kubernetes | `helm/kube-starter/values.yaml` | `backend.service.port` |
| porta do frontend no Kubernetes | `helm/kube-starter/values.yaml` | `frontend.service.port` |
| replicas sem HPA | `helm/kube-starter/values.yaml` | `*.replicaCount` e `*.autoscaling.enabled=false` |
| HPA | `helm/kube-starter/values.yaml` | `*.autoscaling.*` |
| CPU/memoria | `helm/kube-starter/values.yaml` | `*.resources.requests`, `*.resources.limits` |
| host HTTP da app | `argocd/applications/kube-starter-application.yaml` ou `helm --set` | `ingress.hosts[0].host` |
| ServiceMonitor | `helm/kube-starter/values-observability.yaml` | `monitoring.serviceMonitor.enabled` |
| Grafana/Prometheus/Alertmanager | `platform/monitoring/values.yaml` | `grafana`, `prometheus`, `alertmanager` |
| ingress-nginx | `platform/ingress-nginx/values.yaml` | `controller.*` |
| Metrics Server | `platform/metrics-server/values.yaml` | `args`, `resources` |
| repo Git usado pelo Argo CD | `argocd/*.yaml` | `repoURL` |
| branch/tag Git usada pelo Argo CD | `argocd/*.yaml` | `targetRevision` |
| versao de chart externo no Argo CD | `argocd/applications/*.yaml` | `targetRevision` do chart |
| portas locais do cluster kind | `clusters/local/kind-config.yaml` | `extraPortMappings` |

## 3. Alterar Imagem Da Aplicacao

### 3.1 Ambiente local com Docker

Build com tag padrao:

```bash
docker build -t kube-backend:latest ./backend
docker build -t kube-frontend:latest ./frontend
```

Build com tag versionada:

```bash
docker build -t kube-backend:1.1.0 ./backend
docker build -t kube-frontend:1.1.0 ./frontend
```

Rodar a tag versionada:

```bash
docker run --rm -p 3000:3000 kube-backend:1.1.0
```

Motivo: a tag identifica exatamente qual versao da imagem voce quer executar. `latest` e conveniente para laboratorio, mas em ambientes reais prefira tags imutaveis como `1.1.0`, `2026-05-06-001` ou o SHA do commit.

### 3.2 Scripts locais

Os scripts aceitam variaveis:

```bash
IMAGE_TAG=1.1.0 make build-images
IMAGE_TAG=1.1.0 make images-load
```

Tambem da para trocar o nome da imagem:

```bash
BACKEND_IMAGE=ghcr.io/seu-usuario/kube-backend \
FRONTEND_IMAGE=ghcr.io/seu-usuario/kube-frontend \
IMAGE_TAG=1.1.0 \
make build-images
```

Essas variaveis afetam os scripts em:

```text
scripts/build-images.sh
scripts/load-kind-images.sh
```

### 3.3 Manifests puros

Edite:

```text
manifests/kube-starter/base/10-backend-deployment.yaml
manifests/kube-starter/base/20-frontend-deployment.yaml
```

Troque:

```yaml
image: kube-backend:latest
```

por:

```yaml
image: ghcr.io/seu-usuario/kube-backend:1.1.0
```

Depois aplique:

```bash
kubectl apply -f manifests/kube-starter/base
kubectl rollout status deployment/kube-starter-backend -n kube-starter --timeout=300s
```

Use manifests puros quando estiver aprendendo ou depurando Kubernetes. Para operacao normal, prefira Helm ou Argo CD.

### 3.4 Helm local

Edite:

```text
helm/kube-starter/values.yaml
```

Campos:

```yaml
backend:
  image:
    repository: kube-backend
    tag: latest

frontend:
  image:
    repository: kube-frontend
    tag: latest
```

Exemplo com registry:

```yaml
backend:
  image:
    repository: ghcr.io/seu-usuario/kube-backend
    tag: "1.1.0"

frontend:
  image:
    repository: ghcr.io/seu-usuario/kube-frontend
    tag: "1.1.0"
```

Aplicar:

```bash
helm upgrade --install kube-starter ./helm/kube-starter \
  --namespace kube-starter \
  --create-namespace
```

Sem editar arquivo, use override:

```bash
helm upgrade --install kube-starter ./helm/kube-starter \
  --namespace kube-starter \
  --create-namespace \
  --set backend.image.repository=ghcr.io/seu-usuario/kube-backend \
  --set backend.image.tag=1.1.0 \
  --set frontend.image.repository=ghcr.io/seu-usuario/kube-frontend \
  --set frontend.image.tag=1.1.0
```

Motivo: o template do Deployment nao deve hardcodar imagem. O valor muda por ambiente, entao fica em `values.yaml`.

### 3.5 Argo CD

No fluxo GitOps, altere a imagem no Git, normalmente em:

```text
helm/kube-starter/values.yaml
```

Depois faca commit e push. O Argo CD vai renderizar o chart novamente e aplicar o novo estado.

Se quiser manter valores especificos do ambiente GitOps sem mexer no default, crie um arquivo, por exemplo:

```text
helm/kube-starter/values-gitops.yaml
```

Conteudo:

```yaml
backend:
  image:
    repository: ghcr.io/seu-usuario/kube-backend
    tag: "1.1.0"

frontend:
  image:
    repository: ghcr.io/seu-usuario/kube-frontend
    tag: "1.1.0"
```

Depois inclua em:

```text
argocd/applications/kube-starter-application.yaml
```

Campo:

```yaml
helm:
  releaseName: kube-starter
  valueFiles:
    - values.yaml
    - values-observability.yaml
    - values-gitops.yaml
```

Motivo: GitOps deve operar a partir de arquivos versionados. Evite alterar recurso manualmente com `kubectl edit`, porque o Argo CD vai detectar drift e voltar para o estado do Git.

## 4. Alterar Portas

### 4.1 Porta local no Docker Compose

Sem editar arquivo:

```bash
BACKEND_PORT=3002 FRONTEND_PORT=9081 docker compose up --build -d
```

O Compose usa:

```yaml
ports:
  - "${BACKEND_PORT:-3000}:3000"
```

Leitura:

- lado esquerdo: porta no host
- lado direito: porta dentro do container

Exemplo:

```text
3002:3000
```

Significa: acessar `localhost:3002` no host encaminha para `3000` dentro do container.

### 4.2 Porta do backend

Backend local:

```text
backend/src/server.ts
```

O servidor le:

```ts
process.env.PORT ?? 3000
```

Docker Compose:

```text
docker-compose.yml
```

Kubernetes com Helm:

```text
helm/kube-starter/values.yaml
```

Campo:

```yaml
backend:
  service:
    port: 3000
```

Motivo: a porta do container, do Service e da env `PORT` precisam apontar para o mesmo contrato. Se uma delas divergir, o Service pode mandar trafego para uma porta onde o processo nao escuta.

### 4.3 Porta externa do Ingress local

Edite:

```text
clusters/local/kind-config.yaml
```

Campo:

```yaml
extraPortMappings:
  - containerPort: 80
    hostPort: 8080
```

Leitura: o ingress-nginx escuta na porta `80` dentro do node kind, e o host acessa por `localhost:8080`.

Se mudar `hostPort` para `8088`, a app passa a responder em:

```text
http://kube-starter.localhost:8088
```

## 5. Alterar Host Do Ingress

### 5.1 Helm local

Com comando:

```bash
helm upgrade --install kube-starter ./helm/kube-starter \
  --namespace kube-starter \
  --create-namespace \
  --set ingress.enabled=true \
  --set ingress.className=nginx \
  --set ingress.hosts[0].host=app.localhost
```

### 5.2 GitOps

Edite:

```text
argocd/applications/kube-starter-application.yaml
```

Campo:

```yaml
ingress:
  enabled: true
  className: nginx
  hosts:
    - host: kube-starter.localhost
```

Motivo: em GitOps, o host faz parte do estado desejado do ambiente. Por isso ele deve estar no Git.

## 6. Alterar Replicas E HPA

### 6.1 Replicas fixas

Edite:

```text
helm/kube-starter/values.yaml
```

Desabilite HPA:

```yaml
backend:
  replicaCount: 2
  autoscaling:
    enabled: false
```

Motivo: quando HPA esta ativo, ele controla o numero de replicas. Manter `replicas` fixo ao mesmo tempo cria ambiguidade operacional.

### 6.2 HPA

Edite:

```yaml
backend:
  autoscaling:
    enabled: true
    minReplicas: 1
    maxReplicas: 4
    targetCPUUtilizationPercentage: 70
    targetMemoryUtilizationPercentage: 80
```

Requisitos:

- Metrics Server instalado.
- `resources.requests` definido no container.

Sem `requests`, o HPA nao tem base para calcular percentual de uso.

## 7. Alterar CPU E Memoria

Edite:

```text
helm/kube-starter/values.yaml
```

Campos:

```yaml
backend:
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      cpu: 500m
      memory: 256Mi
```

Leitura:

- `requests`: reserva usada pelo scheduler e base do HPA.
- `limits`: teto de consumo do container.

Motivo: sem `requests`, o scheduler tem menos informacao para alocar Pods e o HPA de CPU/memoria perde previsibilidade.

## 8. Alterar Observabilidade

### 8.1 Habilitar ServiceMonitor

Arquivo:

```text
helm/kube-starter/values-observability.yaml
```

Campo:

```yaml
monitoring:
  serviceMonitor:
    enabled: true
```

Motivo: `ServiceMonitor` e um CRD do Prometheus Operator. Ele deve ser habilitado apenas quando o cluster ja tem o operador instalado.

### 8.2 Alterar Grafana

Arquivo:

```text
platform/monitoring/values.yaml
```

Campos comuns:

```yaml
grafana:
  adminUser: admin
  adminPassword: admin
  ingress:
    hosts:
      - grafana.localhost
```

Para producao, nao deixe senha em texto puro. Use secret externo ou sealed/encrypted secrets.

### 8.3 Alterar Prometheus

Arquivo:

```text
platform/monitoring/values.yaml
```

Campos comuns:

```yaml
prometheus:
  prometheusSpec:
    retention: 12h
    scrapeInterval: 30s
```

Motivo: laboratorio local usa retencao curta para economizar disco e memoria. Em ambiente real, ajuste conforme volume de metricas e necessidade historica.

## 9. Alterar Repo, Branch Ou Fork No Argo CD

Arquivos:

```text
argocd/root-application.yaml
argocd/applications/*.yaml
```

Campos:

```yaml
repoURL: https://github.com/andersonflima/kube-starter-example.git
targetRevision: main
```

Se estiver em uma branch:

```yaml
targetRevision: feature/kubernetes-platform-tutorial
```

Se estiver em um fork:

```yaml
repoURL: https://github.com/seu-usuario/kube-starter-example.git
```

Motivo: o Argo CD roda dentro do cluster e le o repositorio remoto. Mudanca local que ainda nao foi publicada nao existe para ele.

## 10. Alterar Versoes De Charts Externos

Arquivos:

```text
argocd/applications/ingress-nginx-application.yaml
argocd/applications/metrics-server-application.yaml
argocd/applications/kube-prometheus-stack-application.yaml
```

Campo:

```yaml
targetRevision: 4.15.1
```

Esse `targetRevision` e a versao do chart Helm externo, nao a branch do seu repositorio.

Quando alterar:

1. leia release notes do chart
2. renderize localmente com `helm template`
3. aplique em ambiente descartavel
4. so depois promova para ambiente compartilhado

## 11. Alterar Namespaces

Namespaces atuais:

```text
argocd
ingress-nginx
kube-system
monitoring
kube-starter
```

Onde alterar:

- App namespace: `helm install --namespace`, `argocd/applications/kube-starter-application.yaml`, manifests puros.
- Monitoring namespace: `argocd/applications/kube-prometheus-stack-application.yaml`.
- Ingress namespace: `argocd/applications/ingress-nginx-application.yaml`.

Motivo: namespace define fronteira operacional. Logs, RBAC, recursos e troubleshooting ficam mais claros quando cada camada tem seu namespace.

## 12. Quando Usar Cada Caminho

Use Docker quando quiser validar o processo isolado.

Use Compose quando quiser backend e frontend juntos sem cluster.

Use manifests puros quando quiser aprender Kubernetes ou reproduzir um problema sem Helm.

Use Helm quando quiser parametrizar e instalar a aplicacao.

Use Argo CD quando quiser que o Git seja a fonte de verdade.

## 13. Checklist Antes De Subir Mudanca

```bash
npm run build --prefix backend
npm run build --prefix frontend
docker build -t kube-backend:local-test ./backend
docker build -t kube-frontend:local-test ./frontend
helm lint ./helm/kube-starter
helm template kube-starter ./helm/kube-starter
docker compose config
```

Se alterou YAML:

```bash
ruby -ryaml -e 'ARGV.each { |file| YAML.load_stream(File.read(file)); puts "ok: #{file}" }' \
  $(find argocd clusters manifests platform helm/kube-starter -path "helm/kube-starter/templates" -prune -o -name "*.yaml" -print)
```

Se alterou imagem para kind:

```bash
make build-images
make images-load
kubectl rollout restart deployment/kube-starter-backend -n kube-starter
kubectl rollout restart deployment/kube-starter-frontend -n kube-starter
```
