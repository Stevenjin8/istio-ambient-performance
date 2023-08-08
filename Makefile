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

.PHONY: pres pres-1.18 pres-master pres-fast

pres: pres-118 pres-master pres-fast

pres-118:
	RESULTS=./pres-data/1.18/results OUT_DIR=./pres-data/1.18/graphs python ./scripts/graphs.py
	sed -i "s/\(.*\)font:\(.*\)Ambient\(.*\)/\1font: bold\2Ambient\3/" pres-data/1.18/graphs/*.svg

pres-master:
	RESULTS=./pres-data/master-old/results OUT_DIR=./pres-data/master-old/graphs python ./scripts/graphs.py
	sed -i "s/\(.*\)font:\(.*\)Ambient\(.*\)/\1font: bold\2Ambient\3/" pres-data/master-old/graphs/*.svg

pres-fast:
	RESULTS=./pres-data/fast/results OUT_DIR=./pres-data/fast/graphs python ./scripts/graphs.py
	sed -i "s/\(.*\)font:\(.*\)Ambient\(.*\)/\1font: bold\2Ambient\3/" pres-data/fast/graphs/*.svg

