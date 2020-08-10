# kube-thanos

> Note that everything is experimental and may change significantly at any time.

This repository collects Kubernetes manifests combined with documentation and scripts to provide easy to deploy experience for Thanos on Kubernetes.

The content of this project is written in [jsonnet](http://jsonnet.org/). This project could both be described as a package as well as a library.

## Prerequisites

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
$ jb install github.com/thanos-io/kube-thanos/jsonnet/kube-thanos # Creates `vendor/` & `jsonnetfile.lock.json`, and fills in `jsonnetfile.json`
```

> `jb` can be installed with `go get github.com/jsonnet-bundler/jsonnet-bundler/cmd/jb`

> An e.g. of how to install a given version of this library: `jb install github.com/thanos-io/kube-thanos/jsonnet/kube-thanos`

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
// Usually this should be an absolute import paths.
// In this instance, however, we use a local symlink cause this is within the same repository.
local thanos = import 'kube-thanos/thanos.libsonnet';

// This is a config shared across components.
// Before passing the params to the component this config is merged with the component's config.
local config = {
  namespace: 'thanos',
  version: 'v0.14.0',
  image: 'quay.io/thanos/thanos:' + self.version,
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
};

local store = thanos.store(config {
  name: 'thanos-store',
  replicas: 1,
  serviceMonitor: true,
});

local query = thanos.query(config {
  replicas: 1,
  replicaLabels: ['prometheus_replica', 'rule_replica'],
  serviceMonitor: true,
});

{ ['thanos-store-' + name]: store[name] for name in std.objectFields(store) } +
{ ['thanos-query-' + name]: query[name] for name in std.objectFields(query) }
```

> Note you need `jsonnet` (`go get github.com/google/go-jsonnet/cmd/jsonnet`) and `gojsontoyaml` (`go get github.com/brancz/gojsontoyaml`) installed to run `build.sh`. If you just want json output, not yaml, then you can skip the pipe and everything afterwards.

This script runs the jsonnet code, then reads each key of the generated json and uses that as the file name, and writes the value of that key to that file, and converts each json manifest to yaml.

### Extending / Overwriting

Whenever there are very specific changes you want to make to the Thanos deployment, that only really you need or aren't applicable to be part of kube-thanos, 
you can use merging of jsonnet objects and arrays to extend or overwrite the generated Kubernetes objects.


[embedmd]:# (examples/extend.jsonnet)
```jsonnet
// Usually this should be an absolute import paths.
// In this instance, however, we use a local symlink cause this is within the same repository.
local thanos = import 'kube-thanos/thanos.libsonnet';

// This example demonstrates how to overwrite or extends each component,
// whenever out-of-the-box configuration isn't enough.

local query = thanos.query({
  namespace: 'thanos',
  version: 'v0.13.0',
  image: 'quay.io/thanos/thanos:' + self.version,
  replicas: 1,
  replicaLabels: ['replica'],
});

local queryExtended = query {
  deployment+: {
    metadata+: {
      // Let's extend the deployment with our specific annotations
      annotations: {
        'some-specific-annotation': 'foobar',
      },
      // We can also overwrite existing labels completely.
      labels: {
        app: 'thanos-query',
      },
    },
    // We can even add a sidecar without changing the initial component.
    // By doing that, we can still upgrade kube-thanos but never lose our own sidecar.
    spec+: {
      template+: {
        spec+: {
          containers+: [
            {
              name: 'thanos-query-sidecar',
              image: 'quay.io/org/app:dont-use-latest',
              args: ['--foo=bar'],
            },
          ],
        },
      },
    },
  },
};

{ ['thanos-query-' + name]: queryExtended[name] for name in std.objectFields(queryExtended) if queryExtended[name] != null }

// The same can be done without the extra variable:

// local query = thanos.query({
//   namespace: 'thanos',
//   version: 'v0.13.0',
//   image: 'quay.io/thanos/thanos:' + self.version,
//   replicas: 1,
//   replicaLabels: ['replica'],
// }) + {
//   deployment+: {
//     metadata+: {
//       annotations: {
//         'some-specific-annotation': 'foobar',
//       },
//     },
//   },
// };



```
