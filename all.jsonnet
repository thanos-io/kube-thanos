local t = import 'kube-thanos/thanos.libsonnet';

// THIS IS MERELY AN EXAMPLE MEANT TO SHOW HOW TO USE ALL COMPONENTS!
// Neither this example nor its manifests in examples/all/manifests/ are meant to ever be run.

local commonConfig = {
  local cfg = self,
  namespace: 'thanos',
  version: 'v0.16.0',
  image: 'quay.io/thanos/thanos:' + cfg.version,
  replicaLabels: ['prometheus_replica', 'rule_replica'],
  objectStorageConfig: {
    name: 'thanos-objectstorage',
    key: 'thanos.yaml',
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

  // Example on how to overwrite the tracing config on a per component basis
  // tracing+: {
  //   config+: {
  //     service_name: 'awesome-thanos-bucket',
  //   },
  // },
});

local c = t.compact(commonConfig {
  replicas: 1,
  serviceMonitor: true,
  disableDownsampling: true,
  deduplicationReplicaLabels: super.replicaLabels,  // reuse same labels for deduplication
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
  serviceMonitor: true,
});

local s = t.store(commonConfig {
  replicas: 1,
  serviceMonitor: true,
  bucketCache: {
    type: 'memcached',
    config+: {
      // NOTICE: <MEMCACHED_SERVICE> is a placeholder to generate examples.
      // List of memcached addresses, that will get resolved with the DNS service discovery provider.
      // For DNS service discovery reference https://thanos.io/service-discovery.md/#dns-service-discovery
      addresses: ['dnssrv+_client._tcp.<MEMCACHED_SERVICE>.%s.svc.cluster.local' % commonConfig.namespace],
    },
  },
  indexCache: {
    type: 'memcached',
    config+: {
      // NOTICE: <MEMCACHED_SERVICE> is a placeholder to generate examples.
      // List of memcached addresses, that will get resolved with the DNS service discovery provider.
      // For DNS service discovery reference https://thanos.io/service-discovery.md/#dns-service-discovery
      addresses: ['dnssrv+_client._tcp.<MEMCACHED_SERVICE>.%s.svc.cluster.local' % commonConfig.namespace],
    },
  },
});

local q = t.query(commonConfig {
  name: 'thanos-query',
  replicas: 1,
  stores: [
    'dnssrv+_grpc._tcp.%s.%s.svc.cluster.local' % [service.metadata.name, service.metadata.namespace]
    for service in [re.service, ru.service, s.service]
  ],
  externalPrefix: '',
  resources: {},
  queryTimeout: '5m',
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
      // For DNS service discovery reference https://thanos.io/service-discovery.md/#dns-service-discovery
      addresses: ['dnssrv+_client._tcp.<MEMCACHED_SERVICE>.%s.svc.cluster.local' % commonConfig.namespace],
    },
  },
  labelsCache: {
    type: 'memcached',
    config+: {
      // NOTICE: <MEMCACHED_SERVICE> is a placeholder to generate examples.
      // List of memcached addresses, that will get resolved with the DNS service discovery provider.
      // For DNS service discovery reference https://thanos.io/service-discovery.md/#dns-service-discovery
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
  replicas: 1,
  replicationFactor: 1,
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
      // NOTICE: <MEMCACHED_SERCIVE> is a placeholder to generate examples.
      // List of memcached addresses, that will get resolved with the DNS service discovery provider.
      // For DNS service discovery reference https://thanos.io/service-discovery.md/#dns-service-discovery
      addresses: ['dnssrv+_client._tcp.<MEMCACHED_SERCIVE>.%s.svc.cluster.local' % commonConfig.namespace],
    },
  },
  indexCache: {
    type: 'memcached',
    config+: {
      // NOTICE: <MEMCACHED_SERCIVE> is a placeholder to generate examples.
      // List of memcached addresses, that will get resolved with the DNS service discovery provider.
      // For DNS service discovery reference https://thanos.io/service-discovery.md/#dns-service-discovery
      addresses: ['dnssrv+_client._tcp.<MEMCACHED_SERCIVE>.%s.svc.cluster.local' % commonConfig.namespace],
    },
  },
});

local finalQ = t.query(q.config {
  stores: [
    'dnssrv+_grpc._tcp.%s.%s.svc.cluster.local' % [service.metadata.name, service.metadata.namespace]
    for service in [re.service, ru.service, s.service] +
                   [rcvs[hashring].service for hashring in std.objectFields(rcvs)] +
                   [strs[shard].service for shard in std.objectFields(strs)]
  ],
});

{ ['thanos-bucket-' + name]: b[name] for name in std.objectFields(b) } +
{ ['thanos-compact-' + name]: c[name] for name in std.objectFields(c) } +
{ ['thanos-receive-' + name]: re[name] for name in std.objectFields(re) } +
{ ['thanos-rule-' + name]: finalRu[name] for name in std.objectFields(finalRu) } +
{ ['thanos-store-' + name]: s[name] for name in std.objectFields(s) } +
{ ['thanos-query-' + name]: finalQ[name] for name in std.objectFields(finalQ) } +
{ ['thanos-query-frontend-' + name]: qf[name] for name in std.objectFields(qf) } +
{
  ['thanos-receive-' + hashring + '-' + name]: rcvs[hashring][name]
  for hashring in std.objectFields(rcvs)
  for name in std.objectFields(rcvs[hashring])
  if rcvs[hashring][name] != null
} +
{
  ['store-' + shard + '-' + name]: strs[shard][name]
  for shard in std.objectFields(strs)
  for name in std.objectFields(strs[shard])
  if strs[shard][name] != null
}
