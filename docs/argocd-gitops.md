# Argo CD E GitOps

Este documento explica a camada GitOps do projeto.

## 1. Papel Do Argo CD

O Argo CD observa o Git e reconcilia o cluster para o estado declarado.

Fluxo:

```text
[ commit no repositorio ]
          |
          v
[ Argo CD observa main ]
          |
          v
[ Argo CD aplica Applications ]
          |
          v
[ Kubernetes reconcilia recursos ]
```

Ele nao builda imagens. Em um fluxo real, a pipeline builda e publica imagens, depois atualiza a tag declarada no Git.

## 2. Estrutura GitOps

```text
argocd/
|-- projects/
|   `-- kube-starter-project.yaml
|-- root-application.yaml
`-- applications/
    |-- ingress-nginx-application.yaml
    |-- metrics-server-application.yaml
    |-- kube-prometheus-stack-application.yaml
    `-- kube-starter-application.yaml
```

Responsabilidades:

- `AppProject`: limita repositorios e namespaces aceitos
- `root-application`: implementa app-of-apps
- `applications/*`: declara cada componente reconciliado

## 3. Componentes Gerenciados

- `ingress-nginx`: entrada HTTP local
- `metrics-server`: metricas de CPU/memoria usadas pelo HPA
- `kube-prometheus-stack`: Prometheus Operator, Prometheus, Alertmanager e Grafana
- `kube-starter`: aplicacao deste repositorio via chart Helm

## 4. Bootstrap

Crie cluster, imagens e instale Argo CD:

```bash
make cluster-create
make build-images
make images-load
make argocd-install
```

Suba a plataforma:

```bash
make platform-bootstrap
```

Atalho:

```bash
make up
```

## 5. Acompanhamento

```bash
kubectl get applications.argoproj.io -n argocd
kubectl get pods -n ingress-nginx
kubectl get pods -n monitoring
kubectl get pods -n kube-starter
```

Se usar o CLI:

```bash
argocd app get kube-starter-platform
argocd app get kube-starter
argocd app wait kube-starter --health --sync --timeout 300
```

## 6. Acesso

Aplicacao:

```text
http://kube-starter.localhost:8080
```

Grafana:

```text
http://grafana.localhost:8080
usuario: admin
senha: admin
```

Prometheus:

```text
http://prometheus.localhost:8080
```

Argo CD:

```bash
kubectl port-forward svc/argocd-server -n argocd 8081:443
argocd admin initial-password -n argocd
```

## 7. Multi-Source Applications

As Applications de charts externos usam `sources`.

Exemplo conceitual:

```yaml
sources:
  - repoURL: https://prometheus-community.github.io/helm-charts
    chart: kube-prometheus-stack
    targetRevision: 84.5.0
    helm:
      valueFiles:
        - $values/platform/monitoring/values.yaml
  - repoURL: https://github.com/andersonflima/kube-starter-example.git
    targetRevision: main
    ref: values
```

Isso permite instalar um chart externo usando values versionados neste repositorio.

## 8. Ordem De Sync

As Applications usam `argocd.argoproj.io/sync-wave`:

- wave `0`: ingress-nginx e metrics-server
- wave `10`: kube-prometheus-stack
- wave `20`: kube-starter

O chart da aplicacao habilita `ServiceMonitor` no fluxo GitOps. Como esse recurso depende das CRDs do Prometheus Operator, a Application da aplicacao usa retry e `SkipDryRunOnMissingResource=true`.

## 9. Ajustes Para Fork Ou Branch

Se voce rodar a partir de um fork, ajuste:

- `repoURL`
- `targetRevision`

Arquivos afetados:

```text
argocd/root-application.yaml
argocd/applications/*.yaml
```

## 10. Referencias Oficiais

- Argo CD Getting Started: https://argo-cd.readthedocs.io/en/stable/getting_started/
- Argo CD Application spec: https://argo-cd.readthedocs.io/en/stable/user-guide/application-specification/
- Argo CD multiple sources: https://argo-cd.readthedocs.io/en/stable/user-guide/multiple_sources/
