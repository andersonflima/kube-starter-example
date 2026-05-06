# Criando Os Arquivos Do Zero

Este guia mostra onde criar cada arquivo, qual conteudo entra nele e por que esse padrao foi escolhido.

Para instalar ferramentas e executar os comandos em Windows, macOS e Linux, veja [03-cross-platform-setup.md](03-cross-platform-setup.md).

## 1. Estrutura Inicial

Crie os diretorios:

```bash
mkdir -p backend/src
mkdir -p frontend/src frontend/nginx
mkdir -p helm/kube-starter/templates
mkdir -p manifests/kube-starter/base manifests/kube-starter/observability
mkdir -p clusters/local
mkdir -p platform/ingress-nginx platform/metrics-server platform/monitoring
mkdir -p argocd/projects argocd/applications
mkdir -p scripts
```

Motivo da separacao:

- `backend` e `frontend`: codigo da aplicacao.
- `helm`: pacote parametrizado da aplicacao.
- `manifests`: YAML puro para estudo e debug.
- `clusters`: configuracao do cluster local.
- `platform`: values de componentes operacionais externos.
- `argocd`: declaracoes GitOps.
- `scripts`: automacoes repetitivas.

## 2. Backend

Arquivos principais:

```text
backend/package.json
backend/tsconfig.json
backend/src/app.ts
backend/src/server.ts
backend/Dockerfile
backend/.dockerignore
```

Padrao usado:

- `app.ts` cria a aplicacao Express sem abrir porta.
- `server.ts` injeta dependencias e chama `listen`.
- Esse corte deixa a app mais testavel, porque o servidor HTTP nao nasce no import.

Dependencias:

```bash
cd backend
npm init -y
npm install express cors prom-client
npm install -D typescript tsx @types/node @types/express @types/cors
```

Scripts:

```json
{
  "scripts": {
    "dev": "tsx watch src/server.ts",
    "build": "tsc -p tsconfig.json",
    "start": "node dist/server.js"
  }
}
```

Por que `prom-client`:

- expoe metricas padrao de Node.js
- permite contador HTTP customizado
- entrega `/metrics` em formato que o Prometheus entende

## 3. Frontend

Arquivos principais:

```text
frontend/package.json
frontend/vite.config.ts
frontend/src/App.tsx
frontend/src/main.tsx
frontend/src/styles.css
frontend/nginx/default.conf.template
frontend/Dockerfile
frontend/.dockerignore
```

Criacao:

```bash
npm create vite@latest frontend -- --template react-ts
cd frontend
npm install
```

Padrao usado:

- Vite compila a UI para arquivos estaticos.
- nginx entrega esses arquivos em runtime.
- nginx faz proxy de `/api` para o backend.

Motivo: o navegador nao precisa saber o nome interno do Service do backend. Ele chama `/api`, e o nginx resolve o destino.

## 4. Dockerfiles

### 4.1 Backend

Arquivo:

```text
backend/Dockerfile
```

Padrao:

- multi-stage
- `npm ci`
- build TypeScript separado do runtime
- runtime com `NODE_ENV=production`
- usuario nao-root

Motivo:

- melhora reprodutibilidade
- reduz tamanho e superficie da imagem final
- evita executar a app como root

### 4.2 Frontend

Arquivo:

```text
frontend/Dockerfile
```

Padrao:

- build com Node.js
- runtime com nginx
- `default.conf.template` para receber `BACKEND_SERVICE_URL`

Motivo:

- Vite precisa do toolchain Node.js somente no build.
- nginx e mais adequado para servir conteudo estatico em runtime.
- configuracao por env evita rebuild da imagem para trocar URL do backend.

## 5. Docker Compose

Arquivo:

```text
docker-compose.yml
```

Responsabilidade:

- construir backend e frontend localmente
- criar rede entre os servicos
- publicar portas no host
- passar `BACKEND_SERVICE_URL=http://backend:3000` para o frontend

Padrao:

