.PHONY: docker-build apply-local cleanup pods default-ns
K=kubectl
NS=netperf
docker-build:
	make build push -C netperf

apply-local:
	$K create ns $(NS) || true
	$K apply -f deploy.local.yaml -n $(NS)

cleanup:
	$K delete ns/$(NS)

pods:
	$K get pods -n 

default-ns:
	$K config set-context --current --namespace=$(NS)

