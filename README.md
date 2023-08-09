# Performance Tests for Ztunnel

## Setup

To run, first set up a cluster with six user nodes: three with the `role=server` label and three with the `role=client` label.
This ensures that `netperf` and `netserver` pods get deployed in different servers.
Next, go into `netperf/Makefile` and change the value of `CR` to your container registry.
Then, inside `netperf/` build and push with

```bash
make build
make push-cr
```

You will also need a Python 3 with `matplotlib` and `pandas` installed.
Also, make sure that `python -V` is some version of Python 3.
An easy way to get this on Ubuntu is running

```bash
sudo apt install python-is-python3
```

Note that if you are using AKS to set up your cluster, make sure that you use Azure CNI as your network plugin and **DO NOT** use a network policy.
Also, make sure to attach to container registry to your cluster.

## Running Benchmarks

First, install Istio Ambient.
I don't automate this process because there are many installation methods and you might be testing a custom build.
To install the latest release of Istio Ambient, run

```bash
istiocl install --set profile=ambient
```

See [these docs](https://istio.io/latest/docs/setup/getting-started/#download) for how to get the `istioctl` binary.

Now, update `scripts/config.sh` as desired or keep the default values, and run `scripts/setup.sh` to deploy the pods.
Once the deployments are complete, run the tests with `make run`.
This will create graphs in the `graphs/` directory and put intermediate files in `results/` by default.

For more configuration options, see `scripts/run.sh`.

