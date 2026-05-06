# Debugging Cheatsheet

Comandos diretos para diagnosticar Docker, Compose, Kubernetes, Helm, Argo CD e observabilidade.

## Docker

```bash
docker ps
docker logs backend
docker logs frontend
docker inspect backend
docker inspect frontend
```

## Docker Compose

```bash
docker compose ps
docker compose logs -f
docker compose logs -f backend
docker compose logs -f frontend
docker compose up --build --force-recreate
docker compose down
```

## kind

```bash
kind get clusters
kubectl config current-context
kubectl get nodes -o wide
docker exec kube-starter-control-plane crictl images | grep kube-
```

## Kubernetes

Objetos principais:

```bash
kubectl get pods,deployments,services,hpa,ingresses -n kube-starter
kubectl describe deployment kube-starter-backend -n kube-starter
kubectl describe deployment kube-starter-frontend -n kube-starter
kubectl describe hpa -n kube-starter
```

Logs:

```bash
kubectl logs deployment/kube-starter-backend -n kube-starter
kubectl logs deployment/kube-starter-frontend -n kube-starter
```

Port-forward:

```bash
kubectl port-forward service/kube-starter-backend -n kube-starter 3003:3000
kubectl port-forward service/kube-starter-frontend -n kube-starter 9082:80
```

Ingress:

```bash
kubectl get ingress -n kube-starter
kubectl describe ingress kube-starter -n kube-starter
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller
curl http://kube-starter.localhost:8080/api/health
```

## Helm

```bash
helm lint ./helm/kube-starter
helm template kube-starter ./helm/kube-starter
helm history kube-starter -n kube-starter
helm get values kube-starter -n kube-starter
helm get manifest kube-starter -n kube-starter
helm rollback kube-starter 1 -n kube-starter
```

## Argo CD

Applications:

```bash
kubectl get applications.argoproj.io -n argocd
kubectl describe applications.argoproj.io kube-starter-platform -n argocd
kubectl describe applications.argoproj.io kube-starter -n argocd
```

Pods:

```bash
kubectl get pods -n argocd
kubectl logs deployment/argocd-server -n argocd
kubectl logs deployment/argocd-repo-server -n argocd
kubectl logs statefulset/argocd-application-controller -n argocd
```

UI:

```bash
kubectl port-forward svc/argocd-server -n argocd 8081:443
argocd admin initial-password -n argocd
```

## Metrics Server E HPA

```bash
kubectl get apiservice v1beta1.metrics.k8s.io
kubectl top nodes
kubectl top pods -n kube-starter
kubectl get hpa -n kube-starter
kubectl describe hpa kube-starter-backend -n kube-starter
```

## Prometheus E Grafana

```bash
kubectl get pods -n monitoring
kubectl get servicemonitors.monitoring.coreos.com -A
kubectl get prometheus -n monitoring
kubectl get alertmanager -n monitoring
curl http://prometheus.localhost:8080/-/ready
curl http://grafana.localhost:8080/login
```

## Problemas Comuns

### ImagePullBackOff No kind

As imagens locais precisam ser carregadas no cluster:

```bash
make build-images
make images-load
kubectl rollout restart deployment/kube-starter-backend -n kube-starter
kubectl rollout restart deployment/kube-starter-frontend -n kube-starter
```

### Ingress Nao Responde

Verifique:

```bash
kubectl get pods -n ingress-nginx
kubectl get ingress -A
curl -H "Host: kube-starter.localhost" http://localhost:8080/api/health
```

### HPA Sem Metricas

Verifique:

```bash
kubectl get apiservice v1beta1.metrics.k8s.io
kubectl logs deployment/metrics-server -n kube-system
kubectl top pods -n kube-starter
```

### ServiceMonitor Nao Aparece No Prometheus

Verifique:

```bash
kubectl get crd servicemonitors.monitoring.coreos.com
kubectl get servicemonitors.monitoring.coreos.com -n kube-starter
kubectl get prometheus kube-prometheus-stack -n monitoring -o yaml | grep -A5 serviceMonitorSelector
```

### Application OutOfSync

Verifique:

```bash
kubectl describe applications.argoproj.io kube-starter -n argocd
argocd app get kube-starter
argocd app sync kube-starter
```
