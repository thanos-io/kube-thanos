local receiveConfigDefaults = import 'kube-thanos/kube-thanos-receive-default-params.libsonnet';
local receiveHashring = import 'kube-thanos/kube-thanos-receive-hashrings.libsonnet';

local defaults = receiveConfigDefaults {
  hashrings: [{
    hashring: 'default',
    tenants: [],
  }],
  hashringConfigMapName: 'hashring-config',
  routerReplicas: 1,
};

function(params) {
  local tr = self,
  // Combine the defaults and the passed params to make the component's config.
  config:: defaults + params,

  local ingestors = receiveHashring(tr.config { name: tr.config.name + '-ingestor' }),

  ingestors: {
    [name]: ingestors.hashrings[name]
    for name in std.objectFields(ingestors.hashrings)
  },

  storeEndpoints:: [
    'dnssrv+_grpc._tcp.%s.%s.svc.cluster.local:%d' % [ingestors.hashrings[name.hashring].service.metadata.name, tr.config.namespace, tr.config.ports.grpc]
    for name in tr.config.hashrings
  ],

  endpoints:: {
    [name.hashring]: [
      '%s-%d.%s.%s.svc.cluster.local:%d' % [
        ingestors.hashrings[name.hashring].service.metadata.name,
        i,
        ingestors.hashrings[name.hashring].service.metadata.name,
        tr.config.namespace,
        tr.config.ports.grpc,
      ]
      // Replica specification is 1-based, but statefulSets are named 0-based.
      for i in std.range(0, tr.config.replicas - 1)
    ]
    for name in tr.config.hashrings
  },
  serviceAccount: ingestors.serviceAccount,
  serviceMonitor: if tr.config.serviceMonitor then ingestors.serviceMonitor,
}
