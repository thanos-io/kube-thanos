local k = import 'ksonnet/ksonnet.beta.4/k.libsonnet';

{
  local tqf = self,

  config:: {
    name: error 'must provide name',
    namespace: error 'must provide namespace',
    version: error 'must provide version',
    image: error 'must provide image',
    replicas: error 'must provide replicas',
    downstreamURL: error 'must provide downstreamURL',

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
    local service = k.core.v1.service;
    local ports = service.mixin.spec.portsType;

    service.new(
      tqf.config.name,
      tqf.config.podLabelSelector,
      [
        ports.newNamed('http', 9090, 'http'),
      ]
    ) +
    service.mixin.metadata.withNamespace(tqf.config.namespace) +
    service.mixin.metadata.withLabels(tqf.config.commonLabels),

  deployment:
    local deployment = k.apps.v1.deployment;
    local container = deployment.mixin.spec.template.spec.containersType;
    local affinity = deployment.mixin.spec.template.spec.affinity.podAntiAffinity.preferredDuringSchedulingIgnoredDuringExecutionType;
    local matchExpression = affinity.mixin.podAffinityTerm.labelSelector.matchExpressionsType;

    local c =
      container.new('thanos-query-frontend', tqf.config.image) +
      container.withTerminationMessagePolicy('FallbackToLogsOnError') +
      container.withArgs([
        'query-frontend',
        '--query-frontend.compress-responses',
        '--http-address=0.0.0.0:%d' % tqf.service.spec.ports[0].port,
        '--query-frontend.downstream-url=%s' % tqf.config.downstreamURL,
      ]) +
      container.withPorts([
        { name: 'http', containerPort: tqf.service.spec.ports[0].port },
      ]) +
      container.mixin.livenessProbe +
      container.mixin.livenessProbe.withPeriodSeconds(30) +
      container.mixin.livenessProbe.withFailureThreshold(4) +
      container.mixin.livenessProbe.httpGet.withPort(tqf.service.spec.ports[0].port) +
      container.mixin.livenessProbe.httpGet.withScheme('HTTP') +
      container.mixin.livenessProbe.httpGet.withPath('/-/healthy') +
      container.mixin.readinessProbe +
      container.mixin.readinessProbe.withPeriodSeconds(5) +
      container.mixin.readinessProbe.withFailureThreshold(20) +
      container.mixin.readinessProbe.httpGet.withPort(tqf.service.spec.ports[0].port) +
      container.mixin.readinessProbe.httpGet.withScheme('HTTP') +
      container.mixin.readinessProbe.httpGet.withPath('/-/ready');

    deployment.new(tqf.config.name, tqf.config.replicas, c, tqf.config.commonLabels) +
    deployment.mixin.metadata.withNamespace(tqf.config.namespace) +
    deployment.mixin.metadata.withLabels(tqf.config.commonLabels) +
    deployment.mixin.spec.selector.withMatchLabels(tqf.config.podLabelSelector) +
    deployment.mixin.spec.template.spec.withTerminationGracePeriodSeconds(120) +
    deployment.mixin.spec.template.spec.affinity.podAntiAffinity.withPreferredDuringSchedulingIgnoredDuringExecution([
      affinity.new() +
      affinity.withWeight(100) +
      affinity.mixin.podAffinityTerm.withNamespaces(tqf.config.namespace) +
      affinity.mixin.podAffinityTerm.withTopologyKey('kubernetes.io/hostname') +
      affinity.mixin.podAffinityTerm.labelSelector.withMatchExpressions([
        matchExpression.new() +
        matchExpression.withKey('app.kubernetes.io/name') +
        matchExpression.withOperator('In') +
        matchExpression.withValues([tqf.deployment.metadata.labels['app.kubernetes.io/name']]),
      ]),
    ]),

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
                  '--query-frontend.log_queries_longer_than=' + tqf.config.logQueriesLongerThan,
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
