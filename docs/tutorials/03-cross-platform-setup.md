# Setup Cross-Platform

Este projeto deve rodar em Windows, macOS e Linux. A diferenca principal esta no shell e na forma de instalar ferramentas.

## 1. Matriz De Suporte

| Sistema | Shell recomendado | Automacao recomendada |
| --- | --- | --- |
| Windows 10/11 | PowerShell 5.1+ ou PowerShell 7 | scripts `.ps1` |
| Windows com WSL2 | shell Linux dentro do WSL2 | `make` ou scripts `.sh` |
| macOS | zsh/bash | `make` ou scripts `.sh` |
| Linux | bash/zsh | `make` ou scripts `.sh` |

No Windows puro, nao assuma que `make`, `bash`, `sed` ou `grep` existem. Use PowerShell.

No Windows com WSL2, execute o projeto dentro do filesystem Linux, por exemplo `~/projects/kube-starter-example`, nao em `/mnt/c/...`, para evitar lentidao de I/O.

## 2. Versao Do Node.js

O projeto declara a versao base em:

```text
.nvmrc
.node-version
```

Use essa versao para alinhar ambiente local e Dockerfile.

Verificacao:

```bash
node --version
npm --version
```

No PowerShell:

```powershell
node --version
npm --version
```

## 3. Docker Desktop Resources

Para subir Argo CD, ingress-nginx, Metrics Server, Prometheus, Alertmanager, Grafana, backend e frontend no mesmo cluster local, configure o Docker Desktop com recursos suficientes.

Recomendado para Windows/macOS:

```text
CPU: 4 cores
Memory: 8 GB
Swap: 1 GB ou mais
Disk image: 40 GB ou mais
```

Minimo para laboratorio pequeno:

```text
CPU: 2 cores
Memory: 6 GB
Disk image: 20 GB
```

No Docker Desktop:

```text
Settings -> Resources
```

Motivo: `kube-prometheus-stack` instala varios componentes e CRDs. Com pouca memoria, os Pods podem ficar em `Pending`, `CrashLoopBackOff` ou a API local pode ficar instavel.

Em Linux com Docker Engine nativo, garanta que a maquina tenha recursos equivalentes.

## 4. Windows 10/11 Com PowerShell

### 4.1 Pre-requisitos Do Windows

Use Windows 10/11 com virtualizacao habilitada na BIOS/UEFI.

Para Docker Desktop, o caminho recomendado e WSL2 backend. Instale WSL2:

```powershell
wsl --install
wsl --status
```

Reinicie a maquina se o instalador solicitar.

### 4.2 Instalar Ferramentas Com winget

Abra PowerShell como usuario normal para instalar ferramentas de usuario. Docker Desktop pode solicitar permissao administrativa.

```powershell
winget install --id Docker.DockerDesktop -e
winget install --id OpenJS.NodeJS.LTS -e
winget install --id Kubernetes.kubectl -e
winget install --id Helm.Helm -e
winget install --id Kubernetes.kind -e
```

Depois abra o Docker Desktop e confirme que ele esta usando Linux containers.

Feche e abra o terminal novamente para recarregar o `PATH`.

### 4.3 Verificar Ferramentas

```powershell
docker version
docker compose version
node --version
npm --version
kind version
kubectl version --client
helm version
```

Ou rode:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\check-tools.ps1
```

### 4.4 Rodar Backend E Frontend Localmente

Backend:

```powershell
cd backend
npm ci
npm run build
npm run start
```

Em outro terminal:

```powershell
Invoke-WebRequest -UseBasicParsing http://localhost:3000/api/health
Invoke-WebRequest -UseBasicParsing http://localhost:3000/metrics
```

Frontend:

```powershell
cd frontend
npm ci
npm run build
npm run preview
```

### 4.5 Rodar Docker Manual

```powershell
docker build -t kube-backend:latest .\backend
docker build -t kube-frontend:latest .\frontend
docker network create kube-starter
docker run -d --name backend --network kube-starter -p 3000:3000 kube-backend:latest
docker run -d --name frontend --network kube-starter -e BACKEND_SERVICE_URL=http://backend:3000 -p 8080:80 kube-frontend:latest
```

Validacao:

```powershell
Invoke-WebRequest -UseBasicParsing http://localhost:3000/api/health
Invoke-WebRequest -UseBasicParsing http://localhost:8080/api/stats
```

Limpeza:

```powershell
docker stop frontend backend
docker rm frontend backend
docker network rm kube-starter
```

### 4.6 Rodar Docker Compose

```powershell
docker compose up --build
```

Em background:

```powershell
docker compose up --build -d
```

Portas alternativas:

```powershell
$env:BACKEND_PORT = "3002"
$env:FRONTEND_PORT = "9081"
docker compose up --build -d
```

Limpar variaveis da sessao:

```powershell
Remove-Item Env:\BACKEND_PORT
Remove-Item Env:\FRONTEND_PORT
```

Parar:

```powershell
docker compose down
```

### 4.7 Subir Cluster Completo No Windows

Atalho:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\up.ps1
```

