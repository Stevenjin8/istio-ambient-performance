#! /bin/bash
# Run performance benchmarks

set -eux

source scripts/config.sh

INTER_TEST_SLEEP=0.1s

mkdir -p "$RESULTS"

# First argument is the client namespace
# Second argument is the server namespace
# Third is any extra test arguments for the TCP_CRR and TCP_RR tests
function run-tests() {
    # give values names
    client_ns=$1
    server_ns=$2
    extra_crr_args=$3
    for _ in $(seq "$N_RUNS")
    do
        kubectl exec "deploy/$BENCHMARK_CLIENT" -n "$client_ns" \
        -- netperf $GLOBAL_ARGS -H "$BENCHMARK_SERVER.$server_ns" -t TCP_STREAM \
        -- $TEST_ARGS
        echo "NAMESPACES=$client_ns:$server_ns"
        echo "$TEST_RUN_SEPARATOR"
        sleep "$INTER_TEST_SLEEP"
    done >> "$RESULTS/TCP_STREAM"

    for _ in $(seq "$N_RUNS")
    do
        kubectl exec "deploy/$BENCHMARK_CLIENT" -n "$client_ns" \
        -- netperf $GLOBAL_ARGS -H "$BENCHMARK_SERVER.$server_ns" -t TCP_CRR \
        -- $TEST_ARGS $extra_crr_args 
        echo "NAMESPACES=$client_ns:$server_ns"
        echo "$TEST_RUN_SEPARATOR"
        sleep "$INTER_TEST_SLEEP"
    done >> "$RESULTS/TCP_CRR"

    for _ in $(seq "$N_RUNS")
    do
        kubectl exec "deploy/$BENCHMARK_CLIENT" -n "$client_ns" \
        -- netperf $GLOBAL_ARGS -H "$BENCHMARK_SERVER.$server_ns" -t TCP_RR \
        -- $TEST_ARGS $extra_crr_args 
        echo "NAMESPACES=$client_ns:$server_ns"
        echo "$TEST_RUN_SEPARATOR"
        sleep "$INTER_TEST_SLEEP"
    done >> "$RESULTS/TCP_RR" 
}

# clear output files
true > "$RESULTS/TCP_STREAM"
true > "$RESULTS/TCP_CRR"
true > "$RESULTS/TCP_RR"

# NO MESH

run-tests "$NS_AMBIENT" "$NS_AMBIENT" "$RR_ARGS"
run-tests "$NS_NO_MESH" "$NS_NO_MESH" "$RR_ARGS"
run-tests "$NS_ISTIO"   "$NS_ISTIO"   "$RR_ARGS"

