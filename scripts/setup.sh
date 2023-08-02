#! /bin/bash
#set up k8 environment
set -eux

# set up config variables
source scripts/config.sh

# create the namespaces
kubectl create namespace $NS_NO_MESH || true # in case the namespace already exists
kubectl create namespace $NS_ISTIO   || true
kubectl create namespace $NS_AMBIENT || true

# install both ambient and normal Istio
# they should be both work on the same mesh
# assume istio is already installed so I can use custom images
# istioctl install --set profile=ambient -y

# inject Envoy sidecars into pods
kubectl label namespace "$NS_ISTIO" istio-injection=enabled
# use ambient data plane
kubectl label namespace "$NS_AMBIENT" istio.io/dataplane-mode=ambient
# WARNING you can't have NS_ISTIO == NS_AMBIENT

# create the clients and server 
kubectl apply -f "$YAML_PATH" -n "$NS_NO_MESH"
kubectl apply -f "$YAML_PATH" -n "$NS_ISTIO"
kubectl apply -f "$YAML_PATH" -n "$NS_AMBIENT"

# wait for deployments to roll out
echo "If this takes a really long time, you might have forgotten to label you nodes."
kubectl rollout status -n "$NS_NO_MESH" -f yaml/deploy.yaml
kubectl rollout status -n "$NS_ISTIO"   -f yaml/deploy.yaml
kubectl rollout status -n "$NS_AMBIENT" -f yaml/deploy.yaml

