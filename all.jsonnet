local k = import 'ksonnet/ksonnet.beta.4/k.libsonnet';
local sts = k.apps.v1.statefulSet;
local deployment = k.apps.v1.deployment;
local t = (import 'kube-thanos/thanos.libsonnet');

local commonConfig = {
  config+:: {
    local cfg = self,
    namespace: 'thanos',
    version: 'master-2020-05-24-079ad427', # v0.13.0-rc.1 candiate
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

local s =
  t.store +
  t.store.withVolumeClaimTemplate +
  t.store.withServiceMonitor +
  commonConfig + {
    config+:: {
      name: 'thanos-store',
      replicas: 1,
    },
  };

local swm =
  t.store +
  t.store.withVolumeClaimTemplate +
  t.store.withServiceMonitor +
  t.store.withIndexCacheMemcached +
  t.store.withCachingBucketMemcached +
  commonConfig + {
    config+:: {
      name: 'thanos-store',
      replicas: 1,
      memcached+: {
        // NOTICE: <MEMCACHED_SERCIVE> is a placeholder to generate examples.
        // List of memcached addresses, that will get resolved with the DNS service discovery provider.
        // For DNS service discovery reference https://thanos.io/service-discovery.md/#dns-service-discovery
        addresses: ['dnssrv+_client._tcp.<MEMCACHED_SERCIVE>.%s.svc.cluster.local' % commonConfig.config.namespace],
      },
    },
  };

local q =
  t.query +
  t.query.withServiceMonitor +
  commonConfig + {
    config+:: {
      name: 'thanos-query',
      replicas: 1,
      stores: [
        'dnssrv+_grpc._tcp.%s.%s.svc.cluster.local' % [service.metadata.name, service.metadata.namespace]
        for service in [re.service, ru.service, s.service]
      ],
      replicaLabels: ['prometheus_replica', 'rule_replica'],
    },
  };

local finalRu = ru {
  config+:: {
    queriers: ['dnssrv+_http._tcp.%s.%s.svc.cluster.local' % [q.service.metadata.name, q.service.metadata.namespace]],
  },
};

{ ['thanos-bucket-' + name]: b[name] for name in std.objectFields(b) } +
{ ['thanos-compact-' + name]: c[name] for name in std.objectFields(c) } +
{ ['thanos-receive-' + name]: re[name] for name in std.objectFields(re) } +
{ ['thanos-rule-' + name]: finalRu[name] for name in std.objectFields(finalRu) } +
{ ['thanos-store-' + name]: s[name] for name in std.objectFields(s) } +
{ ['thanos-query-' + name]: q[name] for name in std.objectFields(q) } +
{ 'thanos-store-statefulSet-with-memcached': swm.statefulSet }
