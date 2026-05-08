SHELL := /bin/sh

.PHONY: check build-images cluster-create images-load argocd-install platform-bootstrap up status smoke down helm-lint helm-template helm-install-local helm-uninstall

check:
	./scripts/check-tools.sh

build-images:
	./scripts/build-images.sh

cluster-create:
	./scripts/create-kind-cluster.sh

images-load:
	./scripts/load-kind-images.sh

argocd-install:
	./scripts/install-argocd.sh

platform-bootstrap:
	./scripts/bootstrap-platform.sh

up:
	./scripts/check-tools.sh
	./scripts/build-images.sh
	./scripts/create-kind-cluster.sh
	./scripts/load-kind-images.sh
	./scripts/install-argocd.sh
	./scripts/bootstrap-platform.sh

status:
	kubectl get applications.argoproj.io -n argocd
	kubectl get pods -n ingress-nginx
	kubectl get pods -n monitoring
	kubectl get pods,svc,hpa,ingress -n kube-starter

smoke:
	./scripts/smoke-test.sh

down:
	./scripts/destroy-kind-cluster.sh

helm-lint:
	helm lint ./helm/kube-starter

helm-template:
	helm template kube-starter ./helm/kube-starter --namespace kube-starter

helm-install-local:
	helm upgrade --install kube-starter ./helm/kube-starter \
		--namespace kube-starter \
		--create-namespace \
		--values helm/kube-starter/values.yaml \
		--values helm/kube-starter/values-local.yaml

helm-uninstall:
	helm uninstall kube-starter -n kube-starter
