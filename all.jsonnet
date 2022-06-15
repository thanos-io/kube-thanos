local t = import 'kube-thanos/thanos.libsonnet';

// THIS IS MERELY AN EXAMPLE MEANT TO SHOW HOW TO USE ALL COMPONENTS!
// Neither this example nor its manifests in examples/all/manifests/ are meant to ever be run.

local commonConfig = {
  local cfg = self,
  namespace: 'thanos',
  version: 'v0.26.0',
  image: 'quay.io/thanos/thanos:' + cfg.version,
  replicaLabels: ['prometheus_replica', 'rule_replica'],
  objectStorageConfig: {
    name: 'thanos-objectstorage',
    key: 'thanos.yaml',
    tlsSecretName: '',
    tlsSecretMountPath: '',
  },
  resources: {
    requests: { cpu: 0.123, memory: '123Mi' },
    limits: { cpu: 0.420, memory: '420Mi' },
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
  // This enables jaeger tracing for all components, as commonConfig is shared
  tracing+: {
    type: 'JAEGER',
    config+: {
      sampler_type: 'ratelimiting',
      sampler_param: 2,
    },
  },
};

local b = t.bucket(commonConfig {
  replicas: 1,
  label: 'cluster_name',
  refresh: '5m',
  // Example on how to overwrite the tracing config on a per component basis
  // tracing+: {
  //   config+: {
  //     service_name: 'awesome-thanos-bucket',
  //   },
  // },
});

local br = t.bucketReplicate(commonConfig {
  replicas: 1,
  // Use the same object storage secret as an example.
  // Need to use another one in real cases.
  objectStorageToConfig: {
    name: 'thanos-objectstorage',
    key: 'thanos.yaml',
  },
  compactionLevels: [1, 2, 3],
  resolutions: ['0s'],
});

local c = t.compact(commonConfig {
  replicas: 1,
  serviceMonitor: true,
  disableDownsampling: true,
  deduplicationReplicaLabels: super.replicaLabels,  // reuse same labels for deduplication
});

local cs = t.compactShards(commonConfig {
  shards: 3,
  sourceLabels: ['cluster'],
  replicas: 1,
  serviceMonitor: true,
  disableDownsampling: true,
});

local re = t.receive(commonConfig {
  replicas: 1,
  replicationFactor: 1,
  serviceMonitor: true,
  hashringConfigMapName: 'hashring',
});

local ru = t.rule(commonConfig {
  replicas: 1,
  rulesConfig: [{ name: 'test', key: 'test' }],
  alertmanagersURLs: ['alertmanager:9093'],
  alertmanagerConfigFile: {
    name: 'thanos-ruler-config',
    key: 'config.yaml',
  },
  remoteWriteConfigFile: {
    name: 'thanos-stateless-ruler-config',
    key: 'rw-config.yaml',
  },
  reloaderImage: 'jimmidyson/configmap-reload:v0.5.0',
  serviceMonitor: true,
});

local sc = t.sidecar(commonConfig {
  // namespace: 'monitoring',
  serviceMonitor: true,
  // Labels of the Prometheus pods with a Thanos Sidecar container
  podLabelSelector: {
    // Here it is the default label given by the prometheus-operator
    // to all Prometheus pods
    app: 'prometheus',
  },
});

local s = t.store(commonConfig {
  replicas: 1,
  serviceMonitor: true,
  bucketCache: {
    type: 'memcached',
    config+: {
      // NOTICE: <MEMCACHED_SERVICE> is a placeholder to generate examples.
      // List of memcached addresses, that will get resolved with the DNS service discovery provider.
      // For DNS service discovery reference https://thanos.io/tip/thanos/service-discovery.md/#dns-service-discovery
      addresses: ['dnssrv+_client._tcp.<MEMCACHED_SERVICE>.%s.svc.cluster.local' % commonConfig.namespace],
    },
  },
  indexCache: {
    type: 'memcached',
    config+: {
      // NOTICE: <MEMCACHED_SERVICE> is a placeholder to generate examples.
      // List of memcached addresses, that will get resolved with the DNS service discovery provider.
      // For DNS service discovery reference https://thanos.io/tip/thanos/service-discovery.md/#dns-service-discovery
      addresses: ['dnssrv+_client._tcp.<MEMCACHED_SERVICE>.%s.svc.cluster.local' % commonConfig.namespace],
    },
  },
});

local q = t.query(commonConfig {
  name: 'thanos-query',
  replicas: 1,
  externalPrefix: '',
  resources: {},
  queryTimeout: '5m',
  autoDownsampling: true,
  lookbackDelta: '15m',
  ports: {
    grpc: 10901,
    http: 9090,
  },
  serviceMonitor: true,
  logLevel: 'debug',
});

local finalRu = t.rule(ru.config {
  queriers: ['dnssrv+_http._tcp.%s.%s.svc.cluster.local' % [q.service.metadata.name, q.service.metadata.namespace]],
});

local qf = t.queryFrontend(commonConfig {
  replicas: 1,
  downstreamURL: 'http://%s.%s.svc.cluster.local.:%d' % [
    q.service.metadata.name,
    q.service.metadata.namespace,
    q.service.spec.ports[1].port,
  ],
  splitInterval: '12h',
  maxRetries: 10,
  logQueriesLongerThan: '10s',
  serviceMonitor: true,
  queryRangeCache: {
    type: 'memcached',
    config+: {
      // NOTICE: <MEMCACHED_SERVICE> is a placeholder to generate examples.
      // List of memcached addresses, that will get resolved with the DNS service discovery provider.
      // For DNS service discovery reference https://thanos.io/tip/thanos/service-discovery.md/#dns-service-discovery
      addresses: ['dnssrv+_client._tcp.<MEMCACHED_SERVICE>.%s.svc.cluster.local' % commonConfig.namespace],
    },
  },
  labelsCache: {
    type: 'memcached',
    config+: {
      // NOTICE: <MEMCACHED_SERVICE> is a placeholder to generate examples.
      // List of memcached addresses, that will get resolved with the DNS service discovery provider.
      // For DNS service discovery reference https://thanos.io/tip/thanos/service-discovery.md/#dns-service-discovery
      addresses: ['dnssrv+_client._tcp.<MEMCACHED_SERVICE>.%s.svc.cluster.local' % commonConfig.namespace],
    },
  },
});

local rcvs = t.receiveHashrings(commonConfig {
  hashrings: [
    {
      hashring: 'default',
      tenants: [],
    },
    {
      hashring: 'region-1',
      tenants: [],
    },
  ],
  replicas: 3,
  replicationFactor: 2,
  serviceMonitor: true,
  hashringConfigMapName: 'hashring',
});

local strs = t.storeShards(commonConfig {
  shards: 3,
  replicas: 1,
  serviceMonitor: true,
  bucketCache: {
    type: 'memcached',
    config+: {
      // NOTICE: <MEMCACHED_SERVICE> is a placeholder to generate examples.
      // List of memcached addresses, that will get resolved with the DNS service discovery provider.
      // For DNS service discovery reference https://thanos.io/tip/thanos/service-discovery.md/#dns-service-discovery
      addresses: ['dnssrv+_client._tcp.<MEMCACHED_SERVICE>.%s.svc.cluster.local' % commonConfig.namespace],
    },
  },
  indexCache: {
    type: 'memcached',
    config+: {
      // NOTICE: <MEMCACHED_SERVICE> is a placeholder to generate examples.
      // List of memcached addresses, that will get resolved with the DNS service discovery provider.
      // For DNS service discovery reference https://thanos.io/tip/thanos/service-discovery.md/#dns-service-discovery
      addresses: ['dnssrv+_client._tcp.<MEMCACHED_SERVICE>.%s.svc.cluster.local' % commonConfig.namespace],
    },
  },
});

local finalQ = t.query(q.config {
  stores: [
    'dnssrv+_grpc._tcp.%s.%s.svc.cluster.local' % [service.metadata.name, service.metadata.namespace]
    for service in [re.service, ru.service, sc.service, s.service] +
                   [rcvs.hashrings[hashring].service for hashring in std.objectFields(rcvs.hashrings)] +
                   [strs.shards[shard].service for shard in std.objectFields(strs.shards)]
  ],
});

{ ['thanos-bucket-' + name]: b[name] for name in std.objectFields(b) if b[name] != null } +
{ ['thanos-bucket-replicate-' + name]: br[name] for name in std.objectFields(br) if br[name] != null } +
{ ['thanos-compact-' + name]: c[name] for name in std.objectFields(c) if c[name] != null } +
{
  ['thanos-compact-' + shard + '-' + name]: cs.shards[shard][name]
  for shard in std.objectFields(cs.shards)
  for name in std.objectFields(cs.shards[shard])
  if cs.shards[shard][name] != null
} +
{ ['thanos-receive-' + name]: re[name] for name in std.objectFields(re) if re[name] != null } +
{ ['thanos-rule-' + name]: finalRu[name] for name in std.objectFields(finalRu) if finalRu[name] != null } +
{ ['thanos-sidecar-' + name]: sc[name] for name in std.objectFields(sc) if sc[name] != null } +
{ ['thanos-store-' + name]: s[name] for name in std.objectFields(s) if s[name] != null } +
{ ['thanos-query-' + name]: finalQ[name] for name in std.objectFields(finalQ) if finalQ[name] != null } +
{ ['thanos-query-frontend-' + name]: qf[name] for name in std.objectFields(qf) if qf[name] != null } +
{
  ['thanos-receive-' + hashring + '-' + name]: rcvs.hashrings[hashring][name]
  for hashring in std.objectFields(rcvs.hashrings)
  for name in std.objectFields(rcvs.hashrings[hashring])
  if rcvs.hashrings[hashring][name] != null
} +
{
  ['thanos-store-' + shard + '-' + name]: strs.shards[shard][name]
  for shard in std.objectFields(strs.shards)
  for name in std.objectFields(strs.shards[shard])
  if strs.shards[shard][name] != null
} +
{ ['thanos-compact-shards-' + name]: cs[name] for name in std.objectFields(cs) if name != 'shards' && cs[name] != null } +
{ ['thanos-receive-hashrings-' + name]: rcvs[name] for name in std.objectFields(rcvs) if name != 'hashrings' && rcvs[name] != null } +
{ ['thanos-store-shards-' + name]: strs[name] for name in std.objectFields(strs) if name != 'shards' && strs[name] != null }
