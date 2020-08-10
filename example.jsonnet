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
