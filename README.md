# Kube Starter

Exemplo simples com:

- backend em `Express + TypeScript`
- frontend em `React + Vite`
- `Dockerfile` para os dois projetos
- `docker-compose.yml` para subir localmente
- chart Helm para Kubernetes

## Endpoints

- `GET /api/health`
- `GET /api/message`
- `GET /api/stats`

## Arquitetura da solucao

### Visao geral

O frontend serve a interface para o navegador e encaminha chamadas `/api` para o backend. O backend concentra a logica HTTP e responde os 3 endpoints da aplicacao.

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

### Responsabilidades

- frontend: entrega a UI e faz proxy das chamadas `/api`
- backend: responde `health`, `message` e `stats`
- docker: empacota cada servico como imagem
- docker compose: sobe os servicos juntos no ambiente local
- helm: instala e versiona os recursos no cluster Kubernetes

## Componentes principais do Kubernetes

Quando voce executa um `helm upgrade --install`, o Helm envia manifests para o cluster. A partir dai, cada componente do Kubernetes assume uma responsabilidade diferente.

### Fluxo simplificado

```text
[ Helm / kubectl ]
        |
        v
[ kube-apiserver ]
        |
        v
[ etcd ]
        |
        v
[ controller-manager ] ---> garante o estado desejado
        |
        v
[ scheduler ] ---> escolhe em qual node o Pod vai rodar
        |
        v
[ kubelet ] ---> cria e monitora o Pod no node
```

### Diferenca entre eles

- `kube-apiserver`: porta de entrada do cluster. Recebe requisicoes, valida manifests, aplica regras de autenticacao/autorizacao e expoe a API do Kubernetes.
- `etcd`: banco chave-valor do cluster. Guarda o estado desejado e o estado atual persistido, como `Deployments`, `Services`, `Secrets` e metadados.
- `controller-manager`: conjunto de controllers que compara estado desejado com estado atual e tenta corrigir divergencias. Exemplo: se um `Deployment` pede 2 replicas e existe 1, ele cria outra.
- `scheduler`: decide em qual node um Pod pendente deve ser alocado, levando em conta recursos, afinidade, taints, tolerations e restricoes.
- `kubelet`: agente que roda em cada node. Recebe a decisao do control plane, conversa com o runtime de containers e garante que os Pods daquele node estejam de pe.

### Como pensar na pratica

- `kube-apiserver` e `etcd` pertencem ao centro de controle do cluster.
- `controller-manager` e `scheduler` transformam declaracao em execucao.
- `kubelet` e quem materializa isso no node.

### Exemplo com este projeto

Quando voce instala este chart:

- o `Helm` envia `Deployment` e `Service` para o `kube-apiserver`
- o `kube-apiserver` valida e persiste isso no `etcd`
- o `controller-manager` percebe que frontend e backend precisam existir
- o `scheduler` escolhe os nodes onde cada Pod sera executado
- o `kubelet` de cada node baixa a imagem e sobe os containers

## Diferenca entre Pod, Deployment, Service e Ingress

Esses sao os objetos mais importantes para entender o chart deste projeto.

### Visao curta

- `Pod`: menor unidade executavel do Kubernetes
- `Deployment`: controlador que garante Pods rodando na quantidade desejada
- `Service`: endpoint estavel para acessar Pods
- `Ingress`: camada HTTP/HTTPS de entrada para trafego externo

### Como eles se relacionam

```text
[ Usuario / Navegador ]
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

### Diferenca entre eles

- `Pod`: e onde o container realmente roda. Se um Pod morrer, ele pode ser recriado com outro nome e outro IP.
- `Deployment`: nao expoe trafego diretamente. Ele declara quantas replicas devem existir e gerencia rollout, restart e atualizacao de Pods.
- `Service`: resolve o problema de IP dinamico dos Pods. Ele oferece um nome fixo e balanceia trafego entre os Pods selecionados por label.
- `Ingress`: define regras de entrada HTTP/HTTPS, como host e path, e normalmente fica na frente de um `Service`, nao de Pods diretamente.

### Como pensar na pratica

- se voce quer rodar container, pensa em `Pod`
- se voce quer manter Pods vivos e versionar rollout, pensa em `Deployment`
- se voce quer comunicacao interna estavel, pensa em `Service`
- se voce quer acesso externo web, pensa em `Ingress`

### Exemplo com este projeto

- o chart cria um `Deployment` para o `frontend`
- o chart cria um `Deployment` para o `backend`
- cada `Deployment` cria e gerencia seus `Pods`
- o chart cria um `Service` para o frontend e outro para o backend
- o `Ingress`, quando habilitado, aponta para o `Service` do frontend
- o frontend acessa o backend pelo nome do `Service` interno

## Diferencas entre Docker, Docker Compose e Helm

### Docker

Use `Docker` quando quiser construir e rodar cada servico manualmente, com controle fino sobre imagem, container, rede e portas.

- escopo: container individual
- foco: build e execucao manual
- melhor uso: testes isolados de backend ou frontend

### Docker Compose

Use `Docker Compose` quando quiser subir backend e frontend juntos no ambiente local, com rede interna entre os servicos e configuracao centralizada em um unico arquivo.

- escopo: varios containers relacionados
- foco: ambiente local integrado
- melhor uso: desenvolvimento e validacao local da stack inteira

### Helm

Use `Helm` quando quiser instalar a aplicacao em um cluster Kubernetes com objetos versionados, parametrizacao por `values.yaml` e suporte a upgrade/rollback.

- escopo: aplicacao no Kubernetes
- foco: empacotamento e deploy em cluster
- melhor uso: homologacao, staging e producao

## Comandos

### 1. Rodando com Docker

Build das imagens:

```bash
docker build -t kube-backend ./backend
docker build -t kube-frontend ./frontend
```

Criando uma rede local para os containers:

```bash
docker network create kube-starter
```

Subindo o backend:

```bash
docker run -d --name backend --network kube-starter -p 3000:3000 kube-backend
```

Subindo o frontend apontando para o backend:

```bash
docker run -d --name frontend --network kube-starter \
  -e BACKEND_SERVICE_URL=http://backend:3000 \
  -p 8080:80 kube-frontend
```

Parando e removendo os containers:

```bash
docker stop frontend backend
docker rm frontend backend
docker network rm kube-starter
```

### 2. Rodando com Docker Compose

```bash
docker compose up --build
```

Frontend: `http://localhost:8080`  
Backend: `http://localhost:3000`

Para rodar em background:

```bash
docker compose up --build -d
```

Para parar tudo:

```bash
docker compose down
```

Observacao: se a porta `3000` ou `8080` ja estiver ocupada na sua maquina, ajuste o mapeamento no [docker-compose.yml](/Users/andersonespindola/snippets/kube/docker-compose.yml).

### 3. Rodando com Helm

Renderizando os manifests localmente:

```bash
helm template kube-starter ./helm/kube-starter
```

Validando o chart:

```bash
helm lint ./helm/kube-starter
```

Instalando ou atualizando no cluster:

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

Desinstalando do cluster:

```bash
helm uninstall kube-starter
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
