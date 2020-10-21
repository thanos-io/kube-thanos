{
  local tqf = self,

  config:: {
    name: error 'must provide name',
    namespace: error 'must provide namespace',
    version: error 'must provide version',
    image: error 'must provide image',
    replicas: error 'must provide replicas',
    downstreamURL: error 'must provide downstreamURL',
    logLevel: 'info',

    commonLabels:: {
      'app.kubernetes.io/name': 'thanos-query-frontend',
      'app.kubernetes.io/instance': tqf.config.name,
      'app.kubernetes.io/version': tqf.config.version,
      'app.kubernetes.io/component': 'query-cache',
    },

    podLabelSelector:: {
      [labelName]: tqf.config.commonLabels[labelName]
      for labelName in std.objectFields(tqf.config.commonLabels)
      if !std.setMember(labelName, ['app.kubernetes.io/version'])
    },
  },

  service:
    {
      apiVersion: 'v1',
      kind: 'Service',
      metadata: {
        name: tqf.config.name,
        namespace: tqf.config.namespace,
        labels: tqf.config.commonLabels,
      },
      spec: {
        selector: tqf.config.podLabelSelector,
        ports: [{ name: 'http', targetPort: 'http', port: 9090 }],
      },
    },

  deployment:
    local c = {
      name: 'thanos-query-frontend',
      image: tqf.config.image,
      args: [
        'query-frontend',
        '--query-frontend.compress-responses',
        '--http-address=0.0.0.0:%d' % tqf.service.spec.ports[0].port,
        '--query-frontend.downstream-url=%s' % tqf.config.downstreamURL,
      ],
      ports: [{ name: 'http', containerPort: tqf.service.spec.ports[0].port }],
      livenessProbe: { failureThreshold: 4, periodSeconds: 30, httpGet: {
        scheme: 'HTTP',
        port: tqf.service.spec.ports[0].port,
        path: '/-/healthy',
      } },
      readinessProbe: { failureThreshold: 20, periodSeconds: 5, httpGet: {
        scheme: 'HTTP',
        port: tqf.service.spec.ports[0].port,
        path: '/-/ready',
      } },
      terminationMessagePolicy: 'FallbackToLogsOnError',
    };

    {
      apiVersion: 'apps/v1',
      kind: 'Deployment',
      metadata: {
        name: tqf.config.name,
        namespace: tqf.config.namespace,
        labels: tqf.config.commonLabels,
      },
      spec: {
        replicas: tqf.config.replicas,
        selector: { matchLabels: tqf.config.podLabelSelector },
        template: {
          metadata: { labels: tqf.config.commonLabels },
          spec: {
            containers: [c],
            terminationGracePeriodSeconds: 120,
            affinity: { podAntiAffinity: {
              preferredDuringSchedulingIgnoredDuringExecution: [{
                podAffinityTerm: {
                  namespaces: [tqf.config.namespace],
                  topologyKey: 'kubernetes.io/hostname',
                  labelSelector: { matchExpressions: [{
                    key: 'app.kubernetes.io/name',
                    operator: 'In',
                    values: [tqf.deployment.metadata.labels['app.kubernetes.io/name']],
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
    local tqf = self,
    serviceMonitor: {
      apiVersion: 'monitoring.coreos.com/v1',
      kind: 'ServiceMonitor',
      metadata+: {
        name: tqf.config.name,
        namespace: tqf.config.namespace,
        labels: tqf.config.commonLabels,
      },
      spec: {
        selector: {
          matchLabels: tqf.config.podLabelSelector,
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
    local tqf = self,
    config+:: {
      resources: error 'must provide resources',
    },

    deployment+: {
      spec+: {
        template+: {
          spec+: {
            containers: [
              if c.name == 'thanos-query-frontend' then c {
                resources: tqf.config.resources,
              } else c
              for c in super.containers
            ],
          },
        },
      },
    },
  },

  withLogQueriesLongerThan:: {
    local tqf = self,
    config+:: {
      logQueriesLongerThan: error 'must provide logQueriesLongerThan',
    },

    deployment+: {
      spec+: {
        template+: {
          spec+: {
            containers: [
              if c.name == 'thanos-query-frontend' then c {
                args+: [
                  '--query-frontend.log-queries-longer-than=' + tqf.config.logQueriesLongerThan,
                ],
              } else c
              for c in super.containers
            ],
          },
        },
      },
    },
  },

  withMaxRetries:: {
    local tqf = self,
    config+:: {
      maxRetries: error 'must provide maxRetries',
    },

    deployment+: {
      spec+: {
        template+: {
          spec+: {
            containers: [
              if c.name == 'thanos-query-frontend' then c {
                args+: [
                  '--query-range.max-retries-per-request=' + tqf.config.maxRetries,
                ],
              } else c
              for c in super.containers
            ],
          },
        },
      },
    },
  },

  withSplitInterval:: {
    local tqf = self,
    config+:: {
      splitInterval: error 'must provide splitInterval',
    },

    deployment+: {
      spec+: {
        template+: {
          spec+: {
            containers: [
              if c.name == 'thanos-query-frontend' then c {
                args+: [
                  '--query-range.split-interval=' + tqf.config.splitInterval,
                ],
              } else c
              for c in super.containers
            ],
          },
        },
      },
    },
  },

  local fifoCacheDefaults = {
    // Don't limit maximum item size.
    maxSize: '0',
    maxSizeItems: 2048,
    validity: '6h',
  },

  withInMemoryResponseCache:: {
    local tqf = self,
    config+:: {
      fifoCache: fifoCacheDefaults,
    },
    local m = tqf.config.fifoCache,
    local cfg =
      {
        type: 'in-memory',
        config: {
          max_size: m.maxSize,
          max_size_items: m.maxSizeItems,
          validity: m.validity,
        },
      },
    deployment+: {
      spec+: {
        template+: {
          spec+: {
            containers: [
              if c.name == 'thanos-query-frontend' then c {
                args+: if m != {} then [
                  '--query-range.response-cache-config=' + std.manifestYamlDoc(cfg),
                ] else [],
              } else c
              for c in super.containers
            ],
          },
        },
      },
    },
  },
}
