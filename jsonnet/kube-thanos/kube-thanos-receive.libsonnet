local k = import 'ksonnet/ksonnet.beta.4/k.libsonnet';

{
  local tr = self,

  config:: {
    name: error 'must provide name',
    namespace: error 'must provide namespace',
    version: error 'must provide version',
    image: error 'must provide image',
    replicas: error 'must provide replicas',
    replicationFactor: error 'must provide replication factor',
    objectStorageConfig: error 'must provide objectStorageConfig',
    logLevel: 'info',

    commonLabels:: {
      'app.kubernetes.io/name': 'thanos-receive',
      'app.kubernetes.io/instance': tr.config.name,
      'app.kubernetes.io/version': tr.config.version,
      'app.kubernetes.io/component': 'database-write-hashring',
    },

    podLabelSelector:: {
      [labelName]: tr.config.commonLabels[labelName]
      for labelName in std.objectFields(tr.config.commonLabels)
      if !std.setMember(labelName, ['app.kubernetes.io/version'])
    },
  },

  service:
    local service = k.core.v1.service;
    local ports = service.mixin.spec.portsType;

    service.new(
      tr.config.name,
      tr.config.podLabelSelector,
      [
        ports.newNamed('grpc', 10901, 10901),
        ports.newNamed('http', 10902, 10902),
        ports.newNamed('remote-write', 19291, 19291),
      ]
    ) +
    service.mixin.metadata.withNamespace(tr.config.namespace) +
    service.mixin.metadata.withLabels(tr.config.commonLabels) +
    service.mixin.spec.withClusterIp('None'),

  statefulSet:
    local sts = k.apps.v1.statefulSet;
    local affinity = sts.mixin.spec.template.spec.affinity.podAntiAffinity.preferredDuringSchedulingIgnoredDuringExecutionType;
    local matchExpression = affinity.mixin.podAffinityTerm.labelSelector.matchExpressionsType;
    local volume = sts.mixin.spec.template.spec.volumesType;
    local container = sts.mixin.spec.template.spec.containersType;
    local containerEnv = container.envType;
    local containerVolumeMount = container.volumeMountsType;

    local replicationFactor = tr.config.replicationFactor;
    local localEndpointFlag = '--receive.local-endpoint=$(NAME).%s.$(NAMESPACE).svc.cluster.local:%d' % [tr.config.name, tr.service.spec.ports[0].port];

    local c =
      container.new('thanos-receive', tr.config.image) +
      container.withTerminationMessagePolicy('FallbackToLogsOnError') +
      container.withArgs([
        'receive',
        '--log.level=' + tr.config.logLevel,
        '--grpc-address=0.0.0.0:%d' % tr.service.spec.ports[0].port,
        '--http-address=0.0.0.0:%d' % tr.service.spec.ports[1].port,
        '--remote-write.address=0.0.0.0:%d' % tr.service.spec.ports[2].port,
        '--receive.replication-factor=%d' % replicationFactor,
        '--objstore.config=$(OBJSTORE_CONFIG)',
        '--tsdb.path=/var/thanos/receive',
        '--label=replica="$(NAME)"',
        '--label=receive="true"',
        localEndpointFlag,
      ]) +
      container.withEnv([
        containerEnv.fromFieldPath('NAME', 'metadata.name'),
        containerEnv.fromFieldPath('NAMESPACE', 'metadata.namespace'),
        containerEnv.fromSecretRef(
          'OBJSTORE_CONFIG',
          tr.config.objectStorageConfig.name,
          tr.config.objectStorageConfig.key,
        ),
      ]) +
      container.withPorts([
        { name: 'grpc', containerPort: tr.service.spec.ports[0].port },
        { name: 'http', containerPort: tr.service.spec.ports[1].port },
        { name: 'remote-write', containerPort: tr.service.spec.ports[2].port },
      ]) +
      container.withVolumeMounts([
        containerVolumeMount.new('data', '/var/thanos/receive', false),
      ]) +
      container.mixin.livenessProbe +
      container.mixin.livenessProbe.withPeriodSeconds(30) +
      container.mixin.livenessProbe.withFailureThreshold(8) +
      container.mixin.livenessProbe.httpGet.withPort(tr.service.spec.ports[1].port) +
      container.mixin.livenessProbe.httpGet.withScheme('HTTP') +
      container.mixin.livenessProbe.httpGet.withPath('/-/healthy') +
      container.mixin.readinessProbe +
      container.mixin.readinessProbe.withPeriodSeconds(5) +
      container.mixin.readinessProbe.withFailureThreshold(20) +
      container.mixin.readinessProbe.httpGet.withPort(tr.service.spec.ports[1].port) +
      container.mixin.readinessProbe.httpGet.withScheme('HTTP') +
      container.mixin.readinessProbe.httpGet.withPath('/-/ready');

    sts.new(tr.config.name, tr.config.replicas, c, [], tr.config.commonLabels) +
    sts.mixin.metadata.withNamespace(tr.config.namespace) +
    sts.mixin.metadata.withLabels(tr.config.commonLabels) +
    sts.mixin.spec.withServiceName(tr.service.metadata.name) +
    sts.mixin.spec.template.spec.withTerminationGracePeriodSeconds(900) +
    sts.mixin.spec.template.spec.withVolumes([
      volume.fromEmptyDir('data'),
    ]) +
    sts.mixin.spec.template.spec.affinity.podAntiAffinity.withPreferredDuringSchedulingIgnoredDuringExecution([
      affinity.new() +
      affinity.withWeight(100) +
      affinity.mixin.podAffinityTerm.withNamespaces(tr.config.namespace) +
      affinity.mixin.podAffinityTerm.withTopologyKey('kubernetes.io/hostname') +
      affinity.mixin.podAffinityTerm.labelSelector.withMatchExpressions([
        matchExpression.new() +
        matchExpression.withKey('app.kubernetes.io/name') +
        matchExpression.withOperator('In') +
        matchExpression.withValues([tr.statefulSet.metadata.labels['app.kubernetes.io/name']]),
        matchExpression.new() +
        matchExpression.withKey('app.kubernetes.io/instance') +
        matchExpression.withOperator('In') +
        matchExpression.withValues([tr.statefulSet.metadata.labels['app.kubernetes.io/instance']]),
      ]),
      affinity.new() +
      affinity.withWeight(100) +
      affinity.mixin.podAffinityTerm.withNamespaces(tr.config.namespace) +
      affinity.mixin.podAffinityTerm.withTopologyKey('topology.kubernetes.io/zone') +
      affinity.mixin.podAffinityTerm.labelSelector.withMatchExpressions([
        matchExpression.new() +
        matchExpression.withKey('app.kubernetes.io/name') +
        matchExpression.withOperator('In') +
        matchExpression.withValues([tr.statefulSet.metadata.labels['app.kubernetes.io/name']]),
        matchExpression.new() +
        matchExpression.withKey('app.kubernetes.io/instance') +
        matchExpression.withOperator('In') +
        matchExpression.withValues([tr.statefulSet.metadata.labels['app.kubernetes.io/instance']]),
      ]),
    ]) +
    sts.mixin.spec.selector.withMatchLabels(tr.config.podLabelSelector) +
    {
      spec+: {
        volumeClaimTemplates: null,
      },
    },

  withServiceMonitor:: {
    local tr = self,
    serviceMonitor: {
      apiVersion: 'monitoring.coreos.com/v1',
      kind: 'ServiceMonitor',
      metadata+: {
        name: tr.config.name,
        namespace: tr.config.namespace,
        labels: tr.config.commonLabels,
      },
      spec: {
        selector: {
          matchLabels: tr.config.podLabelSelector,
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

  withPodDisruptionBudget:: {
    local tr = self,
    config+:: {
      podDisruptionBudgetMaxUnavailable: (std.floor(tr.config.replicationFactor / 2)),
    },

    podDisruptionBudget:
      local pdb = k.policy.v1beta1.podDisruptionBudget;
      pdb.new() +
      pdb.mixin.spec.withMaxUnavailable(tr.config.podDisruptionBudgetMaxUnavailable) +
      pdb.mixin.spec.selector.withMatchLabels(tr.config.podLabelSelector) +
      pdb.mixin.metadata.withName(tr.config.name) +
      pdb.mixin.metadata.withNamespace(tr.config.namespace),
  },

  withVolumeClaimTemplate:: {
    local tr = self,
    config+:: {
      volumeClaimTemplate: error 'must provide volumeClaimTemplate',
    },

    statefulSet+: {
      spec+: {
        template+: {
          spec+: {
            volumes: std.filter(function(v) v.name != 'data', super.volumes),
          },
        },
        volumeClaimTemplates: [tr.config.volumeClaimTemplate {
          metadata+: {
            name: 'data',
            labels+: tr.config.podLabelSelector,
          },
        }],
      },
    },
  },

  withRetention:: {
    local tr = self,
    config+:: {
      retention: error 'must provide retention',
    },

    statefulSet+: {
      spec+: {
        template+: {
          spec+: {
            containers: [
              if c.name == 'thanos-receive' then c {
                args+: [
                  '--tsdb.retention=' + tr.config.retention,
                ],
              } else c
              for c in super.containers
            ],
          },
        },
      },
    },
  },

  withHashringConfigMap:: {
    local tr = self,
    config+:: {
      hashringConfigMapName: error 'must provide hashringConfigMapName',
    },

    statefulSet+: {
      spec+: {
        template+: {
          spec+: {
            containers: [
              if c.name == 'thanos-receive' then c {
                args+: [
                  '--receive.hashrings-file=/var/lib/thanos-receive/hashrings.json',
                ],
                volumeMounts+: [
                  { name: 'hashring-config', mountPath: '/var/lib/thanos-receive' },
                ],
              } else c
              for c in super.containers
            ],

            local volume = k.apps.v1.statefulSet.mixin.spec.template.spec.volumesType,
            volumes+: [
              volume.withName('hashring-config') +
              volume.mixin.configMap.withName(tr.config.hashringConfigMapName),
            ],
          },
        },
      },
    },
  },

  withResources:: {
    local tr = self,
    config+:: {
      resources: error 'must provide resources',
    },

    statefulSet+: {
      spec+: {
        template+: {
          spec+: {
            containers: [
              if c.name == 'thanos-receive' then c {
                resources: tr.config.resources,
              } else c
              for c in super.containers
            ],
          },
        },
      },
    },
  },
}
