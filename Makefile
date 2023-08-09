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
	inkscape ./pres-data/1.18/graphs/TCP_RR.svg     -m ./pres-data/1.18/graphs/TCP_RR.wmf
	inkscape ./pres-data/1.18/graphs/TCP_CRR.svg    -m ./pres-data/1.18/graphs/TCP_CRR.wmf
	inkscape ./pres-data/1.18/graphs/TCP_STREAM.svg -m ./pres-data/1.18/graphs/TCP_STREAM.wmf

pres-master:
	RESULTS=./pres-data/master-old/results OUT_DIR=./pres-data/master-old/graphs python ./scripts/graphs.py
	sed -i "s/\(.*\)font:\(.*\)Ambient\(.*\)/\1font: bold\2Ambient\3/" pres-data/master-old/graphs/*.svg
	inkscape ./pres-data/master-old/graphs/TCP_RR.svg     -m ./pres-data/master-old/graphs/TCP_RR.wmf
	inkscape ./pres-data/master-old/graphs/TCP_CRR.svg    -m ./pres-data/master-old/graphs/TCP_CRR.wmf
	inkscape ./pres-data/master-old/graphs/TCP_STREAM.svg -m ./pres-data/master-old/graphs/TCP_STREAM.wmf

pres-fast:
	RESULTS=./pres-data/fast/results OUT_DIR=./pres-data/fast/graphs python ./scripts/graphs.py
	sed -i "s/\(.*\)font:\(.*\)Ambient\(.*\)/\1font: bold\2Ambient\3/" pres-data/fast/graphs/*.svg
	inkscape ./pres-data/fast/graphs/TCP_RR.svg     -m ./pres-data/fast/graphs/TCP_RR.wmf
	inkscape ./pres-data/fast/graphs/TCP_CRR.svg    -m ./pres-data/fast/graphs/TCP_CRR.wmf
	inkscape ./pres-data/fast/graphs/TCP_STREAM.svg -m ./pres-data/fast/graphs/TCP_STREAM.wmf