```yaml
services:
  backend:
    build:
      context: ./backend
    ports:
      - "${BACKEND_PORT:-3000}:3000"

  frontend:
    build:
      context: ./frontend
    depends_on:
      - backend
    environment:
      BACKEND_SERVICE_URL: http://backend:3000
    ports:
      - "${FRONTEND_PORT:-8080}:80"
```

Motivo:

- `build.context` deixa claro de onde vem cada imagem.
- variaveis de porta permitem rodar sem editar o arquivo.
- `backend` vira DNS interno do Compose.

## 6. Cluster kind

Arquivo:

```text
clusters/local/kind-config.yaml
```

Responsabilidade:

- criar cluster local
- mapear portas do ingress para o host

Padrao:

```yaml
extraPortMappings:
  - containerPort: 80
    hostPort: 8080
```

Motivo: kind roda o cluster dentro de containers Docker. O mapeamento liga a porta do node kind ao localhost da maquina.

## 7. Manifests Kubernetes Puros

Diretorio:

```text
manifests/kube-starter/base
```

Ordem dos arquivos:

```text
00-namespace.yaml
10-backend-deployment.yaml
11-backend-service.yaml
20-frontend-deployment.yaml
21-frontend-service.yaml
30-backend-hpa.yaml
31-frontend-hpa.yaml
40-ingress.yaml
```

Motivo dos prefixos:

- humanos leem na ordem correta
- fica claro o encadeamento dos recursos
- `Namespace` aparece antes dos objetos namespaced

### 7.1 Namespace

Crie:

```text
manifests/kube-starter/base/00-namespace.yaml
```

Motivo: isola a aplicacao e facilita comandos como:

```bash
kubectl get pods -n kube-starter
```

### 7.2 Deployment

Crie um Deployment para cada componente.

Motivo:

- `Deployment` controla ReplicaSets e Pods.
- permite rollout e rollback.
- recria Pods se falharem.

Campos importantes:

- `metadata.labels`: identificacao operacional.
- `spec.selector.matchLabels`: como o Deployment encontra seus Pods.
- `template.metadata.labels`: labels aplicadas aos Pods.
- `containers[].image`: imagem executada.
- `resources`: requests/limits.
- `readinessProbe`: decide se o Pod recebe trafego.
- `livenessProbe`: decide se o container precisa reiniciar.

Regra critica: `selector.matchLabels` deve bater com `template.metadata.labels`.

### 7.3 Service

Crie um Service para cada Deployment.

Motivo:

- Pods tem IP efemero.
- Service cria endereco estavel.
- Service seleciona Pods por label.

Campos importantes:

- `spec.selector`: precisa bater com labels dos Pods.
- `ports[].port`: porta do Service.
- `ports[].targetPort`: porta do container.

### 7.4 HPA

Crie HPA quando quiser escala horizontal.

Requisitos:

- Metrics Server instalado.
- `resources.requests` nos containers.

Motivo: o HPA calcula uso percentual a partir do request.

### 7.5 Ingress

Crie Ingress quando quiser entrada HTTP externa.

Requisitos:

- controller de Ingress instalado, aqui `ingress-nginx`.
- host configurado, aqui `kube-starter.localhost`.

Motivo: Service `ClusterIP` e interno ao cluster. Ingress publica HTTP para fora.

## 8. Helm Chart

Diretorio:

```text
helm/kube-starter
```

Arquivos:

```text
Chart.yaml
values.yaml
values-observability.yaml
templates/_helpers.tpl
templates/backend-deployment.yaml
templates/backend-service.yaml
templates/backend-hpa.yaml
templates/backend-servicemonitor.yaml
templates/frontend-deployment.yaml
templates/frontend-service.yaml
templates/frontend-hpa.yaml
templates/ingress.yaml
```

### 8.1 Chart.yaml

Responsabilidade:

- nome do chart
- versao do chart
- versao da app
- descricao

Motivo: Helm precisa metadados para empacotar, instalar e versionar o release.

### 8.2 values.yaml

Responsabilidade:

- tudo que muda por ambiente

Exemplos:

