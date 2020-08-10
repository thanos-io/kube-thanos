local t = import 'kube-thanos/thanos.libsonnet';

local commonConfig = {
  config+:: {
    local cfg = self,
    namespace: 'thanos',
    version: 'master-2020-08-11-2ea2c2b7',
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

local b =
  t.bucket +
  commonConfig + {
    config+:: {
      name: 'thanos-bucket',
      replicas: 1,
    },
  };

local c =
  t.compact +
  t.compact.withVolumeClaimTemplate +
  t.compact.withServiceMonitor +
  commonConfig + {
    config+:: {
      name: 'thanos-compact',
      replicas: 1,
    },
  };

local re =
  t.receive +
  t.receive.withVolumeClaimTemplate +
  t.receive.withServiceMonitor +
  commonConfig + {
    config+:: {
      name: 'thanos-receive',
      replicas: 1,
      replicationFactor: 1,
    },
  };

local ru =
  t.rule +
  t.rule.withVolumeClaimTemplate +
  t.rule.withServiceMonitor +
  commonConfig + {
    config+:: {
      name: 'thanos-rule',
      replicas: 1,
    },
  };

local store = t.store(commonConfig.config {
  name: 'thanos-store',
  replicas: 1,
  serviceMonitor: true,
});

local storeMemcached = t.store(commonConfig.config {
  name: 'thanos-store',
  replicas: 1,
  memcached+: {
    // NOTICE: <MEMCACHED_SERCIVE> is a placeholder to generate examples.
    // List of memcached addresses, that will get resolved with the DNS service discovery provider.
    // For DNS service discovery reference https://thanos.io/service-discovery.md/#dns-service-discovery
    addresses: ['dnssrv+_client._tcp.%s.%s.svc.cluster.local' % ['<MEMCACHED_SERCIVE>', commonConfig.config.namespace]],
  },
});

local query = t.query(commonConfig.config {
  replicas: 1,
  replicaLabels: ['prometheus_replica', 'rule_replica'],
  queryTimeout: '5m',
  lookbackDelta: '15m',
  stores: [
    'dnssrv+_grpc._tcp.%s.%s.svc.cluster.local' % [service.metadata.name, service.metadata.namespace]
    for service in [re.service, ru.service, store.service]
  ],
  serviceMonitor: true,
});

local finalRu = ru {
  config+:: {
    queriers: ['dnssrv+_http._tcp.%s.%s.svc.cluster.local' % [query.service.metadata.name, query.service.metadata.namespace]],
  },
};

local qf =
  t.queryFrontend +
  t.queryFrontend.withServiceMonitor +
  t.queryFrontend.withSplitInterval +
  t.queryFrontend.withMaxRetries +
  t.queryFrontend.withLogQueriesLongerThan +
  t.queryFrontend.withInMemoryResponseCache +
  commonConfig + {
    config+:: {
      name: 'thanos-query-frontend',
      replicas: 1,
      downstreamURL: 'http://%s.%s.svc.cluster.local.:%d' % [
        query.service.metadata.name,
        query.service.metadata.namespace,
        query.service.spec.ports[1].port,
      ],
      splitInterval: '24h',
      maxRetries: 5,
      logQueriesLongerThan: '5s',
    },
  };


{ ['thanos-bucket-' + name]: b[name] for name in std.objectFields(b) } +
{ ['thanos-compact-' + name]: c[name] for name in std.objectFields(c) } +
{ ['thanos-receive-' + name]: re[name] for name in std.objectFields(re) } +
{ ['thanos-rule-' + name]: finalRu[name] for name in std.objectFields(finalRu) } +
{ ['thanos-store-' + name]: store[name] for name in std.objectFields(store) } +
{ ['thanos-query-' + name]: query[name] for name in std.objectFields(query) } +
{ ['thanos-query-frontend-' + name]: qf[name] for name in std.objectFields(qf) } +
{ 'thanos-store-statefulSet-with-memcached': storeMemcached.statefulSet }
