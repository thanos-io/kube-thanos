{
  local tq = self,

  config:: {
    name: error 'must provide name',
    namespace: error 'must provide namespace',
    version: error 'must provide version',
    image: error 'must provide image',
    replicas: error 'must provide replicas',
    replicaLabels: error 'must provide replica labels',
    stores: error 'must provide store addresses',
    logLevel: 'info',

    commonLabels:: {
      'app.kubernetes.io/name': 'thanos-query',
      'app.kubernetes.io/instance': tq.config.name,
      'app.kubernetes.io/version': tq.config.version,
      'app.kubernetes.io/component': 'query-layer',
    },

    podLabelSelector:: {
      [labelName]: tq.config.commonLabels[labelName]
      for labelName in std.objectFields(tq.config.commonLabels)
      if !std.setMember(labelName, ['app.kubernetes.io/version'])
    },
  },

  service:
    {
      apiVersion: 'v1',
      kind: 'Service',
      metadata: {
        name: tq.config.name,
        namespace: tq.config.namespace,
        labels: tq.config.commonLabels,
      },
      spec: {
        ports: [
          { name: 'grpc', targetPort: 'grpc', port: 10901 },
          { name: 'http', targetPort: 'http', port: 9090 },
        ],
        selector: tq.config.podLabelSelector,
      },
    },

  deployment:
    local c = {
      name: 'thanos-query',
      image: tq.config.image,
      args: [
        'query',
        '--log.level=' + tq.config.logLevel,
        '--grpc-address=0.0.0.0:%d' % tq.service.spec.ports[0].port,
        '--http-address=0.0.0.0:%d' % tq.service.spec.ports[1].port,
      ] + [
        '--query.replica-label=%s' % labelName
        for labelName in tq.config.replicaLabels
      ] + [
        '--store=%s' % store
        for store in tq.config.stores
      ],
      ports: [
        { name: port.name, containerPort: port.port }
        for port in tq.service.spec.ports
      ],
      livenessProbe: { failureThreshold: 4, periodSeconds: 30, httpGet: {
        scheme: 'HTTP',
        port: tq.service.spec.ports[1].port,
        path: '/-/healthy',
      } },
      readinessProbe: { failureThreshold: 20, periodSeconds: 5, httpGet: {
        scheme: 'HTTP',
        port: tq.service.spec.ports[1].port,
        path: '/-/ready',
      } },
      terminationMessagePolicy: 'FallbackToLogsOnError',
    };

    {
      apiVersion: 'apps/v1',
      kind: 'Deployment',
      metadata: {
        name: tq.config.name,
        namespace: tq.config.namespace,
        labels: tq.config.commonLabels,
      },
      spec: {
        replicas: tq.config.replicas,
        selector: { matchLabels: tq.config.podLabelSelector },
        template: {
          metadata: {
            labels: tq.config.commonLabels,
          },
          spec: {
            containers: [c],
            terminationGracePeriodSeconds: 120,
            affinity: { podAntiAffinity: {
              preferredDuringSchedulingIgnoredDuringExecution: [{
                podAffinityTerm: {
                  namespaces: [tq.config.namespace],
                  topologyKey: 'kubernetes.io/hostname',
                  labelSelector: { matchExpressions: [{
                    key: 'app.kubernetes.io/name',
                    operator: 'In',
                    values: [tq.deployment.metadata.labels['app.kubernetes.io/name']],
                  }] },
                },
                weight: 100,
              }],
            } },
          },
        },
      },
    },

  withServiceMonitor:: {
    local tq = self,
    serviceMonitor: {
      apiVersion: 'monitoring.coreos.com/v1',
      kind: 'ServiceMonitor',
      metadata+: {
        name: tq.config.name,
        namespace: tq.config.namespace,
        labels: tq.config.commonLabels,
      },
      spec: {
        selector: {
          matchLabels: tq.config.podLabelSelector,
        },
        endpoints: [
          {
            port: 'http',
            relabelings: [{
              sourceLabels: ['namespace', 'pod'],
              separator: '/',
              targetLabel: 'instance',
            }],
          },
        ],
      },
    },
  },

  withResources:: {
    local tq = self,
    config+:: {
      resources: error 'must provide resources',
    },

    deployment+: {
      spec+: {
        template+: {
          spec+: {
            containers: [
              if c.name == 'thanos-query' then c {
                resources: tq.config.resources,
              } else c
              for c in super.containers
            ],
          },
        },
      },
    },
  },

  withExternalPrefix:: {
    local tq = self,
    config+:: {
      externalPrefix: error 'must provide externalPrefix',
    },

    deployment+: {
      spec+: {
        template+: {
          spec+: {
            containers: [
              if c.name == 'thanos-query' then c {
                args+: [
                  '--web.external-prefix=' + tq.config.externalPrefix,
                ],
              } else c
              for c in super.containers
            ],
          },
        },
      },
    },
  },

  withQueryTimeout:: {
    local tq = self,
    config+:: {
      queryTimeout: error 'must provide queryTimeout',
    },

    deployment+: {
      spec+: {
        template+: {
          spec+: {
            containers: [
              if c.name == 'thanos-query' then c {
                args+: [
                  '--query.timeout=' + tq.config.queryTimeout,
                ],
              } else c
              for c in super.containers
            ],
          },
        },
      },
    },
  },

  withLookbackDelta:: {
    local tq = self,
    config+:: {
      lookbackDelta: error 'must provide lookbackDelta',
    },

    deployment+: {
      spec+: {
        template+: {
          spec+: {
            containers: [
              if c.name == 'thanos-query' then c {
                args+: [
                  '--query.lookback-delta=' + tq.config.lookbackDelta,
                ],
              } else c
              for c in super.containers
            ],
          },
        },
      },
    },
  },
}
