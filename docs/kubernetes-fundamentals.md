# Kubernetes Fundamentals

Este documento aprofunda dois blocos:

- componentes internos do cluster
- recursos principais aplicados por este projeto

## 1. Componentes do control plane e dos nodes

### kube-apiserver

O `kube-apiserver` e a porta de entrada do Kubernetes.

- recebe requisicoes de `kubectl`, `Helm`, `Argo CD` e controllers
- valida manifests
- aplica autenticacao e autorizacao
- persiste mudancas no `etcd`

Se o `kube-apiserver` nao responde, praticamente nada novo entra no cluster.

### etcd

O `etcd` e o armazenamento persistente do estado do cluster.

- guarda `Deployments`, `Services`, `Secrets`, `ConfigMaps`, `Pods` e metadados
- mantem o estado desejado e parte importante do estado observado
- e critico para consistencia do cluster

Sem `etcd`, o control plane perde sua fonte de verdade.

### controller-manager

O `controller-manager` executa varios controllers.

A ideia central de um controller e:

1. ler o estado desejado
2. ler o estado atual
3. comparar os dois
4. corrigir a diferenca

Exemplo:

- se um `Deployment` pede 2 replicas
- e existe apenas 1 Pod
- o controller cria outro Pod

### scheduler

O `scheduler` decide onde um Pod pendente deve rodar.

Ele considera:

- CPU e memoria disponiveis
- afinidade e anti-afinidade
- `taints` e `tolerations`
- restricoes de topology

O scheduler nao cria container. Ele apenas escolhe o node.

### kubelet

O `kubelet` roda em cada node.

Ele:

- observa os Pods destinados ao seu node
- conversa com o runtime de containers
- garante que os containers foram criados
- reporta status de volta ao control plane

Se o scheduler escolhe o node, o kubelet e quem executa de fato.

## 2. Fluxo completo de um deploy

### Com Helm

```text
[ helm upgrade --install ]
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
            |
            v
[ Pod em execucao ]
```

### Com Argo CD

```text
[ git push ]
      |
      v
[ Argo CD percebe mudanca ]
      |
      v
[ Argo CD renderiza chart Helm ]
      |
      v
[ kube-apiserver ]
      |
      v
[ resto do cluster segue o mesmo fluxo ]
```

## 3. Recursos principais

### Namespace

O `Namespace` separa recursos dentro do mesmo cluster.

Neste projeto:

- `argocd`: controller GitOps
- `ingress-nginx`: controller de entrada HTTP
- `monitoring`: Prometheus, Alertmanager e Grafana
- `kube-starter`: aplicacao frontend/backend

### Pod

O `Pod` e a menor unidade executavel do Kubernetes.

- tem um ou mais containers
- possui IP proprio
- e efemero

Se um Pod morre, outro pode ser criado com outro nome e outro IP.

### Deployment

O `Deployment` gerencia Pods de forma declarativa.

Ele permite:

- definir numero de replicas
- fazer rollout
- fazer rollback
- trocar imagem
- manter disponibilidade durante atualizacao

Neste projeto, existe um `Deployment` para backend e outro para frontend.

### Service

O `Service` cria um endpoint estavel para um conjunto de Pods selecionados por label.

Ele resolve:

- IP dinamico dos Pods
- balanceamento simples entre replicas
- descoberta de servico no cluster

Neste projeto:

- o frontend usa o nome do `Service` do backend
- o Ingress aponta para o `Service` do frontend

### Ingress

O `Ingress` define regras HTTP/HTTPS para entrada de trafego externo.

Ele normalmente roteia:

- host
- path
- TLS

para um ou mais `Services`.

Neste projeto, o `Ingress` e opcional e aponta para o `Service` do frontend.

### HorizontalPodAutoscaler

O `HorizontalPodAutoscaler` ajusta o numero de replicas de um `Deployment`.

Ele compara:

- metricas atuais de CPU e memoria
- metas declaradas no HPA
- limites minimo e maximo de replicas

Neste projeto, backend e frontend possuem HPA configurado pelo chart Helm.

### Metrics Server

O `Metrics Server` coleta metricas de uso de recursos de Pods e Nodes e publica a API `metrics.k8s.io`.

Sem ele, o HPA ate pode existir, mas fica sem metricas para decidir escala.

### ServiceMonitor

O `ServiceMonitor` e um recurso criado pelo Prometheus Operator.

Ele declara quais `Services` devem ser coletados pelo Prometheus.

Neste projeto, o backend expoe `/metrics` e o chart Helm pode criar um `ServiceMonitor` apontando para esse endpoint.

### Prometheus

O `Prometheus` coleta, armazena e consulta series temporais.

Neste projeto, ele vem pelo chart `kube-prometheus-stack`.

### Grafana

O `Grafana` visualiza metricas e dashboards.

Neste projeto, ele tambem vem pelo `kube-prometheus-stack`.

## 4. Como esses objetos se relacionam

```text
[ Usuario ]
    |
    v
[ Ingress ]
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

Fluxo de observabilidade:

```text
[ Backend /metrics ]
        ^
        |
[ ServiceMonitor ]
        ^
        |
[ Prometheus Operator ]
        |
        v
[ Prometheus ] -> [ Grafana ]
```

## 5. Leitura pratica deste repositorio

### Backend

- `Deployment`: garante que o backend esteja rodando
- `Service`: expoe o backend dentro do cluster

### Frontend

- `Deployment`: garante que o frontend esteja rodando
- `Service`: expoe o frontend dentro do cluster
- `Ingress`: opcionalmente publica o frontend para fora

## 6. Como pensar em cada camada

- `Pod`: execucao
- `Deployment`: disponibilidade e rollout
- `Service`: comunicacao
- `Ingress`: exposicao web
- `HorizontalPodAutoscaler`: escala horizontal
- `Metrics Server`: fonte de metricas de recursos
- `ServiceMonitor`: descoberta declarativa de metricas para Prometheus
- `Prometheus`: coleta e consulta de metricas
- `Grafana`: visualizacao de dashboards
- `kube-apiserver`: entrada da API
- `etcd`: persistencia do estado
- `controller-manager`: reconciliacao
- `scheduler`: decisao de alocacao
- `kubelet`: execucao no node