Passo a passo equivalente:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\check-tools.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\build-images.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\create-kind-cluster.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\load-kind-images.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\install-argocd.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\bootstrap-platform.ps1
```

Status:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\status.ps1
```

Smoke test:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\smoke-test.ps1
```

Destruir cluster:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\destroy-kind-cluster.ps1
```

### 4.8 Variaveis No PowerShell

Exemplo para buildar outra tag:

```powershell
$env:IMAGE_TAG = "1.1.0"
powershell -ExecutionPolicy Bypass -File .\scripts\build-images.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\load-kind-images.ps1
```

Exemplo com registry:

```powershell
$env:BACKEND_IMAGE = "ghcr.io/seu-usuario/kube-backend"
$env:FRONTEND_IMAGE = "ghcr.io/seu-usuario/kube-frontend"
$env:IMAGE_TAG = "1.1.0"
powershell -ExecutionPolicy Bypass -File .\scripts\build-images.ps1
```

## 5. Windows Com WSL2

Use esse caminho se quiser que os comandos sejam iguais aos de Linux/macOS.

### 5.1 Instalar WSL2

No PowerShell:

```powershell
wsl --install -d Ubuntu
```

Abra o Ubuntu pelo menu iniciar.

### 5.2 Instalar Ferramentas Dentro Do WSL2

Dentro do Ubuntu:

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg make
```

Instale Node com o gerenciador da sua preferencia. Se usar `nvm`:

```bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
source ~/.bashrc
nvm install
nvm use
```

Docker Desktop deve estar instalado no Windows com integracao WSL habilitada.

Verifique dentro do WSL:

```bash
docker version
docker compose version
```

Instale `kubectl`, `helm` e `kind` conforme os comandos Linux da secao 7.

## 6. macOS

### 6.1 Instalar Ferramentas Com Homebrew

```bash
brew install --cask docker
brew install node kubectl helm kind
```

Abra o Docker Desktop pelo Finder ou terminal:

```bash
open -a Docker
```

Espere o Docker iniciar e valide:

```bash
docker version
docker compose version
node --version
npm --version
kind version
kubectl version --client
helm version
```

### 6.2 Rodar Local

```bash
npm ci --prefix backend
npm run build --prefix backend
npm ci --prefix frontend
npm run build --prefix frontend
docker compose up --build
```

### 6.3 Subir Cluster Completo

```bash
make up
make status
make smoke
```

Destruir:

```bash
make down
```

### 6.4 Portas Alternativas

```bash
BACKEND_PORT=3002 FRONTEND_PORT=9081 docker compose up --build -d
```

## 7. Linux

Os comandos abaixo usam Ubuntu/Debian como base. Em Fedora, Arch ou outras distros, use o gerenciador equivalente e mantenha as mesmas verificacoes finais.

### 7.1 Instalar Dependencias Base

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg make
```

### 7.2 Instalar Docker Engine

