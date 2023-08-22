#! /bin/bash
# Run netperf performance benchmarks

set -eux

source scripts/config.sh

mkdir -p "$FORTIO_RESULTS"

function run-tests() {
    client_ns=$1
    server_ns=$2

    kubectl exec -it -n "$client_ns" deploy/client \
        -- fortio load $FORTIO_SERIAL_HTTP_ARGS -json serial.json "http://$BENCHMARK_SERVER.$server_ns:8080"
    echo "$client_ns:$server_ns" >> "$FORTIO_RESULTS/serial"
    kubectl exec -it -n "$client_ns" deploy/client >> "$FORTIO_RESULTS/serial" -- cat serial.json
    echo $TEST_RUN_SEPARATOR >> "$FORTIO_RESULTS/serial"

    kubectl exec -it -n "$client_ns" deploy/client \
        -- fortio load $FORTIO_PARALLEL_HTTP_ARGS -json parallel.json "http://$BENCHMARK_SERVER.$server_ns:8080"
    echo "$client_ns:$server_ns" >> "$FORTIO_RESULTS/parallel"
    kubectl exec -it -n "$client_ns" deploy/client >> "$FORTIO_RESULTS/parallel" -- cat parallel.json
    echo $TEST_RUN_SEPARATOR >> "$FORTIO_RESULTS/parallel"
}

true > "$FORTIO_RESULTS/serial"
true > "$FORTIO_RESULTS/parallel"
run-tests $NS_AMBIENT  $NS_AMBIENT
run-tests $NS_SIDECAR  $NS_SIDECAR
run-tests $NS_NO_MESH  $NS_NO_MESH
run-tests $NS_WAYPOINT $NS_WAYPOINT
