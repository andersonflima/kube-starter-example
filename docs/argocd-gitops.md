# Argo CD And GitOps

Este documento explica como encaixar `Argo CD` neste projeto e como ele difere de `Helm`.

## 1. O que e GitOps

GitOps significa tratar o Git como fonte de verdade do ambiente.

Na pratica:

1. voce altera o codigo ou os manifests
2. voce faz commit e push
3. um controller observa o repositorio
4. o controller reconcilia o cluster

O `Argo CD` e um controller que implementa esse modelo para Kubernetes.

## 2. O que o Argo CD faz

O Argo CD:

- observa repositos Git
- detecta drift entre Git e cluster
- exibe sync status e health status
- pode sincronizar automaticamente
- pode desfazer drift manual se `selfHeal` estiver ligado
- pode instalar dependencias operacionais, como Metrics Server, a partir de charts externos

## 3. O que o Argo CD nao faz sozinho

Ele nao builda a sua imagem.

Por isso, o fluxo real costuma ser:

1. pipeline builda imagem
2. pipeline publica imagem
3. repositorio Git recebe mudanca de tag ou values
4. Argo CD sincroniza o cluster

## 4. Helm vs Argo CD

### Helm

- foco: empacotar e instalar
- gatilho: voce ou o CI executa o comando
- modelo: imperativo no momento do deploy

### Argo CD

- foco: reconciliar cluster a partir do Git
- gatilho: mudanca no repositorio ou sync manual
- modelo: declarativo e continuo

### Relacao entre os dois

O Argo CD pode usar:

- manifests YAML puros
- Kustomize
- Helm

Neste projeto, o caminho mais natural e:

- Argo CD como controller GitOps
- Helm como mecanismo de template

## 5. Fluxo deste projeto com Argo CD

```text
[ commit no repositorio ]
          |
          v
[ GitHub ]
          |
          v
[ Argo CD observa a branch main ]
          |
          v
[ Argo CD reconcilia Metrics Server e o chart Helm em helm/kube-starter ]
          |
          v
[ kube-apiserver ]
          |
          v
[ cluster reconcilia frontend e backend ]
```

## 6. Instalando Argo CD

Os comandos abaixo seguem o fluxo recomendado na documentacao oficial do Argo CD para instalacao inicial.

```bash
kubectl create namespace argocd
kubectl apply -n argocd --server-side --force-conflicts \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

Para producao, prefira pin de versao em vez de `stable`, para evitar mudancas inesperadas no bootstrap do controller.

Port-forward da UI/API:

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Senha inicial do admin:

```bash
argocd admin initial-password -n argocd
```

## 7. Aplicando este projeto no Argo CD

O repositorio contem um exemplo pronto:

- [argocd/kube-starter-application.yaml](../argocd/kube-starter-application.yaml)
- [argocd/metrics-server-application.yaml](../argocd/metrics-server-application.yaml)

Aplicacao:

```bash
kubectl apply -f argocd/metrics-server-application.yaml
kubectl apply -f argocd/kube-starter-application.yaml
```

Verificacao:

```bash
kubectl get applications.argoproj.io -n argocd
kubectl get apiservice v1beta1.metrics.k8s.io
kubectl get hpa -n kube-starter
kubectl describe applications.argoproj.io kube-starter -n argocd
argocd app get kube-starter
argocd app sync kube-starter
argocd app wait kube-starter --health --sync
```

### Fluxo com kind

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
kubectl apply -f argocd/metrics-server-application.yaml
kubectl apply -f argocd/kube-starter-application.yaml
kubectl get applications.argoproj.io kube-starter -n argocd
```

## 8. O que a Application deste projeto faz

- usa este repositorio como fonte
- aponta para `main`
- usa `helm/kube-starter` como path
- cria recursos no namespace `kube-starter`
- cria HPAs para backend e frontend
- ativa `prune`
- ativa `selfHeal`
- ativa `CreateNamespace=true`

## 9. O que a Application do Metrics Server faz

- usa o chart oficial `metrics-server`
- instala no namespace `kube-system`
- habilita `ServerSideApply`
- usa `--kubelet-insecure-tls` para facilitar clusters locais como `kind`
- publica a API `metrics.k8s.io`, usada pelo HPA

Em producao, revise `--kubelet-insecure-tls` e prefira certificados de kubelet validos.

## 10. Exemplo de operacao

### Cenario 1: voce muda o values

1. altera `helm/kube-starter/values.yaml`
2. faz commit e push
3. Argo CD detecta a mudanca
4. Argo CD renderiza o chart novamente
5. cluster aplica a nova configuracao

### Cenario 2: alguem muda o cluster manualmente

1. alguem altera um `Deployment` via `kubectl edit`
2. o cluster fica diferente do Git
3. o Argo CD detecta drift
4. se `selfHeal` estiver ligado, ele volta ao estado do Git

## 11. Quando Argo CD vale a pena

- quando existem varios ambientes
- quando varias pessoas fazem deploy
- quando voce quer auditabilidade
- quando quer reduzir deploy manual
- quando quer detectar drift rapidamente

## 12. Quando Helm puro pode bastar

- laboratorio pequeno
- ambiente efemero
- deploy manual controlado
- pouca necessidade de reconciliacao continua

## 13. Regra pratica

- `Helm` sem `Argo CD`: bom para deploy manual ou pipeline simples
- `Helm` com `Argo CD`: melhor para operacao continua e GitOps

## 14. Referencias oficiais

- Argo CD Getting Started: https://argo-cd.readthedocs.io/en/release-3.4/getting_started/
- Argo CD Installation: https://argo-cd.readthedocs.io/en/latest/operator-manual/installation/
- Metrics Server: https://github.com/kubernetes-sigs/metrics-server

## 15. Observacao sobre validacao

O manifesto [argocd/kube-starter-application.yaml](../argocd/kube-starter-application.yaml) depende da CRD `Application` do Argo CD.

Isso significa:

- sem Argo CD instalado, `kubectl` nao reconhece esse kind
- com Argo CD instalado, a validacao e a aplicacao passam a funcionar normalmente
- esse comportamento e esperado e nao indica erro no YAML em si

Para usar o exemplo com `kind`, garanta tambem que as imagens locais foram buildadas e carregadas no cluster antes da sincronizacao.
