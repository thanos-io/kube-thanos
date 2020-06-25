# kube-thanos

> Note that everything is experimental and may change significantly at any time.

This repository collects Kubernetes manifests combined with documentation and scripts to provide easy to deploy experience for Thanos on Kubernetes.

The content of this project is written in [jsonnet](http://jsonnet.org/). This project could both be described as a package as well as a library.

## Prerequisites

Update the docker image version in StashInvest/kube-prometheus/secops/manifests/prometheus-prometheus.yaml to match the docker image used in StashInvest/kube-thanos/manifests.
In this case, it is: v0.13.0-rc.0

The code snippet in prometheus-prometheus.yaml is:

  thanos:
    baseImage: quay.io/thanos/thanos
    objectStorageConfig:
      key: thanos.yaml
      name: thanos-objectstorage
    #version: v0.7.0
    version: v0.13.0-rc.0


### kind

In order to just try out this stack, start [kind](https://github.com/kubernetes-sigs/kind) with the following command:

```shell
$ kind create cluster
```

## Quickstart

This project is intended to be used as a library (i.e. the intent is not for you to create your own modified copy of this repository).

Though for a quickstart a compiled version of the Kubernetes [manifests](manifests) generated with this library (specifically with `example.jsonnet`) is checked into this repository in order to try the content out quickly. To try out the stack un-customized run:
 * Simply create the stack:
```shell
$ kubectl create -f manifests/
```

 * And to teardown the stack:
```shell
$ kubectl delete -f manifests/
```

## Customizing kube-thanos

This section:
 * describes how to customize the kube-thanos library via compiling the kube-thanos manifests yourself (as an alternative to the [Quickstart section](#Quickstart)).
 * still doesn't require you to make a copy of this entire repository, but rather only a copy of a few select files.

### Installing

The content of this project consists of a set of [jsonnet](http://jsonnet.org/) files making up a library to be consumed.

Install this library in your own project with [jsonnet-bundler](https://github.com/jsonnet-bundler/jsonnet-bundler#install) (the jsonnet package manager):
```shell
$ mkdir my-kube-thanos; cd my-kube-thanos
$ jb init  # Creates the initial/empty `jsonnetfile.json`
# Install the kube-thanos dependency
$ jb install github.com/thanos-io/kube-thanos/jsonnet/kube-thanos@master # Creates `vendor/` & `jsonnetfile.lock.json`, and fills in `jsonnetfile.json`
```

> `jb` can be installed with `go get github.com/jsonnet-bundler/jsonnet-bundler/cmd/jb`

> An e.g. of how to install a given version of this library: `jb install github.com/thanos-io/kube-thanos/jsonnet/kube-thanos@master`

In order to update the kube-thanos dependency, simply use the jsonnet-bundler update functionality:
```shell
$ jb update
```

### Compiling

e.g. of how to compile the manifests: `./build.sh example.jsonnet`

> before compiling, install `gojsontoyaml` tool with `go get github.com/brancz/gojsontoyaml`

Here's [example.jsonnet](example.jsonnet):

[embedmd]:# (example.jsonnet)
```jsonnet
local k = import 'ksonnet/ksonnet.beta.4/k.libsonnet';
local sts = k.apps.v1.statefulSet;
local deployment = k.apps.v1.deployment;
local t = (import 'kube-thanos/thanos.libsonnet');

local commonConfig = {
  config+:: {
    local cfg = self,
    namespace: 'thanos',
    version: 'v0.13.0-rc.0',
    image: 'quay.io/thanos/thanos:' + cfg.version,
    objectStorageConfig: {
      name: 'thanos-objectstorage',
      key: 'thanos.yaml',
    },
    volumeClaimTemplate: {
      spec: {
        accessModes: ['ReadWriteOnce'],
        resources: {
          requests: {
            storage: '10Gi',
          },
        },
      },
    },
  },
};

//local b = t.bucket + commonConfig + {
//  config+:: {
//    name: 'thanos-bucket',
//    replicas: 1,
//  },
//};
//
//local c = t.compact + t.compact.withVolumeClaimTemplate + t.compact.withServiceMonitor + commonConfig + {
//  config+:: {
//    name: 'thanos-compact',
//    replicas: 1,
//  },
//};
//
//local re = t.receive + t.receive.withVolumeClaimTemplate + t.receive.withServiceMonitor + commonConfig + {
//  config+:: {
//    name: 'thanos-receive',
//    replicas: 1,
//    replicationFactor: 1,
//  },
//};
//
//local ru = t.rule + t.rule.withVolumeClaimTemplate + t.rule.withServiceMonitor + commonConfig + {
//  config+:: {
//    name: 'thanos-rule',
//    replicas: 1,
//  },
//};

local s = t.store + t.store.withVolumeClaimTemplate + t.store.withServiceMonitor + commonConfig + {
  config+:: {
    name: 'thanos-store',
    replicas: 1,
  },
};

local q = t.query + t.query.withServiceMonitor + commonConfig + {
  config+:: {
    name: 'thanos-query',
    replicas: 1,
    stores: [
      'dnssrv+_grpc._tcp.%s.%s.svc.cluster.local' % [service.metadata.name, service.metadata.namespace]
      for service in [s.service]
    ],
    replicaLabels: ['prometheus_replica', 'rule_replica'],
  },
};

//local finalRu = ru {
//  config+:: {
//    queriers: ['dnssrv+_http._tcp.%s.%s.svc.cluster.local' % [q.service.metadata.name, q.service.metadata.namespace]],
//  },
//};

//{ ['thanos-bucket-' + name]: b[name] for name in std.objectFields(b) } +
//{ ['thanos-compact-' + name]: c[name] for name in std.objectFields(c) } +
//{ ['thanos-receive-' + name]: re[name] for name in std.objectFields(re) } +
//{ ['thanos-rule-' + name]: finalRu[name] for name in std.objectFields(finalRu) } +
{ ['thanos-store-' + name]: s[name] for name in std.objectFields(s) } +
{ ['thanos-query-' + name]: q[name] for name in std.objectFields(q) }
```

And here's the [build.sh](build.sh) script (which uses `vendor/` to render all manifests in a json structure of `{filename: manifest-content}`):

[embedmd]:# (build.sh)
```sh
#!/usr/bin/env bash

# This script uses arg $1 (name of *.jsonnet file to use) to generate the manifests/*.yaml files.

set -e
set -x
# only exit with zero if all commands of the pipeline exit successfully
set -o pipefail

# Make sure to start with a clean 'manifests' dir
rm -rf manifests
mkdir manifests

# optional, but we would like to generate yaml, not json
jsonnet -J vendor -m manifests "${1-example.jsonnet}" | xargs -I{} sh -c 'cat {} | gojsontoyaml > {}.yaml; rm -f {}' -- {}

# The following script generates all components, mostly used for testing

rm -rf examples/all/manifests
mkdir examples/all/manifests

jsonnet -J vendor -m examples/all/manifests "${1-all.jsonnet}" | xargs -I{} sh -c 'cat {} | gojsontoyaml > {}.yaml; rm -f {}' -- {}
```

> Note you need `jsonnet` (`go get github.com/google/go-jsonnet/cmd/jsonnet`) and `gojsontoyaml` (`go get github.com/brancz/gojsontoyaml`) installed to run `build.sh`. If you just want json output, not yaml, then you can skip the pipe and everything afterwards.

This script runs the jsonnet code, then reads each key of the generated json and uses that as the file name, and writes the value of that key to that file, and converts each json manifest to yaml.

### Apply the kube-thanos stack
The previous steps (compilation) has created a bunch of manifest files in the manifest/ folder.
Now simply use `kubectl` to install Thanos as per your configuration:

```shell
$ kubectl apply -f manifests/
```

Check the monitoring namespace (or the namespace you have specific in `namespace: `) and make sure the pods are running.
