# Performance Tests for Ztunnel

## Setup

To run, first set up a cluster with nodes with the

```
role=server
role=client
```

labels.
This ensures that `netperf` and `netserver` pods get deployed in different servers.
Next, go into `netperf/Makefile` and change the name of the container registry to yours. 
Then, inside `netperf/` build and push with

```bash
make build
make push-cr
```

You will also need a Python 3 with `matplotlib` and `pandas` installed.
Also, make sure that `python -V` is some version of Python 3.

## Running Benchmarks

Now, update `scripts/config.sh` and run `scripts/setup.sh` to deploy the pods.
Once the deployments are complete, run the tests wtih `scripts/run.sh`.
The data will be saved in `results/` as key-value pairs.
The `./scripts/gen_csv.sh` script will turn them into `csv` files.
Finally, create graphs with `python ./scripts/graphs.py`.


