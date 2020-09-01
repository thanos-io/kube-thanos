local k = import 'ksonnet/ksonnet.beta.4/k.libsonnet';

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
    local service = k.core.v1.service;
    local ports = service.mixin.spec.portsType;

    service.new(
      tq.config.name,
      tq.config.podLabelSelector,
      [
        ports.newNamed('grpc', 10901, 'grpc'),
        ports.newNamed('http', 9090, 'http'),
      ]
    ) +
    service.mixin.metadata.withNamespace(tq.config.namespace) +
    service.mixin.metadata.withLabels(tq.config.commonLabels),

  deployment:
    local deployment = k.apps.v1.deployment;
    local container = deployment.mixin.spec.template.spec.containersType;
    local affinity = deployment.mixin.spec.template.spec.affinity.podAntiAffinity.preferredDuringSchedulingIgnoredDuringExecutionType;
    local matchExpression = affinity.mixin.podAffinityTerm.labelSelector.matchExpressionsType;

    local c =
      container.new('thanos-query', tq.config.image) +
      container.withTerminationMessagePolicy('FallbackToLogsOnError') +
      container.withArgs([
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
      ]) +
      container.withPorts([
        { name: 'grpc', containerPort: tq.service.spec.ports[0].port },
        { name: 'http', containerPort: tq.service.spec.ports[1].port },
      ]) +
      container.mixin.livenessProbe +
      container.mixin.livenessProbe.withPeriodSeconds(30) +
      container.mixin.livenessProbe.withFailureThreshold(4) +
      container.mixin.livenessProbe.httpGet.withPort(tq.service.spec.ports[1].port) +
      container.mixin.livenessProbe.httpGet.withScheme('HTTP') +
      container.mixin.livenessProbe.httpGet.withPath('/-/healthy') +
      container.mixin.readinessProbe +
      container.mixin.readinessProbe.withPeriodSeconds(5) +
      container.mixin.readinessProbe.withFailureThreshold(20) +
      container.mixin.readinessProbe.httpGet.withPort(tq.service.spec.ports[1].port) +
      container.mixin.readinessProbe.httpGet.withScheme('HTTP') +
      container.mixin.readinessProbe.httpGet.withPath('/-/ready');

    deployment.new(tq.config.name, tq.config.replicas, c, tq.config.commonLabels) +
    deployment.mixin.metadata.withNamespace(tq.config.namespace) +
    deployment.mixin.metadata.withLabels(tq.config.commonLabels) +
    deployment.mixin.spec.selector.withMatchLabels(tq.config.podLabelSelector) +
    deployment.mixin.spec.template.spec.withTerminationGracePeriodSeconds(120) +
    deployment.mixin.spec.template.spec.affinity.podAntiAffinity.withPreferredDuringSchedulingIgnoredDuringExecution([
      affinity.new() +
      affinity.withWeight(100) +
      affinity.mixin.podAffinityTerm.withNamespaces(tq.config.namespace) +
      affinity.mixin.podAffinityTerm.withTopologyKey('kubernetes.io/hostname') +
      affinity.mixin.podAffinityTerm.labelSelector.withMatchExpressions([
        matchExpression.new() +
        matchExpression.withKey('app.kubernetes.io/name') +
        matchExpression.withOperator('In') +
        matchExpression.withValues([tq.deployment.metadata.labels['app.kubernetes.io/name']]),
      ]),
    ]),

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