- imagem
- tag
- replicas
- resources
- HPA
- service
- ingress

Motivo: template deve descrever estrutura; values devem descrever variacao.

### 8.3 _helpers.tpl

Responsabilidade:

- padronizar nomes
- padronizar labels
- evitar repeticao

Motivo: se cada template montar nome e label manualmente, aumenta o risco de Service nao encontrar Pods ou recursos ficarem inconsistentes.

### 8.4 Templates

Responsabilidade:

- transformar values em manifests Kubernetes

Exemplo:

```yaml
image: "{{ .Values.backend.image.repository }}:{{ .Values.backend.image.tag }}"
```

Motivo: a imagem muda por ambiente, entao o template le de `values.yaml`.

## 9. Plataforma

Diretorio:

```text
platform
```

Arquivos:

```text
platform/ingress-nginx/values.yaml
platform/metrics-server/values.yaml
platform/monitoring/values.yaml
```

Padrao:

- chart externo fica fora do repositorio
- values ficam versionados aqui

Motivo: voce nao precisa copiar chart de terceiros para dentro do repo. Versione apenas a configuracao que pertence ao ambiente.

## 10. Argo CD

Diretorio:

```text
argocd
```

Arquivos:

```text
argocd/projects/kube-starter-project.yaml
argocd/root-application.yaml
argocd/applications/ingress-nginx-application.yaml
argocd/applications/metrics-server-application.yaml
argocd/applications/kube-prometheus-stack-application.yaml
argocd/applications/kube-starter-application.yaml
```

### 10.1 AppProject

Responsabilidade:

- restringir repositorios permitidos
- restringir destinos permitidos
- definir escopo operacional

Motivo: evita que uma Application aplique qualquer coisa em qualquer namespace sem intencao explicita.

### 10.2 Root Application

Responsabilidade:

- observar `argocd/applications`
- aplicar as Applications filhas

Motivo: app-of-apps reduz bootstrap manual. Voce aplica uma app raiz e ela reconcilia o restante.

### 10.3 Applications Filhas

Responsabilidade:

- declarar cada componente da plataforma

Cada Application responde:

- de onde ler (`repoURL`, `chart`, `path`)
- qual versao ler (`targetRevision`)
- onde aplicar (`destination`)
- como sincronizar (`syncPolicy`)

## 11. Scripts

Diretorio:

```text
scripts
```

Responsabilidade:

- reduzir comandos repetitivos
- padronizar o caminho feliz
- manter o tutorial facil de executar

Scripts:

- `check-tools.sh`: valida ferramentas.
- `build-images.sh`: builda imagens.
- `create-kind-cluster.sh`: cria cluster local.
- `load-kind-images.sh`: carrega imagens no kind.
- `install-argocd.sh`: instala Argo CD.
- `bootstrap-platform.sh`: aplica AppProject e root Application.
- `smoke-test.sh`: valida endpoints principais.
- `destroy-kind-cluster.sh`: remove cluster local.

## 12. Ordem Recomendada De Criacao

1. Crie backend e valide com `npm run build`.
2. Crie frontend e valide com `npm run build`.
3. Crie Dockerfiles e valide com `docker build`.
4. Crie Compose e valide com `docker compose up --build`.
5. Crie cluster kind.
6. Carregue imagens no kind.
7. Crie manifests puros e aplique com `kubectl apply`.
8. Transforme manifests em Helm chart.
9. Instale dependencias operacionais com Helm.
10. Crie estrutura Argo CD.
11. Suba app-of-apps.
12. Ative observabilidade.

## 13. Por Que Nao Comecar Direto Com Argo CD

Porque Argo CD adiciona reconciliacao, mas nao substitui entendimento basico.

Se algo falha, voce precisa saber diagnosticar:

- imagem existe?
- Pod subiu?
- Service seleciona o Pod?
- Ingress aponta para o Service?
- HPA tem metricas?
- Prometheus tem CRDs?
- Application esta sincronizada?

Por isso o tutorial passa por Docker, Compose, manifests, Helm e depois GitOps.
