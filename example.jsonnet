local t = import 'kube-thanos/thanos.libsonnet';

// For an example with every option and component, please check all.jsonnet

local commonConfig = {
  config+:: {
    local cfg = self,
    namespace: 'thanos',
    version: 'v0.22.0',
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

local s = t.store(commonConfig.config {
  replicas: 1,
  serviceMonitor: true,
});

local split = t.receiveSplit(commonConfig.config {
  replicas: 1,
  replicaLabels: ['receive_replica'],
  replicationFactor: 1,
  // Disable shipping to object storage for the purposes of this example
  objectStorageConfig: null,
});

local q = t.query(commonConfig.config {
  replicas: 1,
  replicaLabels: ['prometheus_replica', 'rule_replica'],
  serviceMonitor: true,
  stores: split.ingestorStores,
});

{ ['thanos-store-' + name]: s[name] for name in std.objectFields(s) } +
{ ['thanos-query-' + name]: q[name] for name in std.objectFields(q) } +
{
  ['thanos-receive-' + hashring + '-' + resource]: split.ingestors[hashring][resource]
  for hashring in std.objectFields(split.ingestors)
  for resource in std.objectFields(split.ingestors[hashring])
  if split.ingestors[hashring][resource] != null
}
{ ['thanos-receive-' + resource]: split[resource] for resource in std.objectFields(split) if resource != 'ingestors' }