```bash
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

Permitir Docker sem `sudo`:

```bash
sudo usermod -aG docker "$USER"
newgrp docker
```

Valide:

```bash
docker version
docker compose version
```

### 7.3 Instalar Node.js

Use a versao declarada em `.nvmrc`. Com `nvm`:

```bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
source ~/.bashrc
nvm install
nvm use
node --version
npm --version
```

### 7.4 Instalar kubectl

```bash
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
kubectl version --client
```

Para ARM64, troque `linux/amd64` por `linux/arm64`.

### 7.5 Instalar Helm

```bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
helm version
```

### 7.6 Instalar kind

AMD64:

```bash
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.31.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind
```

ARM64:

```bash
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.31.0/kind-linux-arm64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind
```

Valide:

```bash
kind version
```

### 7.7 Rodar Local

```bash
npm ci --prefix backend
npm run build --prefix backend
npm ci --prefix frontend
npm run build --prefix frontend
docker compose up --build
```

### 7.8 Subir Cluster Completo

```bash
make up
make status
make smoke
```

Destruir:

```bash
make down
```

## 8. Configuracoes Compartilhadas

### 8.1 Quebras De Linha

O repositorio tem:

```text
.gitattributes
```

Ele fixa `LF` para scripts `.sh`, YAML, Dockerfile e codigo fonte, e `CRLF` para `.ps1`.

Motivo: Windows pode converter arquivos para CRLF. Scripts `.sh` com CRLF podem falhar em Linux/WSL com erro de interpretador. O `.gitattributes` reduz esse risco.

### 8.2 Arquivo .env

Copie o exemplo:

Windows PowerShell:

```powershell
Copy-Item .env.example .env
```

macOS/Linux:

```bash
cp .env.example .env
```

O Docker Compose le `.env` automaticamente.

Variaveis disponiveis:

```text
BACKEND_PORT=3000
FRONTEND_PORT=8080
BACKEND_IMAGE=kube-backend
FRONTEND_IMAGE=kube-frontend
IMAGE_TAG=latest
CLUSTER_NAME=kube-starter
KIND_CONFIG=clusters/local/kind-config.yaml
ARGOCD_VERSION=stable
SMOKE_ATTEMPTS=24
SMOKE_SLEEP_SECONDS=5
```

Os scripts `.sh` e `.ps1` tambem carregam `.env` automaticamente. Variaveis ja definidas na sessao do terminal têm prioridade sobre o valor do arquivo.

### 8.3 Equivalencia De Comandos

| Acao | macOS/Linux | Windows PowerShell |
| --- | --- | --- |
| verificar ferramentas | `make check` | `powershell -ExecutionPolicy Bypass -File .\scripts\check-tools.ps1` |
| buildar imagens | `make build-images` | `powershell -ExecutionPolicy Bypass -File .\scripts\build-images.ps1` |
| criar cluster | `make cluster-create` | `powershell -ExecutionPolicy Bypass -File .\scripts\create-kind-cluster.ps1` |
| carregar imagens | `make images-load` | `powershell -ExecutionPolicy Bypass -File .\scripts\load-kind-images.ps1` |
| instalar Argo CD | `make argocd-install` | `powershell -ExecutionPolicy Bypass -File .\scripts\install-argocd.ps1` |
| bootstrap GitOps | `make platform-bootstrap` | `powershell -ExecutionPolicy Bypass -File .\scripts\bootstrap-platform.ps1` |
| subir tudo | `make up` | `powershell -ExecutionPolicy Bypass -File .\scripts\up.ps1` |
| status | `make status` | `powershell -ExecutionPolicy Bypass -File .\scripts\status.ps1` |
| smoke test | `make smoke` | `powershell -ExecutionPolicy Bypass -File .\scripts\smoke-test.ps1` |
| destruir cluster | `make down` | `powershell -ExecutionPolicy Bypass -File .\scripts\destroy-kind-cluster.ps1` |

## 9. Cuidados Por Sistema

### Windows

- Use Linux containers no Docker Desktop.
- Garanta que Docker Desktop esteja aberto antes de rodar `kind`.
- Se `kind` falhar criando o cluster, valide `docker ps`.
- Se PowerShell bloquear script, use `-ExecutionPolicy Bypass -File`.
- Se usar WSL2, clone o repo dentro do filesystem Linux.

### macOS

- Docker Desktop precisa estar aberto.
- Em Apple Silicon, as imagens `node:20-alpine` e `nginx:1.27-alpine` suportam ARM64.
- Se portas estiverem ocupadas, altere `FRONTEND_PORT` ou `clusters/local/kind-config.yaml`.

### Linux

- O usuario precisa acessar o socket Docker.
- Depois de `usermod -aG docker`, faca logout/login ou use `newgrp docker`.
- Se firewall bloquear `localhost:8080`, valide primeiro com port-forward.

## 10. Referencias Oficiais

- Docker Desktop: https://docs.docker.com/desktop/
- Docker Engine Linux: https://docs.docker.com/engine/install/
- kind Quick Start: https://kind.sigs.k8s.io/docs/user/quick-start/
- kubectl Windows: https://kubernetes.io/docs/tasks/tools/install-kubectl-windows/
- kubectl macOS: https://kubernetes.io/docs/tasks/tools/install-kubectl-macos/
- kubectl Linux: https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/
- Helm install: https://helm.sh/docs/intro/install/
